CREATE DATABASE car_sharing_physical_db;

CREATE SCHEMA IF NOT EXISTS car_sharing_ops;
SET search_path TO car_sharing_ops, public;

CREATE TABLE IF NOT EXISTS vehicle_type (
    vehicle_type_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL,
    description TEXT,
    CONSTRAINT uq_vehicle_type_type_name UNIQUE (type_name)
);

CREATE TABLE IF NOT EXISTS app_user (
    user_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone_number VARCHAR(30) NOT NULL,
    driver_license_no VARCHAR(50) NOT NULL,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_app_user_email UNIQUE (email),
    CONSTRAINT uq_app_user_phone_number UNIQUE (phone_number),
    CONSTRAINT uq_app_user_driver_license_no UNIQUE (driver_license_no),
    CONSTRAINT chk_app_user_registered_at_after_2000
        CHECK (registered_at::date > DATE '2000-01-01')
);


CREATE TABLE IF NOT EXISTS employee (
    employee_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone_number VARCHAR(30) UNIQUE,
    job_title VARCHAR(100) NOT NULL,
    hired_at DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_employee_email UNIQUE (email),
    CONSTRAINT chk_employee_hired_at_after_2000
        CHECK (hired_at > DATE '2000-01-01')
);


CREATE TABLE IF NOT EXISTS vehicle (
    vehicle_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vehicle_type_id BIGINT NOT NULL,
    vin VARCHAR(50) NOT NULL,
    registration_plate VARCHAR(20) NOT NULL,
    brand VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    production_year INTEGER NOT NULL,
    commissioned_at DATE,
    retired_at DATE,
    current_odometer_km NUMERIC(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT uq_vehicle_vin UNIQUE (vin),
    CONSTRAINT uq_vehicle_registration_plate UNIQUE (registration_plate),
    CONSTRAINT fk_vehicle_vehicle_type
        FOREIGN KEY (vehicle_type_id)
        REFERENCES vehicle_type (vehicle_type_id),
    CONSTRAINT chk_vehicle_production_year_reasonable
        CHECK (production_year BETWEEN 2000 AND EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER + 1),
    CONSTRAINT chk_vehicle_commissioned_at_after_2000
        CHECK (commissioned_at IS NULL OR commissioned_at > DATE '2000-01-01'),
    CONSTRAINT chk_vehicle_retired_after_commissioned
        CHECK (retired_at IS NULL OR commissioned_at IS NULL OR retired_at >= commissioned_at),
    CONSTRAINT chk_vehicle_odometer_nonnegative
        CHECK (current_odometer_km >= 0)
);


CREATE TABLE IF NOT EXISTS maintenance_event (
    maintenance_event_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vehicle_id BIGINT NOT NULL,
    maintenance_type VARCHAR(50) NOT NULL,
    description TEXT,
    opened_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    odometer_km NUMERIC(12,2) NOT NULL,
    maintenance_status VARCHAR(20) NOT NULL DEFAULT 'planned',
    cost_amount NUMERIC(10,2),
    CONSTRAINT fk_maintenance_event_vehicle
        FOREIGN KEY (vehicle_id)
        REFERENCES vehicle (vehicle_id),
    CONSTRAINT chk_maintenance_event_opened_after_2000
        CHECK (opened_at::date > DATE '2000-01-01'),
    CONSTRAINT chk_maintenance_event_completed_after_opened
        CHECK (completed_at IS NULL OR completed_at >= opened_at),
    CONSTRAINT chk_maintenance_event_odometer_nonnegative
        CHECK (odometer_km >= 0),
    CONSTRAINT chk_maintenance_event_cost_nonnegative
        CHECK (cost_amount IS NULL OR cost_amount >= 0),
    CONSTRAINT chk_maintenance_event_status
        CHECK (maintenance_status IN ('planned', 'in_progress', 'completed', 'cancelled'))
);




CREATE TABLE IF NOT EXISTS inspection_event (
    inspection_event_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vehicle_id BIGINT NOT NULL,
    employee_id BIGINT NOT NULL,
    inspection_type VARCHAR(50) NOT NULL,
    inspection_result VARCHAR(20) NOT NULL,
    notes TEXT,
    inspected_at TIMESTAMPTZ NOT NULL,
    odometer_km NUMERIC(12,2) NOT NULL,
    CONSTRAINT fk_inspection_event_vehicle
        FOREIGN KEY (vehicle_id)
        REFERENCES vehicle (vehicle_id),
    CONSTRAINT fk_inspection_event_employee
        FOREIGN KEY (employee_id)
        REFERENCES employee (employee_id),
    CONSTRAINT chk_inspection_event_date_after_2000
        CHECK (inspected_at::date > DATE '2000-01-01'),
    CONSTRAINT chk_inspection_event_odometer_nonnegative
        CHECK (odometer_km >= 0),
    CONSTRAINT chk_inspection_event_result
        CHECK (inspection_result IN ('passed', 'failed', 'requires_follow_up'))
);

CREATE TABLE IF NOT EXISTS reservation (
    reservation_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL,
    vehicle_id BIGINT NOT NULL,
    reserved_from TIMESTAMPTZ NOT NULL,
    reserved_until TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cancelled_at TIMESTAMPTZ,
    reservation_status VARCHAR(20) NOT NULL DEFAULT 'active',
    CONSTRAINT fk_reservation_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id),
    CONSTRAINT fk_reservation_vehicle
        FOREIGN KEY (vehicle_id)
        REFERENCES vehicle (vehicle_id),
    CONSTRAINT chk_reservation_dates_after_2000
        CHECK (
            reserved_from::date > DATE '2000-01-01'
            AND reserved_until::date > DATE '2000-01-01'
            AND created_at::date > DATE '2000-01-01'
        ),
    CONSTRAINT chk_reservation_until_after_from
        CHECK (reserved_until > reserved_from),
    CONSTRAINT chk_reservation_cancelled_after_created
        CHECK (cancelled_at IS NULL OR cancelled_at >= created_at),
    CONSTRAINT chk_reservation_status
        CHECK (reservation_status IN ('active', 'fulfilled', 'cancelled', 'expired'))
);


