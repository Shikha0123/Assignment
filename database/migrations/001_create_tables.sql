-- ---------------------------------------------------------------------------
-- 001_create_tables.sql
-- Core schema: hotel_bookings + booking_events
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS hotel_bookings (
    id             BIGSERIAL PRIMARY KEY,
    org_id         INTEGER      NOT NULL,
    hotel_id       INTEGER      NOT NULL,
    city           VARCHAR(100) NOT NULL,
    checkin_date   DATE         NOT NULL,
    checkout_date  DATE         NOT NULL,
    amount         NUMERIC(10, 2) NOT NULL CHECK (amount >= 0),
    status         VARCHAR(20)  NOT NULL DEFAULT 'confirmed'
                   CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT chk_checkout_after_checkin CHECK (checkout_date > checkin_date)
);

CREATE TABLE IF NOT EXISTS booking_events (
    id          BIGSERIAL PRIMARY KEY,
    booking_id  BIGINT       NOT NULL REFERENCES hotel_bookings (id) ON DELETE CASCADE,
    event_type  VARCHAR(50)  NOT NULL
                CHECK (event_type IN ('created', 'payment_received', 'confirmed',
                                       'modified', 'cancelled', 'checked_in', 'checked_out')),
    payload     JSONB        NOT NULL DEFAULT '{}'::jsonb,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- A booking is looked up by id very frequently when walking its event
-- history; this FK column benefits from an index (Postgres does not
-- automatically index foreign key columns, unlike the referenced primary
-- key side).
CREATE INDEX IF NOT EXISTS idx_booking_events_booking_id ON booking_events (booking_id);

COMMENT ON TABLE hotel_bookings IS 'One row per hotel booking made through the platform.';
COMMENT ON TABLE booking_events IS 'Append-only audit trail of lifecycle events for a booking.';
