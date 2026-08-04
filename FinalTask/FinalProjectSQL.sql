/* ============================================================================
   FINAL PROJECT — STEPS 1–5
   PostgreSQL 15+

   Implements:
     1. Restartable master load procedures
     2. Several SCD1 dimensions loaded with MERGE; SCD2 customer load retained
     3. Incremental fact loading
     4. fct_bookings_dd monthly partition rebuild using DETACH/ATTACH
     5. Data-quality monitoring: stored SQL tests + cursor + dynamic EXECUTE

   Assumptions based on the supplied diagrams:
     - schemas: sa_bookings, sa_customer_satisfactions, bl_3nf, bl_dm, bl_cl
     - default surrogate records use -1
     - PostgreSQL version is 15 or newer (MERGE support)
     - bl_dm.fct_bookings_dd is RANGE partitioned by event_dt
   ============================================================================ */

CREATE SCHEMA IF NOT EXISTS bl_cl;

/* ============================================================================
   0. LOGGING
   ============================================================================ */

CREATE TABLE IF NOT EXISTS bl_cl.etl_load_log
(
    log_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    log_dttm        TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    procedure_name  TEXT NOT NULL,
    rows_affected   BIGINT NOT NULL DEFAULT 0,
    status          VARCHAR(20) NOT NULL,
    message         TEXT,
    executed_by     TEXT NOT NULL DEFAULT session_user
);

CREATE OR REPLACE PROCEDURE bl_cl.pr_write_log
(
    p_procedure_name TEXT,
    p_rows_affected  BIGINT,
    p_status         TEXT,
    p_message        TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO bl_cl.etl_load_log
    (
        procedure_name,
        rows_affected,
        status,
        message
    )
    VALUES
    (
        p_procedure_name,
        COALESCE(p_rows_affected, 0),
        p_status,
        p_message
    );
END;
$$;

/* ============================================================================
   1. SCD1 DIMENSIONS USING MERGE
   Each procedure is restartable:
     - new business key -> INSERT
     - changed attribute -> UPDATE
     - unchanged row -> no action
   ============================================================================ */

CREATE OR REPLACE PROCEDURE bl_cl.pr_load_dim_booking_channels()
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows BIGINT := 0;
BEGIN
    MERGE INTO bl_dm.dim_booking_channels AS tgt
    USING
    (
        SELECT
            booking_channel_src_id,
            COALESCE(booking_channel, 'N/A') AS booking_channel,
            COALESCE(source_system, 'MANUAL') AS source_system,
            COALESCE(source_entity, 'ce_booking_channels') AS source_entity
        FROM bl_3nf.ce_booking_channels
        WHERE booking_channel_id <> -1
    ) AS src
    ON  tgt.booking_channel_src_id = src.booking_channel_src_id
    AND tgt.source_system = src.source_system
    AND tgt.source_entity = src.source_entity
    WHEN MATCHED AND
         tgt.booking_channel IS DISTINCT FROM src.booking_channel
    THEN UPDATE SET
         booking_channel = src.booking_channel,
         ta_update_dt = clock_timestamp()
    WHEN NOT MATCHED THEN
         INSERT
         (
             booking_channel_src_id, booking_channel,
             ta_insert_dt, ta_update_dt, source_system, source_entity
         )
         VALUES
         (
             src.booking_channel_src_id, src.booking_channel,
             clock_timestamp(), clock_timestamp(),
             src.source_system, src.source_entity
         );

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_dim_booking_channels', v_rows, 'SUCCESS',
        'SCD1 MERGE completed.'
    );
EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_dim_booking_channels', 0, 'FAILED',
        format('SQLSTATE=%s; %s', SQLSTATE, SQLERRM)
    );
    RAISE;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.pr_load_dim_payment_methods()
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows BIGINT := 0;
BEGIN
    MERGE INTO bl_dm.dim_payment_methods AS tgt
    USING
    (
        SELECT
            payment_method_src_id,
            COALESCE(payment_method, 'N/A') AS payment_method,
            COALESCE(source_system, 'MANUAL') AS source_system,
            COALESCE(source_entity, 'ce_payment_methods') AS source_entity
        FROM bl_3nf.ce_payment_methods
        WHERE payment_method_id <> -1
    ) AS src
    ON  tgt.payment_method_src_id = src.payment_method_src_id
    AND tgt.source_system = src.source_system
    AND tgt.source_entity = src.source_entity
    WHEN MATCHED AND
         tgt.payment_method IS DISTINCT FROM src.payment_method
    THEN UPDATE SET
         payment_method = src.payment_method,
         ta_update_dt = clock_timestamp()
    WHEN NOT MATCHED THEN
         INSERT
         (
             payment_method_src_id, payment_method,
             ta_insert_dt, ta_update_dt, source_system, source_entity
         )
         VALUES
         (
             src.payment_method_src_id, src.payment_method,
             clock_timestamp(), clock_timestamp(),
             src.source_system, src.source_entity
         );

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_dim_payment_methods', v_rows, 'SUCCESS',
        'SCD1 MERGE completed.'
    );
EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_dim_payment_methods', 0, 'FAILED',
        format('SQLSTATE=%s; %s', SQLSTATE, SQLERRM)
    );
    RAISE;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.pr_load_dim_loyalties()
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows BIGINT := 0;
BEGIN
    MERGE INTO bl_dm.dim_loyalties AS tgt
    USING
    (
        SELECT
            loyalty_src_id,
            COALESCE(loyalty_level, 'N/A') AS loyalty_level,
            COALESCE(source_system, 'MANUAL') AS source_system,
            COALESCE(source_entity, 'ce_loyalties') AS source_entity
        FROM bl_3nf.ce_loyalties
        WHERE loyalty_id <> -1
    ) AS src
    ON  tgt.loyalty_src_id = src.loyalty_src_id
    AND tgt.source_system = src.source_system
    AND tgt.source_entity = src.source_entity
    WHEN MATCHED AND
         tgt.loyalty_level IS DISTINCT FROM src.loyalty_level
    THEN UPDATE SET
         loyalty_level = src.loyalty_level,
         ta_update_dt = clock_timestamp()
    WHEN NOT MATCHED THEN
         INSERT
         (
             loyalty_src_id, loyalty_level,
             ta_insert_dt, ta_update_dt, source_system, source_entity
         )
         VALUES
         (
             src.loyalty_src_id, src.loyalty_level,
             clock_timestamp(), clock_timestamp(),
             src.source_system, src.source_entity
         );

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_dim_loyalties', v_rows, 'SUCCESS',
        'SCD1 MERGE completed.'
    );
EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_dim_loyalties', 0, 'FAILED',
        format('SQLSTATE=%s; %s', SQLSTATE, SQLERRM)
    );
    RAISE;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.pr_load_dim_travel_insurances()
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows BIGINT := 0;
BEGIN
    MERGE INTO bl_dm.dim_travel_insurances AS tgt
    USING
    (
        SELECT
            travel_insurance_src_id,
            COALESCE(travel_insurance, 'N/A') AS travel_insurance,
            COALESCE(source_system, 'MANUAL') AS source_system,
            COALESCE(source_entity, 'ce_travel_insurances') AS source_entity
        FROM bl_3nf.ce_travel_insurances
        WHERE travel_insurance_id <> -1
    ) AS src
    ON  tgt.travel_insurance_src_id = src.travel_insurance_src_id
    AND tgt.source_system = src.source_system
    AND tgt.source_entity = src.source_entity
    WHEN MATCHED AND
         tgt.travel_insurance IS DISTINCT FROM src.travel_insurance
    THEN UPDATE SET
         travel_insurance = src.travel_insurance,
         ta_update_dt = clock_timestamp()
    WHEN NOT MATCHED THEN
         INSERT
         (
             travel_insurance_src_id, travel_insurance,
             ta_insert_dt, ta_update_dt, source_system, source_entity
         )
         VALUES
         (
             src.travel_insurance_src_id, src.travel_insurance,
             clock_timestamp(), clock_timestamp(),
             src.source_system, src.source_entity
         );

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_dim_travel_insurances', v_rows, 'SUCCESS',
        'SCD1 MERGE completed.'
    );
EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_dim_travel_insurances', 0, 'FAILED',
        format('SQLSTATE=%s; %s', SQLSTATE, SQLERRM)
    );
    RAISE;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.pr_load_dim_satisfaction_statuses()
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows BIGINT := 0;
BEGIN
    MERGE INTO bl_dm.dim_satisfaction_statuses AS tgt
    USING
    (
        SELECT
            satisfaction_status_src_id,
            COALESCE(satisfaction_status, 'N/A') AS satisfaction_status,
            COALESCE(source_system, 'MANUAL') AS source_system,
            COALESCE(source_entity, 'ce_satisfaction_statuses') AS source_entity
        FROM bl_3nf.ce_satisfaction_statuses
        WHERE satisfaction_status_id <> -1
    ) AS src
    ON  tgt.satisfaction_status_src_id = src.satisfaction_status_src_id
    AND tgt.source_system = src.source_system
    AND tgt.source_entity = src.source_entity
    WHEN MATCHED AND
         tgt.satisfaction_status IS DISTINCT FROM src.satisfaction_status
    THEN UPDATE SET
         satisfaction_status = src.satisfaction_status,
         ta_update_dt = clock_timestamp()
    WHEN NOT MATCHED THEN
         INSERT
         (
             satisfaction_status_src_id, satisfaction_status,
             ta_insert_dt, ta_update_dt, source_system, source_entity
         )
         VALUES
         (
             src.satisfaction_status_src_id, src.satisfaction_status,
             clock_timestamp(), clock_timestamp(),
             src.source_system, src.source_entity
         );

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_dim_satisfaction_statuses', v_rows, 'SUCCESS',
        'SCD1 MERGE completed.'
    );
EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_dim_satisfaction_statuses', 0, 'FAILED',
        format('SQLSTATE=%s; %s', SQLSTATE, SQLERRM)
    );
    RAISE;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.pr_load_dim_travels()
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows BIGINT := 0;
BEGIN
    MERGE INTO bl_dm.dim_travels AS tgt
    USING
    (
        SELECT
            travel_src_id,
            COALESCE(travel_type, 'N/A') AS travel_type,
            COALESCE(travel_class, 'N/A') AS travel_class,
            COALESCE(flight_distance, 0) AS flight_distance,
            COALESCE(source_system, 'MANUAL') AS source_system,
            COALESCE(source_entity, 'ce_travels') AS source_entity
        FROM bl_3nf.ce_travels
        WHERE travel_id <> -1
    ) AS src
    ON  tgt.travel_src_id = src.travel_src_id
    AND tgt.source_system = src.source_system
    AND tgt.source_entity = src.source_entity
    WHEN MATCHED AND
    (
        tgt.travel_type IS DISTINCT FROM src.travel_type OR
        tgt.travel_class IS DISTINCT FROM src.travel_class OR
        tgt.flight_distance IS DISTINCT FROM src.flight_distance
    )
    THEN UPDATE SET
         travel_type = src.travel_type,
         travel_class = src.travel_class,
         flight_distance = src.flight_distance,
         ta_update_dt = clock_timestamp()
    WHEN NOT MATCHED THEN
         INSERT
         (
             travel_src_id, travel_type, travel_class, flight_distance,
             ta_insert_dt, ta_update_dt, source_system, source_entity
         )
         VALUES
         (
             src.travel_src_id, src.travel_type, src.travel_class,
             src.flight_distance, clock_timestamp(), clock_timestamp(),
             src.source_system, src.source_entity
         );

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_dim_travels', v_rows, 'SUCCESS',
        'SCD1 MERGE completed.'
    );
EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_dim_travels', 0, 'FAILED',
        format('SQLSTATE=%s; %s', SQLSTATE, SQLERRM)
    );
    RAISE;
END;
$$;

/* ============================================================================
   2. BL_DM SCD2 CUSTOMER LOAD
   This procedure preserves history and is restartable.
   A changed active customer version is closed, then a new version is inserted.
   ============================================================================ */

CREATE OR REPLACE PROCEDURE bl_cl.pr_load_dim_customers_scd()
LANGUAGE plpgsql
AS $$
DECLARE
    v_closed   BIGINT := 0;
    v_inserted BIGINT := 0;
BEGIN
    WITH src AS
    (
        SELECT DISTINCT ON
        (
            customer_src_id, source_system, source_entity
        )
            customer_src_id,
            COALESCE(gender, 'N/A') AS gender,
            COALESCE(age, -1) AS age,
            COALESCE(customer_type, 'N/A') AS customer_type,
            COALESCE(start_dt, CURRENT_DATE) AS effective_dt,
            COALESCE(source_system, 'MANUAL') AS source_system,
            COALESCE(source_entity, 'ce_customers_scd') AS source_entity
        FROM bl_3nf.ce_customers_scd
        WHERE is_active = 'Y'
          AND customer_id <> -1
        ORDER BY
            customer_src_id, source_system, source_entity,
            start_dt DESC, customer_id DESC
    )
    UPDATE bl_dm.dim_customers_scd tgt
       SET end_dt = src.effective_dt - 1,
           is_active = 'N',
           ta_update_dt = clock_timestamp()
      FROM src
     WHERE tgt.customer_src_id = src.customer_src_id
       AND tgt.source_system = src.source_system
       AND tgt.source_entity = src.source_entity
       AND tgt.is_active = 'Y'
       AND ROW(tgt.gender, tgt.age, tgt.customer_type)
           IS DISTINCT FROM
           ROW(src.gender, src.age, src.customer_type);

    GET DIAGNOSTICS v_closed = ROW_COUNT;

    WITH src AS
    (
        SELECT DISTINCT ON
        (
            customer_src_id, source_system, source_entity
        )
            customer_src_id,
            COALESCE(gender, 'N/A') AS gender,
            COALESCE(age, -1) AS age,
            COALESCE(customer_type, 'N/A') AS customer_type,
            COALESCE(start_dt, CURRENT_DATE) AS effective_dt,
            COALESCE(source_system, 'MANUAL') AS source_system,
            COALESCE(source_entity, 'ce_customers_scd') AS source_entity
        FROM bl_3nf.ce_customers_scd
        WHERE is_active = 'Y'
          AND customer_id <> -1
        ORDER BY
            customer_src_id, source_system, source_entity,
            start_dt DESC, customer_id DESC
    )
    INSERT INTO bl_dm.dim_customers_scd
    (
        customer_src_id, gender, age, customer_type,
        start_dt, end_dt, is_active,
        ta_insert_dt, ta_update_dt,
        source_system, source_entity
    )
    SELECT
        src.customer_src_id,
        src.gender,
        src.age,
        src.customer_type,
        src.effective_dt,
        DATE '9999-12-31',
        'Y',
        clock_timestamp(),
        clock_timestamp(),
        src.source_system,
        src.source_entity
    FROM src
    LEFT JOIN bl_dm.dim_customers_scd tgt
      ON tgt.customer_src_id = src.customer_src_id
     AND tgt.source_system = src.source_system
     AND tgt.source_entity = src.source_entity
     AND tgt.is_active = 'Y'
    WHERE tgt.customer_surr_id IS NULL;

    GET DIAGNOSTICS v_inserted = ROW_COUNT;

    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_dim_customers_scd',
        v_closed + v_inserted,
        'SUCCESS',
        format('SCD2 completed: %s rows closed, %s rows inserted.',
               v_closed, v_inserted)
    );
EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_dim_customers_scd', 0, 'FAILED',
        format('SQLSTATE=%s; %s', SQLSTATE, SQLERRM)
    );
    RAISE;
END;
$$;

/* ============================================================================
   3. INCREMENTAL FACT LOAD WITH PARTITION DETACH / ATTACH

   Rebuilds only one requested month:
     1. Create standalone stage table.
     2. Copy current month rows and add newly available BL_3NF rows.
     3. Deduplicate by booking_src_id.
     4. DETACH and drop old partition when present.
     5. Rename and ATTACH the rebuilt partition.

   Running it repeatedly with unchanged source data produces no duplicates.
   ============================================================================ */
CREATE OR REPLACE PROCEDURE bl_cl.pr_refresh_fct_bookings_partition
(
    p_month DATE
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_month_start    DATE;
    v_month_end      DATE;
    v_partition_name TEXT;
    v_stage_name     TEXT;
    v_partition_oid  REGCLASS;

    v_rows_before    BIGINT := 0;
    v_rows_after     BIGINT := 0;
    v_rows_affected  BIGINT := 0;
BEGIN
    IF p_month IS NULL THEN
        RAISE EXCEPTION
            'p_month cannot be NULL in pr_refresh_fct_bookings_partition';
    END IF;

    v_month_start :=
        DATE_TRUNC('month', p_month)::DATE;

    v_month_end :=
        (
            DATE_TRUNC('month', p_month)
            + INTERVAL '1 month'
        )::DATE;

    v_partition_name :=
        FORMAT(
            'fct_bookings_dd_%s',
            TO_CHAR(v_month_start, 'YYYYMM')
        );

    v_stage_name :=
        FORMAT(
            'fct_bookings_dd_stage_%s',
            TO_CHAR(v_month_start, 'YYYYMM')
        );

    /*
     * Check whether the final monthly partition already exists.
     */
    SELECT TO_REGCLASS(
        FORMAT('bl_dm.%I', v_partition_name)
    )
    INTO v_partition_oid;

    /*
     * Count the current rows in the existing partition.
     * If the partition does not exist, the count remains zero.
     */
    IF v_partition_oid IS NOT NULL THEN
        EXECUTE FORMAT(
            'SELECT COUNT(*)
               FROM bl_dm.%I',
            v_partition_name
        )
        INTO v_rows_before;
    END IF;

    /*
     * Remove a stage table left after an earlier failed execution.
     */
    EXECUTE FORMAT(
        'DROP TABLE IF EXISTS bl_dm.%I',
        v_stage_name
    );

    /*
     * Create a standalone table with the fact-table structure.
     */
    EXECUTE FORMAT(
        'CREATE TABLE bl_dm.%I
         (
             LIKE bl_dm.fct_bookings_dd
             INCLUDING DEFAULTS
             INCLUDING CONSTRAINTS
         )',
        v_stage_name
    );

    /*
     * Add a monthly-range constraint.
     */
    EXECUTE FORMAT(
        'ALTER TABLE bl_dm.%I
         ADD CONSTRAINT %I
         CHECK
         (
             event_dt >= %L
             AND event_dt < %L
         )',
        v_stage_name,
        v_stage_name || '_event_dt_chk',
        v_month_start,
        v_month_end
    );

    /*
     * Merge:
     * 1. Existing fact rows for the month.
     * 2. Current BL_3NF rows for the month.
     *
     * BL_3NF has higher priority, so changed fact values
     * are recalculated during partition refresh.
     */
    EXECUTE FORMAT(
        $sql$
        INSERT INTO bl_dm.%I
        (
            event_dt,
            booking_src_id,
            customer_surr_id,
            travel_surr_id,
            booking_channel_surr_id,
            payment_method_surr_id,
            loyalty_surr_id,
            travel_insurance_surr_id,
            fct_ticket_price,
            fct_operating_cost,
            fct_airport_fee,
            fct_promotion_discount,
            fct_profit,
            ta_insert_dt,
            ta_update_dt
        )
        SELECT DISTINCT ON (q.booking_src_id)
            q.event_dt,
            q.booking_src_id,
            q.customer_surr_id,
            q.travel_surr_id,
            q.booking_channel_surr_id,
            q.payment_method_surr_id,
            q.loyalty_surr_id,
            q.travel_insurance_surr_id,
            q.fct_ticket_price,
            q.fct_operating_cost,
            q.fct_airport_fee,
            q.fct_promotion_discount,
            q.fct_profit,
            q.ta_insert_dt,
            q.ta_update_dt
        FROM
        (
            /*
             * Existing rows from the current partition.
             */
            SELECT
                f.event_dt,
                f.booking_src_id,
                f.customer_surr_id,
                f.travel_surr_id,
                f.booking_channel_surr_id,
                f.payment_method_surr_id,
                f.loyalty_surr_id,
                f.travel_insurance_surr_id,
                f.fct_ticket_price,
                f.fct_operating_cost,
                f.fct_airport_fee,
                f.fct_promotion_discount,
                f.fct_profit,
                f.ta_insert_dt,
                f.ta_update_dt,
                1 AS source_priority
            FROM bl_dm.fct_bookings_dd AS f
            WHERE f.event_dt >= %L
              AND f.event_dt < %L

            UNION ALL

            /*
             * New or changed rows from BL_3NF.
             */
            SELECT
                b.booking_dt AS event_dt,
                b.booking_id::TEXT AS booking_src_id,

                COALESCE(dc.customer_surr_id, -1)
                    AS customer_surr_id,

                COALESCE(dt.travel_surr_id, -1)
                    AS travel_surr_id,

                COALESCE(dbc.booking_channel_surr_id, -1)
                    AS booking_channel_surr_id,

                COALESCE(dpm.payment_method_surr_id, -1)
                    AS payment_method_surr_id,

                COALESCE(dl.loyalty_surr_id, -1)
                    AS loyalty_surr_id,

                COALESCE(dti.travel_insurance_surr_id, -1)
                    AS travel_insurance_surr_id,

                COALESCE(b.ticket_price, 0)
                    AS fct_ticket_price,

                COALESCE(b.operating_cost, 0)
                    AS fct_operating_cost,

                COALESCE(b.airport_fee, 0)
                    AS fct_airport_fee,

                COALESCE(b.promotion_discount, 0)
                    AS fct_promotion_discount,

                COALESCE(b.profit, 0)
                    AS fct_profit,

                COALESCE(
                    b.insert_dt,
                    CLOCK_TIMESTAMP()
                ) AS ta_insert_dt,

                CLOCK_TIMESTAMP() AS ta_update_dt,

                2 AS source_priority

            FROM bl_3nf.ce_bookings AS b

            LEFT JOIN bl_3nf.ce_customers_scd AS c3
                ON c3.customer_id = b.customer_id

            LEFT JOIN bl_dm.dim_customers_scd AS dc
                ON dc.customer_src_id = c3.customer_src_id
               AND dc.source_system = c3.source_system
               AND dc.source_entity = c3.source_entity
               AND b.booking_dt
                   BETWEEN dc.start_dt AND dc.end_dt

            LEFT JOIN bl_3nf.ce_travels AS t3
                ON t3.travel_id = b.travel_id

            LEFT JOIN bl_dm.dim_travels AS dt
                ON dt.travel_src_id = t3.travel_src_id
               AND dt.source_system = t3.source_system
               AND dt.source_entity = t3.source_entity

            LEFT JOIN bl_3nf.ce_booking_channels AS bc3
                ON bc3.booking_channel_id =
                   b.booking_channel_id

            LEFT JOIN bl_dm.dim_booking_channels AS dbc
                ON dbc.booking_channel_src_id =
                   bc3.booking_channel_src_id
               AND dbc.source_system = bc3.source_system
               AND dbc.source_entity = bc3.source_entity

            LEFT JOIN bl_3nf.ce_payment_methods AS pm3
                ON pm3.payment_method_id =
                   b.payment_method_id

            LEFT JOIN bl_dm.dim_payment_methods AS dpm
                ON dpm.payment_method_src_id =
                   pm3.payment_method_src_id
               AND dpm.source_system = pm3.source_system
               AND dpm.source_entity = pm3.source_entity

            LEFT JOIN bl_3nf.ce_loyalties AS l3
                ON l3.loyalty_id = b.loyalty_id

            LEFT JOIN bl_dm.dim_loyalties AS dl
                ON dl.loyalty_src_id = l3.loyalty_src_id
               AND dl.source_system = l3.source_system
               AND dl.source_entity = l3.source_entity

            LEFT JOIN bl_3nf.ce_travel_insurances AS ti3
                ON ti3.travel_insurance_id =
                   b.travel_insurance_id

            LEFT JOIN bl_dm.dim_travel_insurances AS dti
                ON dti.travel_insurance_src_id =
                   ti3.travel_insurance_src_id
               AND dti.source_system = ti3.source_system
               AND dti.source_entity = ti3.source_entity

            WHERE b.booking_dt >= %L
              AND b.booking_dt < %L
        ) AS q
        ORDER BY
            q.booking_src_id,
            q.source_priority DESC,
            q.ta_update_dt DESC
        $sql$,
        v_stage_name,
        v_month_start,
        v_month_end,
        v_month_start,
        v_month_end
    );

    EXECUTE FORMAT(
        'SELECT COUNT(*)
           FROM bl_dm.%I',
        v_stage_name
    )
    INTO v_rows_after;

    /*
     * Remove the existing partition only after the replacement
     * stage table has been successfully populated.
     */
    IF v_partition_oid IS NOT NULL THEN
        EXECUTE FORMAT(
            'ALTER TABLE bl_dm.fct_bookings_dd
             DETACH PARTITION bl_dm.%I',
            v_partition_name
        );

        EXECUTE FORMAT(
            'DROP TABLE bl_dm.%I',
            v_partition_name
        );
    END IF;

    /*
     * Rename the stage table to the final partition name.
     */
    EXECUTE FORMAT(
        'ALTER TABLE bl_dm.%I
         RENAME TO %I',
        v_stage_name,
        v_partition_name
    );

    /*
     * Attach the recalculated table as a partition.
     * This creates the partition when it was previously absent.
     */
    EXECUTE FORMAT(
        'ALTER TABLE bl_dm.fct_bookings_dd
         ATTACH PARTITION bl_dm.%I
         FOR VALUES FROM (%L) TO (%L)',
        v_partition_name,
        v_month_start,
        v_month_end
    );

    v_rows_affected :=
        GREATEST(v_rows_after - v_rows_before, 0);

    CALL bl_cl.pr_write_log
    (
        'bl_cl.pr_refresh_fct_bookings_partition',
        v_rows_affected,
        'SUCCESS',
        FORMAT(
            'Partition %s refreshed: before=%s, after=%s.',
            v_partition_name,
            v_rows_before,
            v_rows_after
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        /*
         * Remove the stage table after a failed refresh.
         */
        EXECUTE FORMAT(
            'DROP TABLE IF EXISTS bl_dm.%I',
            v_stage_name
        );

        CALL bl_cl.pr_write_log
        (
            'bl_cl.pr_refresh_fct_bookings_partition',
            0,
            'FAILED',
            FORMAT(
                'Month=%s; SQLSTATE=%s; %s',
                p_month,
                SQLSTATE,
                SQLERRM
            )
        );

        RAISE;
END;
$procedure$;


/* ================================================================
   2. RECALCULATE BOOKING PARTITIONS FOR THE REQUESTED RANGE
   ================================================================ */

CREATE OR REPLACE PROCEDURE bl_cl.pr_load_fct_bookings_dd
(
    p_from_date DATE DEFAULT NULL,
    p_to_date   DATE DEFAULT NULL
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_month_start DATE;
    v_last_month  DATE;
    v_before      BIGINT := 0;
    v_after       BIGINT := 0;
    v_total       BIGINT := 0;
BEGIN
    IF p_from_date IS NOT NULL
       AND p_to_date IS NOT NULL
       AND p_from_date > p_to_date
    THEN
        RAISE EXCEPTION
            'p_from_date (%) cannot be greater than p_to_date (%)',
            p_from_date,
            p_to_date;
    END IF;

    /*
     * When dates are provided, process every month in the range.
     * This guarantees that a missing monthly partition is created.
     */
    IF p_from_date IS NOT NULL
       AND p_to_date IS NOT NULL
    THEN
        v_month_start :=
            DATE_TRUNC('month', p_from_date)::DATE;

        v_last_month :=
            DATE_TRUNC('month', p_to_date)::DATE;

        WHILE v_month_start <= v_last_month
        LOOP
            SELECT COUNT(*)
              INTO v_before
              FROM bl_dm.fct_bookings_dd
             WHERE event_dt >= v_month_start
               AND event_dt <
                   (v_month_start + INTERVAL '1 month')::DATE;

            CALL bl_cl.pr_refresh_fct_bookings_partition(
                v_month_start
            );

            SELECT COUNT(*)
              INTO v_after
              FROM bl_dm.fct_bookings_dd
             WHERE event_dt >= v_month_start
               AND event_dt <
                   (v_month_start + INTERVAL '1 month')::DATE;

            v_total :=
                v_total
                + GREATEST(v_after - v_before, 0);

            v_month_start :=
                (
                    v_month_start
                    + INTERVAL '1 month'
                )::DATE;
        END LOOP;

    ELSE
        /*
         * When no full date range is supplied, process months
         * that are present in BL_3NF.
         */
        FOR v_month_start IN
            SELECT DISTINCT
                DATE_TRUNC('month', booking_dt)::DATE
            FROM bl_3nf.ce_bookings
            WHERE booking_dt >=
                  COALESCE(
                      p_from_date,
                      DATE '1900-01-01'
                  )
              AND booking_dt <
                  COALESCE(
                      p_to_date + 1,
                      'infinity'::DATE
                  )
            ORDER BY 1
        LOOP
            SELECT COUNT(*)
              INTO v_before
              FROM bl_dm.fct_bookings_dd
             WHERE event_dt >= v_month_start
               AND event_dt <
                   (v_month_start + INTERVAL '1 month')::DATE;

            CALL bl_cl.pr_refresh_fct_bookings_partition(
                v_month_start
            );

            SELECT COUNT(*)
              INTO v_after
              FROM bl_dm.fct_bookings_dd
             WHERE event_dt >= v_month_start
               AND event_dt <
                   (v_month_start + INTERVAL '1 month')::DATE;

            v_total :=
                v_total
                + GREATEST(v_after - v_before, 0);
        END LOOP;
    END IF;

    CALL bl_cl.pr_write_log
    (
        'bl_cl.pr_load_fct_bookings_dd',
        v_total,
        'SUCCESS',
        FORMAT(
            'Booking fact partitions recalculated for range %s–%s.',
            COALESCE(p_from_date::TEXT, 'all'),
            COALESCE(p_to_date::TEXT, 'all')
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        CALL bl_cl.pr_write_log
        (
            'bl_cl.pr_load_fct_bookings_dd',
            0,
            'FAILED',
            FORMAT(
                'SQLSTATE=%s; %s',
                SQLSTATE,
                SQLERRM
            )
        );

        RAISE;
END;
$procedure$;


/* ================================================================
   3. REFRESH OR CREATE ONE CUSTOMER-SATISFACTION PARTITION
   ================================================================ */

CREATE OR REPLACE PROCEDURE
    bl_cl.pr_refresh_fct_customer_satisfactions_partition
(
    p_month DATE
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_month_start    DATE;
    v_month_end      DATE;
    v_partition_name TEXT;
    v_stage_name     TEXT;
    v_partition_oid  REGCLASS;

    v_rows_before    BIGINT := 0;
    v_rows_after     BIGINT := 0;
    v_rows_affected  BIGINT := 0;
BEGIN
    IF p_month IS NULL THEN
        RAISE EXCEPTION
            'p_month cannot be NULL in pr_refresh_fct_customer_satisfactions_partition';
    END IF;

    v_month_start :=
        DATE_TRUNC('month', p_month)::DATE;

    v_month_end :=
        (
            DATE_TRUNC('month', p_month)
            + INTERVAL '1 month'
        )::DATE;

    v_partition_name :=
        FORMAT(
            'fct_customer_satisfactions_dd_%s',
            TO_CHAR(v_month_start, 'YYYYMM')
        );

    v_stage_name :=
        FORMAT(
            'fct_customer_satisfactions_dd_stage_%s',
            TO_CHAR(v_month_start, 'YYYYMM')
        );

    /*
     * Check whether the monthly partition already exists.
     */
    SELECT TO_REGCLASS(
        FORMAT('bl_dm.%I', v_partition_name)
    )
    INTO v_partition_oid;

    IF v_partition_oid IS NOT NULL THEN
        EXECUTE FORMAT(
            'SELECT COUNT(*)
               FROM bl_dm.%I',
            v_partition_name
        )
        INTO v_rows_before;
    END IF;

    /*
     * Remove a stage table left from an earlier failed execution.
     */
    EXECUTE FORMAT(
        'DROP TABLE IF EXISTS bl_dm.%I',
        v_stage_name
    );

    /*
     * Create a standalone table with the same structure
     * as the parent fact table.
     */
    EXECUTE FORMAT(
        'CREATE TABLE bl_dm.%I
         (
             LIKE bl_dm.fct_customer_satisfactions_dd
             INCLUDING DEFAULTS
             INCLUDING CONSTRAINTS
         )',
        v_stage_name
    );

    /*
     * Add the monthly partition-range constraint.
     */
    EXECUTE FORMAT(
        'ALTER TABLE bl_dm.%I
         ADD CONSTRAINT %I
         CHECK
         (
             event_dt >= %L
             AND event_dt < %L
         )',
        v_stage_name,
        v_stage_name || '_event_dt_chk',
        v_month_start,
        v_month_end
    );

    /*
     * Merge existing fact rows with current BL_3NF rows.
     * BL_3NF rows have higher priority and therefore replace
     * previous values during partition recalculation.
     */
    EXECUTE FORMAT(
        $sql$
        INSERT INTO bl_dm.%I
        (
            event_dt,
            customer_satisfaction_src_id,
            customer_surr_id,
            travel_surr_id,
            satisfaction_status_surr_id,
            fct_inflight_wifi_service,
            fct_departure_arrival_time_convenient,
            fct_ease_of_online_booking,
            fct_gate_location,
            fct_food_and_drink,
            fct_online_boarding,
            fct_seat_comfort,
            fct_inflight_entertainment,
            fct_on_board_service,
            fct_leg_room_service,
            fct_baggage_handling,
            fct_checkin_service,
            fct_inflight_service,
            fct_cleanliness,
            fct_departure_delay_in_minutes,
            fct_arrival_delay_in_minutes,
            ta_insert_dt,
            ta_update_dt
        )
        SELECT DISTINCT ON
        (
            q.customer_satisfaction_src_id
        )
            q.event_dt,
            q.customer_satisfaction_src_id,
            q.customer_surr_id,
            q.travel_surr_id,
            q.satisfaction_status_surr_id,
            q.fct_inflight_wifi_service,
            q.fct_departure_arrival_time_convenient,
            q.fct_ease_of_online_booking,
            q.fct_gate_location,
            q.fct_food_and_drink,
            q.fct_online_boarding,
            q.fct_seat_comfort,
            q.fct_inflight_entertainment,
            q.fct_on_board_service,
            q.fct_leg_room_service,
            q.fct_baggage_handling,
            q.fct_checkin_service,
            q.fct_inflight_service,
            q.fct_cleanliness,
            q.fct_departure_delay_in_minutes,
            q.fct_arrival_delay_in_minutes,
            q.ta_insert_dt,
            q.ta_update_dt
        FROM
        (
            /*
             * Existing fact rows for the month.
             */
            SELECT
                f.event_dt,
                f.customer_satisfaction_src_id,
                f.customer_surr_id,
                f.travel_surr_id,
                f.satisfaction_status_surr_id,
                f.fct_inflight_wifi_service,
                f.fct_departure_arrival_time_convenient,
                f.fct_ease_of_online_booking,
                f.fct_gate_location,
                f.fct_food_and_drink,
                f.fct_online_boarding,
                f.fct_seat_comfort,
                f.fct_inflight_entertainment,
                f.fct_on_board_service,
                f.fct_leg_room_service,
                f.fct_baggage_handling,
                f.fct_checkin_service,
                f.fct_inflight_service,
                f.fct_cleanliness,
                f.fct_departure_delay_in_minutes,
                f.fct_arrival_delay_in_minutes,
                f.ta_insert_dt,
                f.ta_update_dt,
                1 AS source_priority
            FROM bl_dm.fct_customer_satisfactions_dd AS f
            WHERE f.event_dt >= %L
              AND f.event_dt < %L

            UNION ALL

            /*
             * New or recalculated rows from BL_3NF.
             */
            SELECT
                cs.survey_dt AS event_dt,

                cs.customer_satisfaction_src_id,

                COALESCE(dc.customer_surr_id, -1)
                    AS customer_surr_id,

                COALESCE(dt.travel_surr_id, -1)
                    AS travel_surr_id,

                COALESCE(
                    dss.satisfaction_status_surr_id,
                    -1
                ) AS satisfaction_status_surr_id,

                COALESCE(
                    cs.inflight_wifi_service,
                    0
                ) AS fct_inflight_wifi_service,

                COALESCE(
                    cs.departure_arrival_time_convenient,
                    0
                ) AS fct_departure_arrival_time_convenient,

                COALESCE(
                    cs.ease_of_online_booking,
                    0
                ) AS fct_ease_of_online_booking,

                COALESCE(
                    cs.gate_location,
                    0
                ) AS fct_gate_location,

                COALESCE(
                    cs.food_and_drink,
                    0
                ) AS fct_food_and_drink,

                COALESCE(
                    cs.online_boarding,
                    0
                ) AS fct_online_boarding,

                COALESCE(
                    cs.seat_comfort,
                    0
                ) AS fct_seat_comfort,

                COALESCE(
                    cs.inflight_entertainment,
                    0
                ) AS fct_inflight_entertainment,

                COALESCE(
                    cs.on_board_service,
                    0
                ) AS fct_on_board_service,

                COALESCE(
                    cs.leg_room_service,
                    0
                ) AS fct_leg_room_service,

                COALESCE(
                    cs.baggage_handling,
                    0
                ) AS fct_baggage_handling,

                COALESCE(
                    cs.checkin_service,
                    0
                ) AS fct_checkin_service,

                COALESCE(
                    cs.inflight_service,
                    0
                ) AS fct_inflight_service,

                COALESCE(
                    cs.cleanliness,
                    0
                ) AS fct_cleanliness,

                COALESCE(
                    cs.departure_delay_in_minutes,
                    0
                ) AS fct_departure_delay_in_minutes,

                COALESCE(
                    cs.arrival_delay_in_minutes,
                    0
                ) AS fct_arrival_delay_in_minutes,

                COALESCE(
                    cs.insert_dt,
                    CLOCK_TIMESTAMP()
                ) AS ta_insert_dt,

                CLOCK_TIMESTAMP() AS ta_update_dt,

                2 AS source_priority

            FROM bl_3nf.ce_customer_satisfactions AS cs

            LEFT JOIN bl_3nf.ce_customers_scd AS c3
                ON c3.customer_id = cs.customer_id

            LEFT JOIN bl_dm.dim_customers_scd AS dc
                ON dc.customer_src_id = c3.customer_src_id
               AND dc.source_system = c3.source_system
               AND dc.source_entity = c3.source_entity
               AND cs.survey_dt
                   BETWEEN dc.start_dt AND dc.end_dt

            LEFT JOIN bl_3nf.ce_travels AS t3
                ON t3.travel_id = cs.travel_id

            LEFT JOIN bl_dm.dim_travels AS dt
                ON dt.travel_src_id = t3.travel_src_id
               AND dt.source_system = t3.source_system
               AND dt.source_entity = t3.source_entity

            LEFT JOIN bl_3nf.ce_satisfaction_statuses AS ss3
                ON ss3.satisfaction_status_id =
                   cs.satisfaction_status_id

            LEFT JOIN bl_dm.dim_satisfaction_statuses AS dss
                ON dss.satisfaction_status_src_id =
                   ss3.satisfaction_status_src_id
               AND dss.source_system = ss3.source_system
               AND dss.source_entity = ss3.source_entity

            WHERE cs.survey_dt >= %L
              AND cs.survey_dt < %L
        ) AS q

        ORDER BY
            q.customer_satisfaction_src_id,
            q.source_priority DESC,
            q.ta_update_dt DESC
        $sql$,
        v_stage_name,
        v_month_start,
        v_month_end,
        v_month_start,
        v_month_end
    );

    EXECUTE FORMAT(
        'SELECT COUNT(*)
           FROM bl_dm.%I',
        v_stage_name
    )
    INTO v_rows_after;

    /*
     * Replace the previous partition when it exists.
     */
    IF v_partition_oid IS NOT NULL THEN
        EXECUTE FORMAT(
            'ALTER TABLE bl_dm.fct_customer_satisfactions_dd
             DETACH PARTITION bl_dm.%I',
            v_partition_name
        );

        EXECUTE FORMAT(
            'DROP TABLE bl_dm.%I',
            v_partition_name
        );
    END IF;

    /*
     * Rename the stage table to its final partition name.
     */
    EXECUTE FORMAT(
        'ALTER TABLE bl_dm.%I
         RENAME TO %I',
        v_stage_name,
        v_partition_name
    );

    /*
     * Attach it as a new or recalculated monthly partition.
     */
    EXECUTE FORMAT(
        'ALTER TABLE bl_dm.fct_customer_satisfactions_dd
         ATTACH PARTITION bl_dm.%I
         FOR VALUES FROM (%L) TO (%L)',
        v_partition_name,
        v_month_start,
        v_month_end
    );

    v_rows_affected :=
        GREATEST(v_rows_after - v_rows_before, 0);

    CALL bl_cl.pr_write_log
    (
        'bl_cl.pr_refresh_fct_customer_satisfactions_partition',
        v_rows_affected,
        'SUCCESS',
        FORMAT(
            'Partition %s refreshed: before=%s, after=%s.',
            v_partition_name,
            v_rows_before,
            v_rows_after
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        EXECUTE FORMAT(
            'DROP TABLE IF EXISTS bl_dm.%I',
            v_stage_name
        );

        CALL bl_cl.pr_write_log
        (
            'bl_cl.pr_refresh_fct_customer_satisfactions_partition',
            0,
            'FAILED',
            FORMAT(
                'Month=%s; SQLSTATE=%s; %s',
                p_month,
                SQLSTATE,
                SQLERRM
            )
        );

        RAISE;
END;
$procedure$;


/* ================================================================
   4. RECALCULATE CUSTOMER-SATISFACTION PARTITIONS FOR RANGE
   ================================================================ */

CREATE OR REPLACE PROCEDURE
    bl_cl.pr_load_fct_customer_satisfactions_dd
(
    p_from_date DATE DEFAULT NULL,
    p_to_date   DATE DEFAULT NULL
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_month_start DATE;
    v_last_month  DATE;
    v_before      BIGINT := 0;
    v_after       BIGINT := 0;
    v_total       BIGINT := 0;
BEGIN
    IF p_from_date IS NOT NULL
       AND p_to_date IS NOT NULL
       AND p_from_date > p_to_date
    THEN
        RAISE EXCEPTION
            'p_from_date (%) cannot be greater than p_to_date (%)',
            p_from_date,
            p_to_date;
    END IF;

    /*
     * Process every calendar month in the supplied date range.
     * For October 2026 this creates or replaces partition 202610.
     */
    IF p_from_date IS NOT NULL
       AND p_to_date IS NOT NULL
    THEN
        v_month_start :=
            DATE_TRUNC('month', p_from_date)::DATE;

        v_last_month :=
            DATE_TRUNC('month', p_to_date)::DATE;

        WHILE v_month_start <= v_last_month
        LOOP
            SELECT COUNT(*)
              INTO v_before
              FROM bl_dm.fct_customer_satisfactions_dd
             WHERE event_dt >= v_month_start
               AND event_dt <
                   (v_month_start + INTERVAL '1 month')::DATE;

            CALL
                bl_cl.pr_refresh_fct_customer_satisfactions_partition
                (
                    v_month_start
                );

            SELECT COUNT(*)
              INTO v_after
              FROM bl_dm.fct_customer_satisfactions_dd
             WHERE event_dt >= v_month_start
               AND event_dt <
                   (v_month_start + INTERVAL '1 month')::DATE;

            v_total :=
                v_total
                + GREATEST(v_after - v_before, 0);

            v_month_start :=
                (
                    v_month_start
                    + INTERVAL '1 month'
                )::DATE;
        END LOOP;

    ELSE
        /*
         * When a complete range is not supplied, process months
         * that are present in the BL_3NF source.
         */
        FOR v_month_start IN
            SELECT DISTINCT
                DATE_TRUNC('month', survey_dt)::DATE
            FROM bl_3nf.ce_customer_satisfactions
            WHERE survey_dt >=
                  COALESCE(
                      p_from_date,
                      DATE '1900-01-01'
                  )
              AND survey_dt <
                  COALESCE(
                      p_to_date + 1,
                      'infinity'::DATE
                  )
            ORDER BY 1
        LOOP
            SELECT COUNT(*)
              INTO v_before
              FROM bl_dm.fct_customer_satisfactions_dd
             WHERE event_dt >= v_month_start
               AND event_dt <
                   (v_month_start + INTERVAL '1 month')::DATE;

            CALL
                bl_cl.pr_refresh_fct_customer_satisfactions_partition
                (
                    v_month_start
                );

            SELECT COUNT(*)
              INTO v_after
              FROM bl_dm.fct_customer_satisfactions_dd
             WHERE event_dt >= v_month_start
               AND event_dt <
                   (v_month_start + INTERVAL '1 month')::DATE;

            v_total :=
                v_total
                + GREATEST(v_after - v_before, 0);
        END LOOP;
    END IF;

    CALL bl_cl.pr_write_log
    (
        'bl_cl.pr_load_fct_customer_satisfactions_dd',
        v_total,
        'SUCCESS',
        FORMAT(
            'Customer-satisfaction partitions recalculated for range %s–%s.',
            COALESCE(p_from_date::TEXT, 'all'),
            COALESCE(p_to_date::TEXT, 'all')
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        CALL bl_cl.pr_write_log
        (
            'bl_cl.pr_load_fct_customer_satisfactions_dd',
            0,
            'FAILED',
            FORMAT(
                'SQLSTATE=%s; %s',
                SQLSTATE,
                SQLERRM
            )
        );

        RAISE;
END;
$procedure$;

/* ============================================================================
   4. RESTARTABLE MASTER PROCEDURES
   The BL_3NF procedures listed below are the procedures already used by the
   project. Their own NOT EXISTS / MERGE / SCD2 logic must remain restartable.
   ============================================================================ */

CREATE OR REPLACE PROCEDURE bl_cl.pr_load_bl_3nf_increment()
LANGUAGE plpgsql
AS $$
BEGIN
    CALL bl_cl.pr_load_ce_booking_channels();
    CALL bl_cl.pr_load_ce_payment_methods();
    CALL bl_cl.pr_load_ce_loyalties();
    CALL bl_cl.pr_load_ce_travel_insurances();
    CALL bl_cl.pr_load_ce_satisfaction_statuses();
    CALL bl_cl.pr_load_ce_travels();
    CALL bl_cl.pr_load_ce_customers_scd();
    CALL bl_cl.pr_load_ce_bookings();
    CALL bl_cl.pr_load_ce_customer_satisfactions();

    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_bl_3nf_increment', 0, 'SUCCESS',
        'All BL_3NF procedures completed in dependency order.'
    );
EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_bl_3nf_increment', 0, 'FAILED',
        format('SQLSTATE=%s; %s', SQLSTATE, SQLERRM)
    );
    RAISE;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.pr_load_bl_dm_increment
(
    p_from_date DATE DEFAULT NULL,
    p_to_date   DATE DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL bl_cl.pr_load_dim_booking_channels();
    CALL bl_cl.pr_load_dim_payment_methods();
    CALL bl_cl.pr_load_dim_loyalties();
    CALL bl_cl.pr_load_dim_travel_insurances();
    CALL bl_cl.pr_load_dim_satisfaction_statuses();
    CALL bl_cl.pr_load_dim_travels();
    CALL bl_cl.pr_load_dim_customers_scd();

    /* Keep the existing restartable time-dimension procedure. */
    CALL bl_cl.pr_load_dim_time_day();

    CALL bl_cl.pr_load_fct_bookings_dd(p_from_date, p_to_date);
    CALL bl_cl.pr_load_fct_customer_satisfactions_dd(p_from_date, p_to_date);

    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_bl_dm_increment', 0, 'SUCCESS',
        'All BL_DM procedures completed in dependency order.'
    );
EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_bl_dm_increment', 0, 'FAILED',
        format('SQLSTATE=%s; %s', SQLSTATE, SQLERRM)
    );
    RAISE;
END;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.pr_load_all_increment
(
    p_from_date DATE DEFAULT NULL,
    p_to_date   DATE DEFAULT NULL,
    p_run_tests BOOLEAN DEFAULT TRUE
)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL bl_cl.pr_load_bl_3nf_increment();
    CALL bl_cl.pr_load_bl_dm_increment(p_from_date, p_to_date);

    IF p_run_tests THEN
        CALL bl_cl.pr_run_data_quality_tests();
    END IF;

    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_all_increment', 0, 'SUCCESS',
        'Complete incremental DWH load finished successfully.'
    );
EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.pr_write_log(
        'bl_cl.pr_load_all_increment', 0, 'FAILED',
        format('SQLSTATE=%s; %s', SQLSTATE, SQLERRM)
    );
    RAISE;
END;
$$;

/* ============================================================================
   5. DATA-QUALITY MONITORING
   - test_group = 1: duplicates
   - test_group = 2: all SA business keys represented in business layer
   - explicit cursor and dynamic EXECUTE are used
   ============================================================================ */

CREATE TABLE IF NOT EXISTS bl_cl.data_quality_tests
(
    test_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    test_group       SMALLINT NOT NULL CHECK (test_group IN (1, 2)),
    test_name        TEXT NOT NULL UNIQUE,
    target_object    TEXT NOT NULL,
    test_sql         TEXT NOT NULL,
    expected_value   BIGINT NOT NULL DEFAULT 0,
    is_active        CHAR(1) NOT NULL DEFAULT 'Y' CHECK (is_active IN ('Y', 'N')) ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

/* Keep monitoring status consistent with the DWH Y/N convention.
   This also converts the column when an earlier version created it as BOOLEAN. */
DO $$
DECLARE
    v_data_type TEXT;
BEGIN
    SELECT data_type
      INTO v_data_type
      FROM information_schema.columns
     WHERE table_schema = 'bl_cl'
       AND table_name = 'data_quality_tests'
       AND column_name = 'is_active';

    IF v_data_type = 'boolean' THEN
        ALTER TABLE bl_cl.data_quality_tests
            ALTER COLUMN is_active DROP DEFAULT;

        ALTER TABLE bl_cl.data_quality_tests
            ALTER COLUMN is_active TYPE CHAR(1)
            USING CASE WHEN is_active THEN 'Y' ELSE 'N' END;

        ALTER TABLE bl_cl.data_quality_tests
            ALTER COLUMN is_active SET DEFAULT 'Y';
    END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS bl_cl.data_quality_test_results
(
    result_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    test_id          BIGINT NOT NULL,
    run_dttm         TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    actual_value     BIGINT,
    expected_value   BIGINT NOT NULL,
    status           VARCHAR(10) NOT NULL CHECK (status IN ('PASSED', 'FAILED', 'ERROR')),
    error_message    TEXT,
    executed_by      TEXT NOT NULL DEFAULT session_user
);

/* Upsert the mandatory tests. Each SQL must return exactly one BIGINT value. */
INSERT INTO bl_cl.data_quality_tests
(
    test_group, test_name, target_object, test_sql, expected_value
)
VALUES
(
    1,
    'No duplicate booking facts',
    'bl_dm.fct_bookings_dd',
    $test$
        SELECT count(*)
        FROM
        (
            SELECT booking_src_id
            FROM bl_dm.fct_bookings_dd
            GROUP BY booking_src_id
            HAVING count(*) > 1
        ) d
    $test$,
    0
),
(
    1,
    'No duplicate customer-satisfaction facts',
    'bl_dm.fct_customer_satisfactions_dd',
    $test$
        SELECT count(*)
        FROM
        (
            SELECT customer_satisfaction_src_id
            FROM bl_dm.fct_customer_satisfactions_dd
            GROUP BY customer_satisfaction_src_id
            HAVING count(*) > 1
        ) d
    $test$,
    0
),
(
    1,
    'One active SCD2 customer version',
    'bl_dm.dim_customers_scd',
    $test$
        SELECT count(*)
        FROM
        (
            SELECT customer_src_id, source_system, source_entity
            FROM bl_dm.dim_customers_scd
            WHERE is_active = 'Y'
            GROUP BY customer_src_id, source_system, source_entity
            HAVING count(*) > 1
        ) d
    $test$,
    0
),
(
    1,
    'No overlapping SCD2 customer periods',
    'bl_dm.dim_customers_scd',
    $test$
        SELECT count(*)
        FROM bl_dm.dim_customers_scd a
        JOIN bl_dm.dim_customers_scd b
          ON a.customer_src_id = b.customer_src_id
         AND a.source_system = b.source_system
         AND a.source_entity = b.source_entity
         AND a.customer_surr_id < b.customer_surr_id
         AND daterange(a.start_dt, a.end_dt, '[]') &&
             daterange(b.start_dt, b.end_dt, '[]')
    $test$,
    0
),
(
    2,
    'All SA booking business keys exist in BL_3NF',
    'bl_3nf.ce_bookings',
    $test$
        SELECT count(*)
        FROM
        (
            SELECT DISTINCT NULLIF(btrim(s.booking_id), '') AS booking_id
            FROM sa_bookings.src_bookings s
            WHERE NULLIF(btrim(s.booking_id), '') IS NOT NULL
        ) s
        LEFT JOIN bl_3nf.ce_bookings t
          ON t.booking_id::TEXT = s.booking_id
        WHERE t.booking_id IS NULL
    $test$,
    0
),
(
    2,
    'All SA satisfaction business keys exist in BL_3NF',
    'bl_3nf.ce_customer_satisfactions',
    $test$
        SELECT count(*)
        FROM
        (
            SELECT DISTINCT NULLIF(btrim(s.survey_id), '') AS survey_id
            FROM sa_customer_satisfactions.src_customer_satisfactions s
            WHERE NULLIF(btrim(s.survey_id), '') IS NOT NULL
        ) s
        LEFT JOIN bl_3nf.ce_customer_satisfactions t
          ON t.customer_satisfaction_src_id::TEXT = s.survey_id
        WHERE t.customer_satisfaction_id IS NULL
    $test$,
    0
),
(
    2,
    'All BL_3NF bookings exist in booking fact',
    'bl_dm.fct_bookings_dd',
    $test$
        SELECT count(*)
        FROM bl_3nf.ce_bookings s
        LEFT JOIN bl_dm.fct_bookings_dd t
          ON t.booking_src_id::TEXT = s.booking_id::TEXT
        WHERE s.booking_id <> -1
          AND t.booking_src_id IS NULL
    $test$,
    0
),
(
    2,
    'All BL_3NF satisfactions exist in satisfaction fact',
    'bl_dm.fct_customer_satisfactions_dd',
    $test$
        SELECT count(*)
        FROM bl_3nf.ce_customer_satisfactions s
        LEFT JOIN bl_dm.fct_customer_satisfactions_dd t
          ON t.customer_satisfaction_src_id::TEXT =
             s.customer_satisfaction_src_id::TEXT
        WHERE s.customer_satisfaction_id <> -1
          AND t.customer_satisfaction_src_id IS NULL
    $test$,
    0
)
ON CONFLICT (test_name)
DO UPDATE SET
    test_group = EXCLUDED.test_group,
    target_object = EXCLUDED.target_object,
    test_sql = EXCLUDED.test_sql,
    expected_value = EXCLUDED.expected_value,
    is_active = 'Y';

CREATE OR REPLACE PROCEDURE bl_cl.pr_run_data_quality_tests()
LANGUAGE plpgsql
AS $$
DECLARE
    cur_tests CURSOR FOR
        SELECT
            test_id,
            test_name,
            test_sql,
            expected_value
        FROM bl_cl.data_quality_tests
        WHERE is_active = 'Y'
        ORDER BY test_group, test_id;

    r_test       RECORD;
    v_actual     BIGINT;
    v_passed     BIGINT := 0;
    v_failed     BIGINT := 0;
BEGIN
    OPEN cur_tests;

    LOOP
        FETCH cur_tests INTO r_test;
        EXIT WHEN NOT FOUND;

        BEGIN
            EXECUTE r_test.test_sql INTO v_actual;

            INSERT INTO bl_cl.data_quality_test_results
            (
                test_id,
                actual_value,
                expected_value,
                status
            )
            VALUES
            (
                r_test.test_id,
                v_actual,
                r_test.expected_value,
                CASE
                    WHEN v_actual = r_test.expected_value THEN 'PASSED'
                    ELSE 'FAILED'
                END
            );

            IF v_actual = r_test.expected_value THEN
                v_passed := v_passed + 1;
            ELSE
                v_failed := v_failed + 1;
            END IF;

        EXCEPTION WHEN OTHERS THEN
            INSERT INTO bl_cl.data_quality_test_results
            (
                test_id,
                actual_value,
                expected_value,
                status,
                error_message
            )
            VALUES
            (
                r_test.test_id,
                NULL,
                r_test.expected_value,
                'ERROR',
                format('SQLSTATE=%s; %s', SQLSTATE, SQLERRM)
            );

            v_failed := v_failed + 1;
        END;
    END LOOP;

    CLOSE cur_tests;

    CALL bl_cl.pr_write_log(
        'bl_cl.pr_run_data_quality_tests',
        v_passed + v_failed,
        CASE WHEN v_failed = 0 THEN 'SUCCESS' ELSE 'FAILED' END,
        format('Tests completed: passed=%s, failed/error=%s.',
               v_passed, v_failed)
    );
END;
$$;

/* ============================================================================
   EXECUTION EXAMPLES
   ============================================================================

   -- Load the incremental date range and run all tests:
   CALL bl_cl.pr_load_all_increment(
       p_from_date => DATE '2025-09-01',
       p_to_date   => DATE '2025-09-30',
       p_run_tests => TRUE
   );

   -- Restartability check: execute the same call again.
   -- No duplicate facts or duplicate active SCD2 records should appear.

   -- Review logs:
   SELECT *
   FROM bl_cl.etl_load_log
   ORDER BY log_id DESC;

   -- Review latest test results:
   SELECT
       r.run_dttm,
       t.test_group,
       t.test_name,
       r.actual_value,
       r.expected_value,
       r.status,
       r.error_message
   FROM bl_cl.data_quality_test_results r
   JOIN bl_cl.data_quality_tests t
     ON t.test_id = r.test_id
   ORDER BY r.result_id DESC;
   ============================================================================ */