CREATE TABLE IF NOT EXISTS trip (
    trip_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL,
    vehicle_id BIGINT NOT NULL,
    reservation_id BIGINT UNIQUE,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    start_odometer_km NUMERIC(12,2) NOT NULL,
    end_odometer_km NUMERIC(12,2),
    distance_km NUMERIC(12,2) GENERATED ALWAYS AS (
        CASE
            WHEN end_odometer_km IS NOT NULL THEN end_odometer_km - start_odometer_km
            ELSE NULL
        END
    ) STORED,
    duration_minutes INTEGER GENERATED ALWAYS AS (
        CASE
            WHEN ended_at IS NOT NULL THEN GREATEST(FLOOR(EXTRACT(EPOCH FROM (ended_at - started_at)) / 60), 0)::INTEGER
            ELSE NULL
        END
    ) STORED,
    total_cost NUMERIC(10,2),
    trip_status VARCHAR(20) NOT NULL DEFAULT 'in_progress',
    CONSTRAINT fk_trip_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id),
    CONSTRAINT fk_trip_vehicle
        FOREIGN KEY (vehicle_id)
        REFERENCES vehicle (vehicle_id),
    CONSTRAINT fk_trip_reservation
        FOREIGN KEY (reservation_id)
        REFERENCES reservation (reservation_id),
    CONSTRAINT chk_trip_started_after_2000
        CHECK (started_at::date > DATE '2000-01-01'),
    CONSTRAINT chk_trip_ended_after_started
        CHECK (ended_at IS NULL OR ended_at >= started_at),
    CONSTRAINT chk_trip_start_odometer_nonnegative
        CHECK (start_odometer_km >= 0),
    CONSTRAINT chk_trip_end_odometer_valid
        CHECK (end_odometer_km IS NULL OR end_odometer_km >= start_odometer_km),
    CONSTRAINT chk_trip_total_cost_nonnegative
        CHECK (total_cost IS NULL OR total_cost >= 0),
    CONSTRAINT chk_trip_status
        CHECK (trip_status IN ('in_progress', 'completed', 'cancelled'))
);

