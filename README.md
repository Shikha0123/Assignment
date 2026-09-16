<<<<<<< HEAD
# Tripare DevOps Assessment — Terraform + Database Reliability

This repository is my submission for the DevOps Engineer assessment: AWS
infrastructure as code with Terraform, plus a local database environment
covering schema design, query optimization, and backup/restore reliability.

Everything below was actually run and verified locally while building this
(Postgres migrations, seed data, `EXPLAIN ANALYZE` before/after the index,
and a full backup → restore → verify cycle) — the exact output is included
in the relevant sections so you can see it worked, not just read a claim
that it does.

## Contents

```
.
├── terraform/
│   ├── modules/            # network, security, alb, ecs, rds
│   └── environments/
│       ├── dev/            # smaller instance, short backups, deletion_protection=false
│       └── prod/           # larger instance, long backups, deletion_protection=true
├── database/
│   ├── docker-compose.yml  # local Postgres
│   ├── migrations/         # schema + indexes
│   └── seed/                # 300+ seed rows across orgs/cities
├── scripts/
│   ├── backup.sh
│   └── restore.sh
└── .github/workflows/terraform-plan.yml   # fmt/init/validate/plan on every PR
```

## 1. Infrastructure (Terraform)

### Architecture

```
Internet
   │
   ▼
┌─────────────────────────┐  public subnets (2 AZs)
│  Application Load       │  SG: 80/443 from 0.0.0.0/0
│  Balancer                │
└───────────┬─────────────┘
            │  only port 80, only from ALB's SG
            ▼
┌─────────────────────────┐  private "app" subnets (2 AZs)
│  ECS Fargate service     │  SG: from ALB SG only
│  (task + service)        │
└───────────┬─────────────┘
            │  only DB port, only from ECS's SG
            ▼
┌─────────────────────────┐  private "db" subnets (2 AZs, no internet route)
│  RDS (Postgres/MySQL)     │  SG: from ECS SG only
└─────────────────────────┘
```

Each tier gets its own security group, and each security group only accepts
traffic from the security group of the tier directly in front of it (see
`terraform/modules/security/main.tf`). The database subnets have no route to
an Internet Gateway or NAT Gateway at all — RDS is unreachable from the
internet even if its endpoint leaked, because there's no network path, not
just a firewall rule.

Modules:

| Module | Responsibility |
|---|---|
| `network` | VPC, public/private-app/private-db subnets across 2 AZs, IGW, NAT Gateway(s), route tables |
| `security` | The three security groups described above |
| `alb` | Application Load Balancer, target group (health-checked), HTTP listener |
| `ecs` | ECS cluster, Fargate task definition + service, IAM execution/task roles, CloudWatch logs |
| `rds` | DB subnet group, RDS instance, a generated master password stored in Secrets Manager (never in state output or tfvars) |

### Dev vs. prod

Both environments call the same modules; only the inputs differ
(`terraform/environments/{dev,prod}/terraform.tfvars`):

| Setting | dev | prod |
|---|---|---|
| DB instance class | `db.t3.micro` | `db.t3.large` |
| DB storage | 20 GB | 100 GB (autoscale to 100/higher as needed) |
| Backup retention | 1 day | 30 days |
| `deletion_protection` | `false` | `true` |
| Multi-AZ | `false` | `true` |
| NAT Gateways | 1 shared (cost) | 1 per AZ (HA) |
| ECS task size | 0.25 vCPU / 512 MB, 1 task | 1 vCPU / 2 GB, 3 tasks |
| ALB deletion protection | off | on |

This mirrors how these two environments are actually used: dev is optimized
for fast, cheap iteration where losing data is not catastrophic; prod is
optimized to resist accidental deletion and data loss.

### Running it

```bash
cd terraform/environments/dev      # or prod
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan                     # requires AWS credentials; does not apply anything
```

I don't have an AWS account wired into this environment, so I validated the
HCL structurally (module wiring, variable types, resource references) but
could not run a live `terraform plan` against real AWS here. The GitHub
Actions workflow below runs the exact same commands against this repo's
configured AWS role on every PR, which is the intended way to validate it
end-to-end.

A remote S3+DynamoDB backend is stubbed out (commented) in each
environment's `backend.tf` — point it at your own state bucket/lock table
before running this against a real account; it's left commented so `init`
doesn't fail on a fresh checkout with no bucket yet.

### CI: `.github/workflows/terraform-plan.yml`

On every pull request that touches `terraform/**`, a matrix job runs, once
per environment (dev, prod):

1. `terraform fmt -check -recursive -diff`
2. `terraform init`
3. `terraform validate`
4. `terraform plan` (never `apply`)

The plan is uploaded as a build artifact and also posted/updated as a
comment on the PR itself, so a reviewer sees exactly what would change
without leaving GitHub. AWS auth uses OIDC (`aws-actions/configure-aws-credentials`)
rather than long-lived access keys — set the `AWS_TERRAFORM_ROLE_ARN` repo
secret to a role your AWS account trusts for GitHub's OIDC provider.

## 2. Local database (Docker Compose)

```bash
cd database
docker compose up -d
```

This starts Postgres 16 and, **on first boot only** (empty volume), runs in
order:

1. `migrations/001_create_tables.sql` — creates `hotel_bookings` and
   `booking_events`
2. `migrations/002_add_indexes.sql` — adds the query-optimization index
   (see below)
3. `seed/003_seed_data.sql` — generates 300 randomized bookings (plus a
   handful of deterministic ones) spread across 5 orgs, 25 hotels, and 7
   cities, with `created_at` timestamps spread over the last ~200 days so
   there's realistic data both inside and outside the "last 30 days"
   reporting window

