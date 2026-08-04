--
--CREATE EXTENSION IF NOT EXISTS file_fdw;
--
--drop server if exists csv_file_server CASCADE;
--
--CREATE SERVER IF NOT EXISTS csv_file_server
--
--FOREIGN DATA WRAPPER file_fdw;
--
--
--
--CREATE SCHEMA IF NOT EXISTS sa_bookings;

DROP FOREIGN TABLE IF EXISTS sa_bookings.ext_bookings;

CREATE FOREIGN TABLE sa_bookings.ext_bookings
(
    booking_id             TEXT,
    customer_id            TEXT,
    gender                 TEXT,
    age                    TEXT,
    travel_type            TEXT,
    travel_class           TEXT,
    flight_distance        TEXT,
    booking_channel        TEXT,
    payment_method         TEXT,
    ticket_price           TEXT,
    loyalty_level          TEXT,
    travel_insurance       TEXT,
    booking_date           TEXT,
    date_key               TEXT,
    year                   TEXT,
    quarter                TEXT,
    month                  TEXT,
    month_name             TEXT,
    day                    TEXT,
    week                   TEXT,
    day_of_week            TEXT,
    airport_fee            TEXT,
    promotion_discount     TEXT,
    operating_cost         TEXT,
    profit                 TEXT
)
SERVER csv_file_server
OPTIONS
(
    filename 'C:/PyhonTasks/final_ProjDWH/booking_sales_increment.csv',
    format 'csv',
    header 'true',
    delimiter ',',
    quote '"',
    escape '"',
    null ''
);




/* ============================================================
   2. CUSTOMER SATISFACTIONS DATASET
   Schema: sa_customer_satisfactions
   External table: ext_customer_satisfactions
   Source table: src_customer_satisfactions
   ============================================================ */

CREATE SCHEMA IF NOT EXISTS sa_customer_satisfactions;

DROP FOREIGN TABLE IF EXISTS sa_customer_satisfactions.ext_customer_satisfactions;

CREATE FOREIGN TABLE sa_customer_satisfactions.ext_customer_satisfactions
(
    unnamed_0                            TEXT,
    customer_id                          TEXT,
    gender                               TEXT,
    customer_type                        TEXT,
    age                                  TEXT,
    travel_type                          TEXT,
    travel_class                         TEXT,
    flight_distance                      TEXT,
    inflight_wifi_service                TEXT,
    departure_arrival_time_convenient    TEXT,
    ease_of_online_booking               TEXT,
    gate_location                        TEXT,
    food_and_drink                       TEXT,
    online_boarding                      TEXT,
    seat_comfort                         TEXT,
    inflight_entertainment               TEXT,
    on_board_service                     TEXT,
    leg_room_service                     TEXT,
    baggage_handling                     TEXT,
    checkin_service                      TEXT,
    inflight_service                     TEXT,
    cleanliness                          TEXT,
    departure_delay_minutes              TEXT,
    arrival_delay_minutes                TEXT,
    satisfaction                         TEXT,
    survey_id                            TEXT,
    survey_date                          TEXT,
    date_key                             TEXT,
    year                                 TEXT,
    quarter                              TEXT,
    month                                TEXT,
    month_name                           TEXT,
    day                                  TEXT,
    week                                 TEXT,
    day_of_week                          TEXT
)
SERVER csv_file_server
OPTIONS
(
    filename 'C:/PyhonTasks/final_ProjDWH/customer_satisfaction_increment.csv',
    format 'csv',
    header 'true',
    delimiter ',',
    quote '"',
    escape '"',
    null ''
);

/* ============================================================
   DML: load sa_bookings.src_bookings with deduplication
   ============================================================ */

delete from sa_bookings.src_bookings where booking_id like 'BK_INC_%'