CREATE TABLE IF NOT EXISTS payment (
    payment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    trip_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    currency_code CHAR(3) NOT NULL DEFAULT 'USD',
    payment_method VARCHAR(30) NOT NULL,
    payment_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_payment_trip_id UNIQUE (trip_id),
    CONSTRAINT fk_payment_trip
        FOREIGN KEY (trip_id)
        REFERENCES trip (trip_id),
    CONSTRAINT fk_payment_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id),
    CONSTRAINT chk_payment_amount_nonnegative
        CHECK (amount >= 0),
    CONSTRAINT chk_payment_currency_upper
        CHECK (currency_code = UPPER(currency_code)),
    CONSTRAINT chk_payment_method
        CHECK (payment_method IN ('card', 'wallet', 'bank_transfer')),
    CONSTRAINT chk_payment_status
        CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded')),
    CONSTRAINT chk_payment_dates_after_2000
        CHECK (
            created_at::date > DATE '2000-01-01'
            AND (paid_at IS NULL OR paid_at::date > DATE '2000-01-01')
        )
);



CREATE TABLE IF NOT EXISTS rating (
    rating_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    trip_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    vehicle_id BIGINT NOT NULL,
    score INTEGER NOT NULL,
    comment_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_rating_trip_id UNIQUE (trip_id),
    CONSTRAINT fk_rating_trip
        FOREIGN KEY (trip_id)
        REFERENCES trip (trip_id),
    CONSTRAINT fk_rating_user
        FOREIGN KEY (user_id)
        REFERENCES app_user (user_id),
    CONSTRAINT fk_rating_vehicle
        FOREIGN KEY (vehicle_id)
        REFERENCES vehicle (vehicle_id),
    CONSTRAINT chk_rating_score
        CHECK (score BETWEEN 1 AND 5),
    CONSTRAINT chk_rating_created_after_2000
        CHECK (created_at::date > DATE '2000-01-01')
);

CREATE TABLE IF NOT EXISTS maintenance_event_employee (
    maintenance_event_id BIGINT NOT NULL,
    employee_id BIGINT NOT NULL,
    assigned_role VARCHAR(50) NOT NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_maintenance_event_employee
        PRIMARY KEY (maintenance_event_id, employee_id),
    CONSTRAINT fk_mee_maintenance_event
        FOREIGN KEY (maintenance_event_id)
        REFERENCES maintenance_event (maintenance_event_id),
    CONSTRAINT fk_mee_employee
        FOREIGN KEY (employee_id)
        REFERENCES employee (employee_id),
    CONSTRAINT chk_mee_assigned_after_2000
        CHECK (assigned_at::date > DATE '2000-01-01')
);

CREATE TABLE IF NOT EXISTS vehicle_status_history (
    vehicle_status_history_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vehicle_id BIGINT NOT NULL,
    status_code VARCHAR(30) NOT NULL,
    reservation_id BIGINT,
    trip_id BIGINT,
    maintenance_event_id BIGINT,
    inspection_event_id BIGINT,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_to TIMESTAMPTZ,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_vsh_vehicle
        FOREIGN KEY (vehicle_id)
        REFERENCES vehicle (vehicle_id),
    CONSTRAINT fk_vsh_reservation
        FOREIGN KEY (reservation_id)
        REFERENCES reservation (reservation_id),
    CONSTRAINT fk_vsh_trip
        FOREIGN KEY (trip_id)
        REFERENCES trip (trip_id),
    CONSTRAINT fk_vsh_maintenance_event
        FOREIGN KEY (maintenance_event_id)
        REFERENCES maintenance_event (maintenance_event_id),
    CONSTRAINT fk_vsh_inspection_event
        FOREIGN KEY (inspection_event_id)
        REFERENCES inspection_event (inspection_event_id),
    CONSTRAINT chk_vsh_status_code
        CHECK (status_code IN ('available', 'reserved', 'in_use', 'maintenance', 'inspection', 'unavailable')),
    CONSTRAINT chk_vsh_valid_from_after_2000
        CHECK (valid_from::date > DATE '2000-01-01'),
    CONSTRAINT chk_vsh_valid_to_after_from
        CHECK (valid_to IS NULL OR valid_to > valid_from),
    CONSTRAINT chk_vsh_recorded_after_2000
        CHECK (recorded_at::date > DATE '2000-01-01')
);


CREATE INDEX IF NOT EXISTS idx_vehicle_vehicle_type_id
    ON vehicle (vehicle_type_id);

CREATE INDEX IF NOT EXISTS idx_maintenance_event_vehicle_id
    ON maintenance_event (vehicle_id);

CREATE INDEX IF NOT EXISTS idx_inspection_event_vehicle_id
    ON inspection_event (vehicle_id);