I ran this against a real local Postgres instance while building it (not
just eyeballing the SQL):

```
 total_bookings
----------------
            304

   city    | count
-----------+-------
 bangalore |    44
 chennai   |    44
 delhi     |    49
 hyderabad |    39
 kolkata   |    48
 mumbai    |    37
 pune      |    43

 total_events
--------------
          595
```

### Schema

**hotel_bookings**: `id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at`
(with a `CHECK` that `checkout_date > checkin_date`, and `status` constrained
to `pending/confirmed/cancelled/completed`).

**booking_events**: `id, booking_id (FK -> hotel_bookings), event_type, payload (jsonb), created_at`
— an append-only audit trail of each booking's lifecycle.

## 3. Query optimization

Target query:

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

**Index added** (`database/migrations/002_add_indexes.sql`):

```sql
CREATE INDEX idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
```

**Rationale:**

- `city` is an equality filter → it leads the composite index.
- `created_at` is a range filter (`>=`) → it goes second; a btree can still
  seek efficiently on a range once the leading equality column is fixed.
- `org_id`, `status`, `amount` are added as `INCLUDE` columns (not index key
  columns) purely so Postgres can answer the *entire* query — the
  `GROUP BY` columns and the `SUM(amount)` — straight from the index,
  without a round-trip to the table's heap for every matching row (an
  "index-only scan").
- A single composite/covering index beats two separate single-column
  indexes (one on `city`, one on `created_at`) for this shape: with two
  indexes Postgres would have to bitmap-AND them and then still visit the
  heap for `org_id`/`status`/`amount`; the covering index avoids both the
  AND and the heap visit.

**Verified before/after** (actual `EXPLAIN ANALYZE` output from the seeded
database, after `VACUUM ANALYZE` so the visibility map is up to date):

Before (index dropped):

```
HashAggregate  (cost=10.28..10.44 rows=13 width=53)
  Group Key: org_id, status
  ->  Seq Scan on hotel_bookings  (cost=0.00..10.08 rows=20 width=20)
        Filter: (((city)::text = 'delhi'::text) AND (created_at >= (now() - '30 days'::interval)))
        Rows Removed by Filter: 282
```

After (index in place):

```
HashAggregate  (cost=4.88..5.04 rows=13 width=53)
  Group Key: org_id, status
  ->  Index Only Scan using idx_hotel_bookings_city_created_at on hotel_bookings  (cost=0.28..4.68 rows=20 width=20)
        Index Cond: ((city = 'delhi'::text) AND (created_at >= (now() - '30 days'::interval)))
        Heap Fetches: 0
```

The planner's cost estimate drops from `10.28` to `4.88`, the plan changes
from a full `Seq Scan` (having to filter out 282 of 304 rows) to an
`Index Only Scan` with zero heap fetches, and `Rows Removed by Filter`
disappears entirely. At this seed scale (304 rows) the wall-clock
difference is a fraction of a millisecond and not the interesting part —
the point is that a `Seq Scan` degrades linearly as the table grows into
the millions of rows a real booking system accumulates, while the
index-only scan stays roughly flat because it only ever touches the rows
that actually match `city = 'delhi'` and the date window.

## 4. Backup and restore

```bash
./scripts/backup.sh
# ==> Backup complete: backups/tripare_20260915T143115Z.dump (24K)
# ==> Verified: backup archive is readable (pg_restore --list succeeded).

./scripts/restore.sh backups/tripare_20260915T143115Z.dump tripare_restore_test
```

- **`backup.sh`** takes a timestamped `pg_dump --format=custom` dump (chosen
  over a plain `.sql` dump because it's compressed and supports selective /
  parallel restore), verifies the archive is readable with
  `pg_restore --list` immediately after writing it, and prunes local dumps
  down to the last 7 so the `backups/` directory doesn't grow forever.
  (Production retention is controlled separately, by RDS's own automated
  backups via the `backup_retention_period` Terraform variable — 1 day in
  dev, 30 in prod.)

- **`restore.sh`** restores into a **brand-new database** (never the
  original), which is the actual proof the backup is self-contained rather
  than restoring "successfully" only because most of the schema was already
  there. It then verifies success by comparing row counts between the
  restored database and the source, rather than trusting a zero exit code:

```
==> Restore command finished. Verifying row counts...
    Restored hotel_bookings rows: 304
    Restored booking_events rows: 595
    Source ('tripare') hotel_bookings rows: 304
==> Verification PASSED: restore produced a queryable database with data intact.
```

Both scripts read connection info from environment variables
(`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `PGPASSWORD`) defaulting to the
`docker-compose.yml` values, so they work unmodified against the local
Compose stack or against a real RDS endpoint by overriding those variables.

## 5. Assumptions / things I'd change with more time

- The ALB listener is HTTP-only (no ACM cert/domain available for this
  assessment); production would redirect 80 → 443 with a real certificate.
- The container image defaults to a placeholder (`nginx`) since there's no
  actual app to build/push here — swap `container_image` for a real
  ECR image URI.
- RDS master credentials are auto-generated (`random_password`) and stored
  only in Secrets Manager, never in state output/tfvars, and ECS reads them
  at container start via the `secrets` block in the task definition.
- The Terraform remote backend (S3 + DynamoDB lock table) is stubbed out
  commented in `backend.tf` — wire it to a real bucket before using this
  against an actual AWS account.
=======
# Assignment
>>>>>>> 925579e4a25d64317d644defae489de67e2f6941
