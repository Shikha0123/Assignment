-- ---------------------------------------------------------------------------
-- 003_seed_data.sql
-- Generates >= 100 hotel_bookings rows (plus related booking_events) spread
-- across multiple orgs, hotels and cities, with created_at timestamps
-- spanning the last 180 days so the "last 30 days" reporting query in
-- 002_add_indexes.sql has real data to return, including for city = 'delhi'.
-- ---------------------------------------------------------------------------

DO $$
DECLARE
    cities        TEXT[]   := ARRAY['delhi', 'mumbai', 'bangalore', 'chennai', 'pune', 'hyderabad', 'kolkata'];
    statuses      TEXT[]   := ARRAY['pending', 'confirmed', 'cancelled', 'completed'];
    event_types   TEXT[]   := ARRAY['created', 'payment_received', 'confirmed', 'checked_in', 'checked_out'];
    total_rows    INT      := 300; -- comfortably over the required 100
    i             INT;
    v_org_id      INT;
    v_hotel_id    INT;
    v_city        TEXT;
    v_checkin     DATE;
    v_checkout    DATE;
    v_amount      NUMERIC(10,2);
    v_status      TEXT;
    v_created_at  TIMESTAMPTZ;
    v_booking_id  BIGINT;
    n_events      INT;
    j             INT;
BEGIN
    FOR i IN 1..total_rows LOOP
        v_org_id     := (1 + floor(random() * 5))::INT;               -- orgs 1-5
        v_hotel_id   := (1 + floor(random() * 25))::INT;              -- hotels 1-25
        v_city       := cities[1 + floor(random() * array_length(cities, 1))];
        v_checkin    := (CURRENT_DATE - (floor(random() * 200))::INT * INTERVAL '1 day')::DATE;
        v_checkout   := v_checkin + (1 + floor(random() * 6))::INT * INTERVAL '1 day';
        v_amount     := round((1500 + random() * 18000)::NUMERIC, 2);
        v_status     := statuses[1 + floor(random() * array_length(statuses, 1))];

        -- Skew created_at so a healthy chunk of rows (~40%) land inside the
        -- last 30 days -- this is the window the reporting query filters
        -- on, and we want 'delhi' rows in particular to be well represented
        -- there for demo/verification purposes.
        IF random() < 0.4 THEN
            v_created_at := now() - (floor(random() * 30))::INT * INTERVAL '1 day' - (floor(random()*86400))::INT * INTERVAL '1 second';
        ELSE
            v_created_at := now() - (30 + floor(random() * 150))::INT * INTERVAL '1 day' - (floor(random()*86400))::INT * INTERVAL '1 second';
        END IF;

        INSERT INTO hotel_bookings (org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
        VALUES (v_org_id, v_hotel_id, v_city, v_checkin, v_checkout, v_amount, v_status, v_created_at)
        RETURNING id INTO v_booking_id;

        -- 1-3 lifecycle events per booking
        n_events := 1 + floor(random() * 3)::INT;
        FOR j IN 1..n_events LOOP
            INSERT INTO booking_events (booking_id, event_type, payload, created_at)
            VALUES (
                v_booking_id,
                event_types[1 + floor(random() * array_length(event_types, 1))],
                jsonb_build_object('source', 'seed_script', 'sequence', j),
                v_created_at + (j * INTERVAL '5 minutes')
            );
        END LOOP;
    END LOOP;
END $$;

-- A handful of guaranteed, deterministic 'delhi' bookings created "today"
-- so the reporting query always returns a predictable, non-empty result
-- immediately after seeding, even if the random skew above happens not to
-- produce any.
INSERT INTO hotel_bookings (org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
VALUES
    (1, 3, 'delhi', CURRENT_DATE + 2, CURRENT_DATE + 5, 8200.00, 'confirmed', now() - INTERVAL '2 days'),
    (1, 7, 'delhi', CURRENT_DATE + 10, CURRENT_DATE + 12, 5400.00, 'pending', now() - INTERVAL '5 days'),
    (2, 3, 'delhi', CURRENT_DATE + 1, CURRENT_DATE + 3, 12500.00, 'confirmed', now() - INTERVAL '1 days'),
    (3, 11, 'delhi', CURRENT_DATE - 5, CURRENT_DATE - 2, 3300.00, 'completed', now() - INTERVAL '10 days');