CREATE INDEX IF NOT EXISTS idx_inspection_event_employee_id
    ON inspection_event (employee_id);

CREATE INDEX IF NOT EXISTS idx_reservation_user_id
    ON reservation (user_id);

CREATE INDEX IF NOT EXISTS idx_reservation_vehicle_id
    ON reservation (vehicle_id);

CREATE INDEX IF NOT EXISTS idx_trip_user_id
    ON trip (user_id);

CREATE INDEX IF NOT EXISTS idx_trip_vehicle_id
    ON trip (vehicle_id);

CREATE INDEX IF NOT EXISTS idx_payment_user_id
    ON payment (user_id);

CREATE INDEX IF NOT EXISTS idx_rating_user_id
    ON rating (user_id);

CREATE INDEX IF NOT EXISTS idx_rating_vehicle_id
    ON rating (vehicle_id);

CREATE INDEX IF NOT EXISTS idx_vsh_vehicle_id
    ON vehicle_status_history (vehicle_id);

-- Consistency of inserted data is ensured:
-- 1) Foreign key values are taken only from rows that already exist in parent tables,
--    so each relationship points to a valid business object.
-- 2) INSERT statements use ON CONFLICT DO NOTHING or WHERE NOT EXISTS, which makes the script
--    rerunnable and prevents duplicate rows if the script is executed more than once.
-- 3) Business values are inserted in a logically valid sequence: for example, a reservation
--    belongs to an existing user and vehicle, a trip refers to an existing reservation,
--    a payment refers to an existing trip and user, and a rating refers to an existing trip,
--    user, and vehicle.
-- 4) CHECK, NOT NULL, UNIQUE, and DEFAULT constraints validate the inserted data at write time,
--    preventing invalid dates, negative measured values, duplicate identifiers, and missing
--    mandatory attributes.
-- 5) Sample timestamps and status values are chosen so that the rows remain semantically
--    consistent, for example a completed trip has a start time before the end time and
--    non-negative odometer and cost values.


INSERT INTO vehicle_type (type_name, description)
VALUES
    ('Sedan', 'Standard passenger car'),
    ('SUV', 'Sport utility vehicle')
ON CONFLICT (type_name) DO NOTHING;

INSERT INTO app_user (first_name, last_name, email, phone_number, driver_license_no, registered_at, is_active)
VALUES
    ('Anna', 'Shevchenko', 'anna.shev@example.com', '380671234567', 'AB1234567', TIMESTAMPTZ '2024-03-13 10:15:00+02', TRUE),
    ('Maksym', 'Bondarenko', 'maksym.bond@example.com', '380501112233', 'CD7654321', TIMESTAMPTZ '2024-04-02 11:30:00+03', TRUE)
ON CONFLICT (email) DO NOTHING;

INSERT INTO employee (first_name, last_name, email, phone_number, job_title, hired_at, is_active)
VALUES
    ('Olena', 'Petrenko', 'olena.petrenko@company.com', '380661234567', 'Technician', DATE '2022-05-10', TRUE),
    ('Ihor', 'Koval', 'ihor.koval@company.com', '380931234567', 'Inspector', DATE '2023-01-15', TRUE)
ON CONFLICT (email) DO NOTHING;

INSERT INTO vehicle (
    vehicle_type_id, vin, registration_plate, brand, model,
    production_year, commissioned_at, retired_at, current_odometer_km
)
SELECT
    vt.vehicle_type_id,
    v.vin,
    v.registration_plate,
    v.brand,
    v.model,
    v.production_year,
    v.commissioned_at,
    v.retired_at,
    v.current_odometer_km
FROM (
    VALUES
        ('Sedan', '1HGCM82633A004352', 'AB1234CD', 'Toyota', 'Corolla', 2015, DATE '2015-06-15', NULL::DATE, 75200.50::NUMERIC(12,2)),
        ('SUV',   '2T1BURHE5FC334455', 'BC5678DE', 'Hyundai', 'Tucson', 2019, DATE '2019-09-01', NULL::DATE, 48110.00::NUMERIC(12,2))
) AS v(type_name, vin, registration_plate, brand, model, production_year, commissioned_at, retired_at, current_odometer_km)
JOIN vehicle_type vt
  ON vt.type_name = v.type_name
ON CONFLICT (vin) DO NOTHING;

