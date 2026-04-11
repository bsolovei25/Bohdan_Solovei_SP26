DROP TABLE IF EXISTS public.table_to_delete;

CREATE TABLE public.table_to_delete AS
SELECT
    'veeeeeeery_long_string' || x AS col
FROM generate_series(1, (10^7)::int) AS x;

SELECT COUNT(*) AS row_count
FROM public.table_to_delete;
-- the table public.table_to_delete containts 10M

SELECT
    *,
    pg_size_pretty(total_bytes) AS total,
    pg_size_pretty(index_bytes) AS index,
    pg_size_pretty(toast_bytes) AS toast,
    pg_size_pretty(table_bytes) AS table
FROM (
    SELECT
        *,
        total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT
            c.oid,
            nspname AS table_schema,
            relname AS table_name,
            c.reltuples AS row_estimate,
            pg_total_relation_size(c.oid) AS total_bytes,
            pg_indexes_size(c.oid) AS index_bytes,
            pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class AS c
        LEFT JOIN pg_namespace AS n
            ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) AS a
) AS a
WHERE table_schema = 'public'
  AND table_name = 'table_to_delete';

-- The total size of the table is 575MB, TOAT size 8192 bytes (8 KB)

DELETE FROM public.table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string', '')::int % 3 = 0;
--execution time for this query is 7.547s

SELECT COUNT(*) AS row_count
FROM public.table_to_delete;
-- the total rows remaining is - 6666667


SELECT
    *,
    pg_size_pretty(total_bytes) AS total,
    pg_size_pretty(index_bytes) AS index,
    pg_size_pretty(toast_bytes) AS toast,
    pg_size_pretty(table_bytes) AS table
FROM (
    SELECT
        *,
        total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT
            c.oid,
            nspname AS table_schema,
            relname AS table_name,
            c.reltuples AS row_estimate,
            pg_total_relation_size(c.oid) AS total_bytes,
            pg_indexes_size(c.oid) AS index_bytes,
            pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class AS c
        LEFT JOIN pg_namespace AS n
            ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) AS a
) AS a
WHERE table_schema = 'public'
  AND table_name = 'table_to_delete';
--the space after deletion of the table is 575MB - the size is same after drop of 1/3 rows as DROP usually does not shrink the table file immediately

VACUUM FULL VERBOSE public.table_to_delete;
--after VACUUM the size of total bytes shrinked to 401580032 < 602MB, total space shrinked tp 383MB < 575MB

--recreated table using commands on the top of the file

TRUNCATE public.table_to_delete;
--it took 0.057s to TRUNCATE the table

SELECT COUNT(*) AS row_count
FROM public.table_to_delete;
-- the remaining amount of rows is equal to 0
-- the space remaining after TRUNCATE is 8,192 bytes 
-- the TRUNCATE command deletes all the rows of the table but remains the structure of the table where as DELETE marks rows as dead tuples and removes them


