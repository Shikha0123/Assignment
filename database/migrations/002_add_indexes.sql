-- ---------------------------------------------------------------------------
-- 002_add_indexes.sql
-- Index to optimize the reporting query:
--
--   SELECT org_id, status, COUNT(*), SUM(amount)
--   FROM hotel_bookings
--   WHERE city = 'delhi'
--     AND created_at >= NOW() - INTERVAL '30 days'
--   GROUP BY org_id, status;
--
-- Rationale (see README.md "Query Optimization" section for the full
-- write-up):
--   * city is filtered with equality  -> put it first in the composite index.
--   * created_at is filtered with a range (>=) -> put it second; a btree
--     index can still use it efficiently once the leading column(s) are
--     fixed by equality.
--   * org_id, status, amount are added as INCLUDE columns (not part of the
--     index key) so Postgres can answer the whole query from the index
--     alone (an index-only scan) without a round-trip to the heap for
--     every matching row -- COUNT(*)/SUM(amount)/GROUP BY org_id,status all
--     get satisfied straight from the index.
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);

-- A plain btree on created_at alone is intentionally NOT added: for this
-- query shape (equality on city + range on created_at + grouping columns
-- that follow) a single composite/covering index outperforms two separate
-- single-column indexes, since Postgres would otherwise have to bitmap-AND
-- two indexes and still visit the heap for org_id/status/amount.