INSERT INTO maintenance_event (
    vehicle_id, maintenance_type, description, opened_at, completed_at,
    odometer_km, maintenance_status, cost_amount
)
SELECT
    veh.vehicle_id,
    x.maintenance_type,
    x.description,
    x.opened_at,
    x.completed_at,
    x.odometer_km,
    x.maintenance_status,
    x.cost_amount
FROM (
    VALUES
        ('1HGCM82633A004352', 'Oil Change', 'Changed engine oil and filter', TIMESTAMPTZ '2024-02-10 09:00:00+02', TIMESTAMPTZ '2024-02-10 10:00:00+02', 75500.00::NUMERIC(12,2), 'completed', 120.50::NUMERIC(10,2)),
        ('2T1BURHE5FC334455', 'Brake Inspection', 'Checked front and rear brakes', TIMESTAMPTZ '2024-03-05 13:00:00+02', TIMESTAMPTZ '2024-03-05 14:10:00+02', 48200.00::NUMERIC(12,2), 'completed', 85.00::NUMERIC(10,2))
) AS x(vin, maintenance_type, description, opened_at, completed_at, odometer_km, maintenance_status, cost_amount)
JOIN vehicle veh
  ON veh.vin = x.vin
WHERE NOT EXISTS (
    SELECT 1
    FROM maintenance_event me
    WHERE me.vehicle_id = veh.vehicle_id
      AND me.maintenance_type = x.maintenance_type
      AND me.opened_at = x.opened_at
);

INSERT INTO inspection_event (
    vehicle_id, employee_id, inspection_type, inspection_result, notes, inspected_at, odometer_km
)
SELECT
    veh.vehicle_id,
    emp.employee_id,
    x.inspection_type,
    x.inspection_result,
    x.notes,
    x.inspected_at,
    x.odometer_km
FROM (
    VALUES
        ('1HGCM82633A004352', 'ihor.koval@company.com', 'Annual Check', 'passed', 'All systems functional', TIMESTAMPTZ '2024-02-01 14:30:00+02', 75000.00::NUMERIC(12,2)),
        ('2T1BURHE5FC334455', 'ihor.koval@company.com', 'Safety Check', 'requires_follow_up', 'Tire replacement recommended', TIMESTAMPTZ '2024-03-01 09:15:00+02', 48050.00::NUMERIC(12,2))
) AS x(vin, employee_email, inspection_type, inspection_result, notes, inspected_at, odometer_km)
JOIN vehicle veh
  ON veh.vin = x.vin
JOIN employee emp
  ON emp.email = x.employee_email
WHERE NOT EXISTS (
    SELECT 1
    FROM inspection_event ie
    WHERE ie.vehicle_id = veh.vehicle_id
      AND ie.employee_id = emp.employee_id
      AND ie.inspection_type = x.inspection_type
      AND ie.inspected_at = x.inspected_at
);

INSERT INTO reservation (
    user_id, vehicle_id, reserved_from, reserved_until, created_at, cancelled_at, reservation_status
)
SELECT
    usr.user_id,
    veh.vehicle_id,
    x.reserved_from,
    x.reserved_until,
    x.created_at,
    x.cancelled_at,
    x.reservation_status
FROM (
    VALUES
        ('anna.shev@example.com',   '1HGCM82633A004352', TIMESTAMPTZ '2024-03-20 09:00:00+02', TIMESTAMPTZ '2024-03-20 18:00:00+02', TIMESTAMPTZ '2024-03-13 12:00:00+02', NULL::TIMESTAMPTZ, 'fulfilled'),
        ('maksym.bond@example.com', '2T1BURHE5FC334455', TIMESTAMPTZ '2024-04-10 08:00:00+03', TIMESTAMPTZ '2024-04-10 12:00:00+03', TIMESTAMPTZ '2024-04-08 16:20:00+03', NULL::TIMESTAMPTZ, 'active')
) AS x(user_email, vin, reserved_from, reserved_until, created_at, cancelled_at, reservation_status)
JOIN app_user usr
  ON usr.email = x.user_email
JOIN vehicle veh
  ON veh.vin = x.vin
WHERE NOT EXISTS (
    SELECT 1
    FROM reservation r
    WHERE r.user_id = usr.user_id
      AND r.vehicle_id = veh.vehicle_id
      AND r.reserved_from = x.reserved_from
);