WITH raw_data AS
(
    SELECT DISTINCT
        NULLIF(BTRIM(booking_id), '')             AS booking_id,
        NULLIF(BTRIM(customer_id), '')            AS customer_id,
        NULLIF(BTRIM(gender), '')                 AS gender,
        NULLIF(BTRIM(age), '')                    AS age,
        NULLIF(BTRIM(travel_type), '')            AS travel_type,
        NULLIF(BTRIM(travel_class), '')           AS travel_class,
        NULLIF(BTRIM(flight_distance), '')        AS flight_distance,
        NULLIF(BTRIM(booking_channel), '')        AS booking_channel,
        NULLIF(BTRIM(payment_method), '')         AS payment_method,
        NULLIF(BTRIM(ticket_price), '')           AS ticket_price,
        NULLIF(BTRIM(loyalty_level), '')          AS loyalty_level,
        NULLIF(BTRIM(travel_insurance), '')       AS travel_insurance,
        NULLIF(BTRIM(booking_date), '')           AS booking_date,
        NULLIF(BTRIM(date_key), '')               AS date_key,
        NULLIF(BTRIM(year), '')                   AS year,
        NULLIF(BTRIM(quarter), '')                AS quarter,
        NULLIF(BTRIM(month), '')                  AS month,
        NULLIF(BTRIM(month_name), '')             AS month_name,
        NULLIF(BTRIM(day), '')                    AS day,
        NULLIF(BTRIM(week), '')                   AS week,
        NULLIF(BTRIM(day_of_week), '')            AS day_of_week,
        NULLIF(BTRIM(airport_fee), '')            AS airport_fee,
        NULLIF(BTRIM(promotion_discount), '')     AS promotion_discount,
        NULLIF(BTRIM(operating_cost), '')         AS operating_cost,
        NULLIF(BTRIM(profit), '')                 AS profit
    FROM sa_bookings.ext_bookings
),
deduplicated AS
(
    SELECT
        raw_data.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY COALESCE
            (
                booking_id,
                'NO_BOOKING_ID_' || MD5
                (
                    CONCAT_WS
                    (
                        '|',
                        customer_id,
                        gender,
                        age,
                        travel_type,
                        travel_class,
                        flight_distance,
                        booking_channel,
                        payment_method,
                        ticket_price,
                        loyalty_level,
                        travel_insurance,
                        booking_date,
                        date_key,
                        year,
                        quarter,
                        month,
                        month_name,
                        day,
                        week,
                        day_of_week,
                        airport_fee,
                        promotion_discount,
                        operating_cost,
                        profit
                    )
                )
            )
            ORDER BY date_key NULLS LAST,
                     booking_date NULLS LAST,
                     customer_id NULLS LAST
        ) AS rn
    FROM raw_data
)
INSERT INTO sa_bookings.src_bookings
(
    booking_id,
    customer_id,
    gender,
    age,
    travel_type,
    travel_class,
    flight_distance,
    booking_channel,
    payment_method,
    ticket_price,
    loyalty_level,
    travel_insurance,
    booking_date,
    date_key,
    year,
    quarter,
    month,
    month_name,
    day,
    week,
    day_of_week,
    airport_fee,
    promotion_discount,
    operating_cost,
    profit
)
SELECT
    booking_id,
    customer_id,
    gender,
    age,
    travel_type,
    travel_class,
    flight_distance,
    booking_channel,
    payment_method,
    ticket_price,
    loyalty_level,
    travel_insurance,
    booking_date,
    date_key,
    year,
    quarter,
    month,
    month_name,
    day,
    week,
    day_of_week,
    airport_fee,
    promotion_discount,
    operating_cost,
    profit
FROM deduplicated
WHERE rn = 1;




/* ============================================================
   DML: load sa_customer_satisfactions.src_customer_satisfactions
   with deduplication
   ============================================================ */
delete from sa_customer_satisfactions.src_customer_satisfactions where survey_id like 'S_INC_%'