INSERT INTO trip (
    user_id, vehicle_id, reservation_id, started_at, ended_at,
    start_odometer_km, end_odometer_km, total_cost, trip_status
)
SELECT
    usr.user_id,
    veh.vehicle_id,
    res.reservation_id,
    x.started_at,
    x.ended_at,
    x.start_odometer_km,
    x.end_odometer_km,
    x.total_cost,
    x.trip_status
FROM (
    VALUES
        ('anna.shev@example.com', '1HGCM82633A004352', TIMESTAMPTZ '2024-03-20 09:00:00+02', TIMESTAMPTZ '2024-03-20 09:15:00+02', TIMESTAMPTZ '2024-03-20 10:45:00+02', 75200.50::NUMERIC(12,2), 75250.50::NUMERIC(12,2), 350.00::NUMERIC(10,2), 'completed'),
        ('maksym.bond@example.com', '2T1BURHE5FC334455', TIMESTAMPTZ '2024-04-10 08:00:00+03', TIMESTAMPTZ '2024-04-10 08:10:00+03', TIMESTAMPTZ '2024-04-10 09:05:00+03', 48110.00::NUMERIC(12,2), 48142.50::NUMERIC(12,2), 210.00::NUMERIC(10,2), 'completed')
) AS x(user_email, vin, reservation_from, started_at, ended_at, start_odometer_km, end_odometer_km, total_cost, trip_status)
JOIN app_user usr
  ON usr.email = x.user_email
JOIN vehicle veh
  ON veh.vin = x.vin
LEFT JOIN reservation res
  ON res.user_id = usr.user_id
 AND res.vehicle_id = veh.vehicle_id
 AND res.reserved_from = x.reservation_from
ON CONFLICT (reservation_id) DO NOTHING;

INSERT INTO payment (
    trip_id, user_id, amount, currency_code, payment_method, payment_status, paid_at, created_at
)
SELECT
    tr.trip_id,
    usr.user_id,
    x.amount,
    x.currency_code,
    x.payment_method,
    x.payment_status,
    x.paid_at,
    x.created_at
FROM (
    VALUES
        ('anna.shev@example.com', '1HGCM82633A004352', TIMESTAMPTZ '2024-03-20 09:15:00+02', 350.00::NUMERIC(10,2), 'USD', 'card', 'paid', TIMESTAMPTZ '2024-03-20 10:50:00+02', TIMESTAMPTZ '2024-03-20 10:46:00+02'),
        ('maksym.bond@example.com', '2T1BURHE5FC334455', TIMESTAMPTZ '2024-04-10 08:10:00+03', 210.00::NUMERIC(10,2), 'USD', 'wallet', 'paid', TIMESTAMPTZ '2024-04-10 09:10:00+03', TIMESTAMPTZ '2024-04-10 09:06:00+03')
) AS x(user_email, vin, trip_started_at, amount, currency_code, payment_method, payment_status, paid_at, created_at)
JOIN app_user usr
  ON usr.email = x.user_email
JOIN vehicle veh
  ON veh.vin = x.vin
JOIN trip tr
  ON tr.user_id = usr.user_id
 AND tr.vehicle_id = veh.vehicle_id
 AND tr.started_at = x.trip_started_at
ON CONFLICT (trip_id) DO NOTHING;

INSERT INTO rating (
    trip_id, user_id, vehicle_id, score, comment_text, created_at
)
SELECT
    tr.trip_id,
    usr.user_id,
    veh.vehicle_id,
    x.score,
    x.comment_text,
    x.created_at
FROM (
    VALUES
        ('anna.shev@example.com', '1HGCM82633A004352', TIMESTAMPTZ '2024-03-20 09:15:00+02', 5, 'Excellent ride, very clean!', TIMESTAMPTZ '2024-03-20 11:00:00+02'),
        ('maksym.bond@example.com', '2T1BURHE5FC334455', TIMESTAMPTZ '2024-04-10 08:10:00+03', 4, 'Smooth trip, but tires need attention.', TIMESTAMPTZ '2024-04-10 09:20:00+03')
) AS x(user_email, vin, trip_started_at, score, comment_text, created_at)
JOIN app_user usr
  ON usr.email = x.user_email
JOIN vehicle veh
  ON veh.vin = x.vin
JOIN trip tr
  ON tr.user_id = usr.user_id
 AND tr.vehicle_id = veh.vehicle_id
 AND tr.started_at = x.trip_started_at
ON CONFLICT (trip_id) DO NOTHING;

INSERT INTO maintenance_event_employee (
    maintenance_event_id, employee_id, assigned_role, assigned_at
)
SELECT
    me.maintenance_event_id,
    emp.employee_id,
    x.assigned_role,
    x.assigned_at
FROM (
    VALUES
        ('1HGCM82633A004352', TIMESTAMPTZ '2024-02-10 09:00:00+02', 'olena.petrenko@company.com', 'Technician', TIMESTAMPTZ '2024-02-10 08:45:00+02'),
        ('2T1BURHE5FC334455', TIMESTAMPTZ '2024-03-05 13:00:00+02', 'olena.petrenko@company.com', 'Technician', TIMESTAMPTZ '2024-03-05 12:45:00+02')
) AS x(vin, opened_at, employee_email, assigned_role, assigned_at)
JOIN vehicle veh
  ON veh.vin = x.vin
JOIN maintenance_event me
  ON me.vehicle_id = veh.vehicle_id
 AND me.opened_at = x.opened_at
JOIN employee emp
  ON emp.email = x.employee_email
ON CONFLICT (maintenance_event_id, employee_id) DO NOTHING;

INSERT INTO vehicle_status_history (
    vehicle_id, status_code, reservation_id, trip_id, maintenance_event_id, inspection_event_id,
    valid_from, valid_to, recorded_at
)
SELECT
    veh.vehicle_id,
    x.status_code,
    res.reservation_id,
    tr.trip_id,
    me.maintenance_event_id,
    ie.inspection_event_id,
    x.valid_from,
    x.valid_to,
    x.recorded_at
FROM (
    VALUES
        ('1HGCM82633A004352', 'in_use',     TIMESTAMPTZ '2024-03-20 09:00:00+02', TIMESTAMPTZ '2024-03-20 09:15:00+02', NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ, TIMESTAMPTZ '2024-03-20 09:15:00+02', TIMESTAMPTZ '2024-03-20 10:45:00+02', TIMESTAMPTZ '2024-03-20 09:15:01+02'),
        ('2T1BURHE5FC334455', 'inspection', NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ, TIMESTAMPTZ '2024-03-01 09:15:00+02', TIMESTAMPTZ '2024-03-01 09:15:00+02', TIMESTAMPTZ '2024-03-01 09:45:00+02', TIMESTAMPTZ '2024-03-01 09:15:10+02')
) AS x(vin, status_code, reservation_from, trip_started_at, maintenance_opened_at, inspection_at, valid_from, valid_to, recorded_at)
JOIN vehicle veh
  ON veh.vin = x.vin
LEFT JOIN reservation res
  ON res.vehicle_id = veh.vehicle_id
 AND res.reserved_from = x.reservation_from
LEFT JOIN trip tr
  ON tr.vehicle_id = veh.vehicle_id
 AND tr.started_at = x.trip_started_at
LEFT JOIN maintenance_event me
  ON me.vehicle_id = veh.vehicle_id
 AND me.opened_at = x.maintenance_opened_at
LEFT JOIN inspection_event ie
  ON ie.vehicle_id = veh.vehicle_id
 AND ie.inspected_at = x.inspection_at
WHERE NOT EXISTS (
    SELECT 1
    FROM vehicle_status_history vsh
    WHERE vsh.vehicle_id = veh.vehicle_id
      AND vsh.status_code = x.status_code
      AND vsh.valid_from = x.valid_from
);


ALTER TABLE car_sharing_ops.vehicle_type ADD COLUMN IF NOT EXISTS record_ts DATE;
UPDATE car_sharing_ops.vehicle_type SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
ALTER TABLE car_sharing_ops.vehicle_type ALTER COLUMN record_ts SET DEFAULT CURRENT_DATE;
ALTER TABLE car_sharing_ops.vehicle_type ALTER COLUMN record_ts SET NOT NULL;

ALTER TABLE car_sharing_ops.app_user ADD COLUMN IF NOT EXISTS record_ts DATE;
UPDATE car_sharing_ops.app_user SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
ALTER TABLE car_sharing_ops.app_user ALTER COLUMN record_ts SET DEFAULT CURRENT_DATE;
ALTER TABLE car_sharing_ops.app_user ALTER COLUMN record_ts SET NOT NULL;