WITH raw_data AS
(
    SELECT DISTINCT
        NULLIF(BTRIM(unnamed_0), '')                            AS unnamed_0,
        NULLIF(BTRIM(customer_id), '')                          AS customer_id,
        NULLIF(BTRIM(gender), '')                               AS gender,
        NULLIF(BTRIM(customer_type), '')                        AS customer_type,
        NULLIF(BTRIM(age), '')                                  AS age,
        NULLIF(BTRIM(travel_type), '')                          AS travel_type,
        NULLIF(BTRIM(travel_class), '')                         AS travel_class,
        NULLIF(BTRIM(flight_distance), '')                      AS flight_distance,
        NULLIF(BTRIM(inflight_wifi_service), '')                AS inflight_wifi_service,
        NULLIF(BTRIM(departure_arrival_time_convenient), '')    AS departure_arrival_time_convenient,
        NULLIF(BTRIM(ease_of_online_booking), '')               AS ease_of_online_booking,
        NULLIF(BTRIM(gate_location), '')                        AS gate_location,
        NULLIF(BTRIM(food_and_drink), '')                       AS food_and_drink,
        NULLIF(BTRIM(online_boarding), '')                      AS online_boarding,
        NULLIF(BTRIM(seat_comfort), '')                         AS seat_comfort,
        NULLIF(BTRIM(inflight_entertainment), '')               AS inflight_entertainment,
        NULLIF(BTRIM(on_board_service), '')                     AS on_board_service,
        NULLIF(BTRIM(leg_room_service), '')                     AS leg_room_service,
        NULLIF(BTRIM(baggage_handling), '')                     AS baggage_handling,
        NULLIF(BTRIM(checkin_service), '')                      AS checkin_service,
        NULLIF(BTRIM(inflight_service), '')                     AS inflight_service,
        NULLIF(BTRIM(cleanliness), '')                          AS cleanliness,
        NULLIF(BTRIM(departure_delay_minutes), '')              AS departure_delay_minutes,
        NULLIF(BTRIM(arrival_delay_minutes), '')                AS arrival_delay_minutes,
        NULLIF(BTRIM(satisfaction), '')                         AS satisfaction,
        NULLIF(BTRIM(survey_id), '')                            AS survey_id,
        NULLIF(BTRIM(survey_date), '')                          AS survey_date,
        NULLIF(BTRIM(date_key), '')                             AS date_key,
        NULLIF(BTRIM(year), '')                                 AS year,
        NULLIF(BTRIM(quarter), '')                              AS quarter,
        NULLIF(BTRIM(month), '')                                AS month,
        NULLIF(BTRIM(month_name), '')                           AS month_name,
        NULLIF(BTRIM(day), '')                                  AS day,
        NULLIF(BTRIM(week), '')                                 AS week,
        NULLIF(BTRIM(day_of_week), '')                          AS day_of_week
    FROM sa_customer_satisfactions.ext_customer_satisfactions
),
deduplicated AS
(
    SELECT
        raw_data.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY COALESCE
            (
                survey_id,
                'NO_SURVEY_ID_' || MD5
                (
                    CONCAT_WS
                    (
                        '|',
                        unnamed_0,
                        customer_id,
                        gender,
                        customer_type,
                        age,
                        travel_type,
                        travel_class,
                        flight_distance,
                        inflight_wifi_service,
                        departure_arrival_time_convenient,
                        ease_of_online_booking,
                        gate_location,
                        food_and_drink,
                        online_boarding,
                        seat_comfort,
                        inflight_entertainment,
                        on_board_service,
                        leg_room_service,
                        baggage_handling,
                        checkin_service,
                        inflight_service,
                        cleanliness,
                        departure_delay_minutes,
                        arrival_delay_minutes,
                        satisfaction,
                        survey_date,
                        date_key,
                        year,
                        quarter,
                        month,
                        month_name,
                        day,
                        week,
                        day_of_week
                    )
                )
            )
            ORDER BY date_key NULLS LAST,
                     survey_date NULLS LAST,
                     unnamed_0 NULLS LAST,
                     customer_id NULLS LAST
        ) AS rn
    FROM raw_data
)
INSERT INTO sa_customer_satisfactions.src_customer_satisfactions
(
    unnamed_0,
    customer_id,
    gender,
    customer_type,
    age,
    travel_type,
    travel_class,
    flight_distance,
    inflight_wifi_service,
    departure_arrival_time_convenient,
    ease_of_online_booking,
    gate_location,
    food_and_drink,
    online_boarding,
    seat_comfort,
    inflight_entertainment,
    on_board_service,
    leg_room_service,
    baggage_handling,
    checkin_service,
    inflight_service,
    cleanliness,
    departure_delay_minutes,
    arrival_delay_minutes,
    satisfaction,
    survey_id,
    survey_date,
    date_key,
    year,
    quarter,
    month,
    month_name,
    day,
    week,
    day_of_week
)
SELECT
    unnamed_0,
    customer_id,
    gender,
    customer_type,
    age,
    travel_type,
    travel_class,
    flight_distance,
    inflight_wifi_service,
    departure_arrival_time_convenient,
    ease_of_online_booking,
    gate_location,
    food_and_drink,
    online_boarding,
    seat_comfort,
    inflight_entertainment,
    on_board_service,
    leg_room_service,
    baggage_handling,
    checkin_service,
    inflight_service,
    cleanliness,
    departure_delay_minutes,
    arrival_delay_minutes,
    satisfaction,
    survey_id,
    survey_date,
    date_key,
    year,
    quarter,
    month,
    month_name,
    day,
    week,
    day_of_week
FROM deduplicated
WHERE rn = 1;


select *  from sa_customer_satisfactions.src_customer_satisfactions where survey_id like 'S_INC_%'