ALTER TABLE car_sharing_ops.employee ADD COLUMN IF NOT EXISTS record_ts DATE;
UPDATE car_sharing_ops.employee SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
ALTER TABLE car_sharing_ops.employee ALTER COLUMN record_ts SET DEFAULT CURRENT_DATE;
ALTER TABLE car_sharing_ops.employee ALTER COLUMN record_ts SET NOT NULL;

ALTER TABLE car_sharing_ops.vehicle ADD COLUMN IF NOT EXISTS record_ts DATE;
UPDATE car_sharing_ops.vehicle SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
ALTER TABLE car_sharing_ops.vehicle ALTER COLUMN record_ts SET DEFAULT CURRENT_DATE;
ALTER TABLE car_sharing_ops.vehicle ALTER COLUMN record_ts SET NOT NULL;


ALTER TABLE car_sharing_ops.maintenance_event ADD COLUMN IF NOT EXISTS record_ts DATE;
UPDATE car_sharing_ops.maintenance_event SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
ALTER TABLE car_sharing_ops.maintenance_event ALTER COLUMN record_ts SET DEFAULT CURRENT_DATE;
ALTER TABLE car_sharing_ops.maintenance_event ALTER COLUMN record_ts SET NOT NULL;


ALTER TABLE car_sharing_ops.inspection_event ADD COLUMN IF NOT EXISTS record_ts DATE;
UPDATE car_sharing_ops.inspection_event SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
ALTER TABLE car_sharing_ops.inspection_event ALTER COLUMN record_ts SET DEFAULT CURRENT_DATE;
ALTER TABLE car_sharing_ops.inspection_event ALTER COLUMN record_ts SET NOT NULL;


ALTER TABLE car_sharing_ops.reservation ADD COLUMN IF NOT EXISTS record_ts DATE;
UPDATE car_sharing_ops.reservation SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
ALTER TABLE car_sharing_ops.reservation ALTER COLUMN record_ts SET DEFAULT CURRENT_DATE;
ALTER TABLE car_sharing_ops.reservation ALTER COLUMN record_ts SET NOT NULL;


ALTER TABLE car_sharing_ops.trip ADD COLUMN IF NOT EXISTS record_ts DATE;
UPDATE car_sharing_ops.trip SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
ALTER TABLE car_sharing_ops.trip ALTER COLUMN record_ts SET DEFAULT CURRENT_DATE;
ALTER TABLE car_sharing_ops.trip ALTER COLUMN record_ts SET NOT NULL;


ALTER TABLE car_sharing_ops.payment ADD COLUMN IF NOT EXISTS record_ts DATE;
UPDATE car_sharing_ops.payment SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
ALTER TABLE car_sharing_ops.payment ALTER COLUMN record_ts SET DEFAULT CURRENT_DATE;
ALTER TABLE car_sharing_ops.payment ALTER COLUMN record_ts SET NOT NULL;


ALTER TABLE car_sharing_ops.rating ADD COLUMN IF NOT EXISTS record_ts DATE;
UPDATE car_sharing_ops.rating SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
ALTER TABLE car_sharing_ops.rating ALTER COLUMN record_ts SET DEFAULT CURRENT_DATE;
ALTER TABLE car_sharing_ops.rating ALTER COLUMN record_ts SET NOT NULL;


ALTER TABLE car_sharing_ops.maintenance_event_employee ADD COLUMN IF NOT EXISTS record_ts DATE;
UPDATE car_sharing_ops.maintenance_event_employee SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
ALTER TABLE car_sharing_ops.maintenance_event_employee ALTER COLUMN record_ts SET DEFAULT CURRENT_DATE;
ALTER TABLE car_sharing_ops.maintenance_event_employee ALTER COLUMN record_ts SET NOT NULL;


ALTER TABLE car_sharing_ops.vehicle_status_history ADD COLUMN IF NOT EXISTS record_ts DATE;
UPDATE car_sharing_ops.vehicle_status_history SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
ALTER TABLE car_sharing_ops.vehicle_status_history ALTER COLUMN record_ts SET DEFAULT CURRENT_DATE;
ALTER TABLE car_sharing_ops.vehicle_status_history ALTER COLUMN record_ts SET NOT NULL;