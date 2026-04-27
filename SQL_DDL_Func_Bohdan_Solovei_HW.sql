CREATE SCHEMA IF NOT EXISTS core;

CREATE OR REPLACE VIEW core.sales_revenue_by_category_qtr AS
SELECT
    c.name AS category_name,
    SUM(p.amount) AS total_sales_revenue
FROM payment AS p
JOIN rental AS r
    ON r.rental_id = p.rental_id
JOIN inventory AS i
    ON i.inventory_id = r.inventory_id
JOIN film_category AS fc
    ON fc.film_id = i.film_id
JOIN category AS c
    ON c.category_id = fc.category_id
WHERE EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
GROUP BY c.name
HAVING SUM(p.amount) > 0
ORDER BY total_sales_revenue DESC, c.name;

--select distinct EXTRACT(YEAR FROM p.payment_date),EXTRACT(QUARTER FROM p.payment_date) from payment AS p

--SELECT * FROM core.sales_revenue_by_category_qtr;

-- Example of data that should NOT appear
SELECT
    EXTRACT(YEAR FROM payment_date) AS yr,
    EXTRACT(QUARTER FROM payment_date) AS qtr,
    COUNT(*) AS payments_cnt,
    SUM(amount) AS revenue
FROM payment
GROUP BY 1, 2
ORDER BY 1, 2;


CREATE OR REPLACE FUNCTION core.get_sales_revenue_by_category_qtr(
    p_year integer,
    p_quarter integer
)
RETURNS TABLE (
    category_name text,
    total_sales_revenue numeric
)
LANGUAGE sql
AS $$
    SELECT
        c.name::text AS category_name,
        SUM(p.amount) AS total_sales_revenue
    FROM payment AS p
    JOIN rental AS r
        ON r.rental_id = p.rental_id
    JOIN inventory AS i
        ON i.inventory_id = r.inventory_id
    JOIN film_category AS fc
        ON fc.film_id = i.film_id
    JOIN category AS c
        ON c.category_id = fc.category_id
    WHERE EXTRACT(YEAR FROM p.payment_date) = p_year
      AND EXTRACT(QUARTER FROM p.payment_date) = p_quarter
    GROUP BY c.name
    HAVING SUM(p.amount) > 0
    ORDER BY total_sales_revenue DESC, c.name;
$$;


                                                                                           CREATE OR REPLACE VIEW core.sales_revenue_by_category_qtr AS
                                                                                           SELECT
                                                                                               c.name AS category_name,
                                                                                               SUM(p.amount) AS total_sales_revenue
                                                                                           FROM payment AS p
                                                                                           JOIN rental AS r
                                                                                               ON r.rental_id = p.rental_id
                                                                                           JOIN inventory AS i
                                                                                               ON i.inventory_id = r.inventory_id
                                                                                           JOIN film_category AS fc
                                                                                               ON fc.film_id = i.film_id
                                                                                           JOIN category AS c
                                                                                               ON c.category_id = fc.category_id
CREATE OR REPLACE FUNCTION core.get_sales_revenue_by_category_qtr_checked(
    p_year integer,
    p_quarter integer
)
RETURNS TABLE (
    category_name text,
    total_sales_revenue numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_year IS NULL THEN
        RAISE EXCEPTION 'Year parameter cannot be NULL';
    END IF;

    IF p_quarter IS NULL THEN
        RAISE EXCEPTION 'Quarter parameter cannot be NULL';
    END IF;

    IF p_quarter NOT BETWEEN 1 AND 4 THEN
        RAISE EXCEPTION 'Invalid quarter: %. Allowed values are 1, 2, 3, 4', p_quarter;
    END IF;

    RETURN QUERY
    SELECT *
    FROM core.get_sales_revenue_by_category_qtr(p_year, p_quarter);
END;
$$;


SELECT * FROM core.get_sales_revenue_by_category_qtr(2017, 2);


SELECT * FROM core.get_sales_revenue_by_category_qtr(2017, 5);

SELECT * FROM core.get_sales_revenue_by_category_qtr_checked(2017, 5);


CREATE OR REPLACE FUNCTION core.most_popular_films_by_countries(
    p_countries text[]
)
RETURNS TABLE (
    country text,
    film text,
    rating mpaa_rating,
    language text,
    length smallint,
    release_year integer
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_countries IS NULL THEN
        RAISE EXCEPTION 'Country array cannot be NULL';
    END IF;

    IF array_length(p_countries, 1) IS NULL THEN
        RAISE EXCEPTION 'Country array cannot be empty';
    END IF;

    RETURN QUERY
    WITH requested_countries AS (
        SELECT unnest(p_countries)::text AS country_name
    ),
    ranked_films AS (
        SELECT
            co.country,
            f.title,
            f.rating,
            l.name AS language_name,
            f.length,
            f.release_year::integer AS release_year,
            COUNT(r.rental_id) AS rental_count,
            ROW_NUMBER() OVER (
                PARTITION BY co.country
                ORDER BY COUNT(r.rental_id) DESC, f.title ASC
            ) AS rn
        FROM country AS co
        JOIN city AS ci
            ON ci.country_id = co.country_id
        JOIN address AS a
            ON a.city_id = ci.city_id
        JOIN customer AS cu
            ON cu.address_id = a.address_id
        JOIN rental AS r
            ON r.customer_id = cu.customer_id
        JOIN inventory AS i
            ON i.inventory_id = r.inventory_id
        JOIN film AS f
            ON f.film_id = i.film_id
        JOIN language AS l
            ON l.language_id = f.language_id
        WHERE co.country IN (SELECT country_name FROM requested_countries)
        GROUP BY
            co.country, f.title, f.rating, l.name, f.length, f.release_year
    )
    SELECT
        rc.country_name::text AS country,
        rf.title::text AS film,
        rf.rating,
        rf.language_name::text AS language,
        rf.length::smallint,
        rf.release_year::integer
    FROM requested_countries AS rc
    LEFT JOIN ranked_films AS rf
        ON rf.country = rc.country_name
       AND rf.rn = 1
    ORDER BY rc.country_name;
END;
$$;

SELECT * 
FROM core.most_popular_films_by_countries(ARRAY['Afghanistan','Brazil','United States']);

SELECT *
FROM core.most_popular_films_by_countries(ARRAY['Atlantis','Brazil']);




CREATE OR REPLACE FUNCTION core.films_in_stock_by_title(
    p_title_pattern text,
    p_store_id integer DEFAULT NULL
)
RETURNS TABLE (
    row_num bigint,
    film_title text,
    language text,
    customer_name text,
    rental_date timestamp without time zone
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_title_pattern IS NULL OR btrim(p_title_pattern) = '' THEN
        RAISE EXCEPTION 'Title pattern cannot be NULL or blank';
    END IF;

    IF p_store_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM store s
           WHERE s.store_id = p_store_id
       ) THEN
        RAISE EXCEPTION 'Store ID % does not exist', p_store_id;
    END IF;

    IF NOT EXISTS (
        WITH matched_films AS (
            SELECT f.film_id, f.title
            FROM film f
            WHERE f.title ILIKE p_title_pattern
        ),
        available_inventory AS (
            SELECT i.inventory_id, i.film_id
            FROM inventory i
            LEFT JOIN rental r
                ON r.inventory_id = i.inventory_id
               AND r.return_date IS NULL
            WHERE r.inventory_id IS NULL
              AND (p_store_id IS NULL OR i.store_id = p_store_id)
        )
        SELECT 1
        FROM matched_films mf
        JOIN available_inventory ai
          ON ai.film_id = mf.film_id
    ) THEN
        RAISE EXCEPTION 'No in-stock films found for pattern: %', p_title_pattern;
    END IF;

    RETURN QUERY
    WITH matched_films AS (
        SELECT f.film_id, f.title, l.name AS language_name
        FROM film f
        JOIN language l
            ON l.language_id = f.language_id
        WHERE f.title ILIKE p_title_pattern
    ),
    available_inventory AS (
        SELECT i.inventory_id, i.film_id
        FROM inventory i
        LEFT JOIN rental r
            ON r.inventory_id = i.inventory_id
           AND r.return_date IS NULL
        WHERE r.inventory_id IS NULL
          AND (p_store_id IS NULL OR i.store_id = p_store_id)
    ),
    latest_rental AS (
        SELECT
            ai.inventory_id,
            MAX(r.rental_date) AS rental_date
        FROM available_inventory ai
        LEFT JOIN rental r
            ON r.inventory_id = ai.inventory_id
        GROUP BY ai.inventory_id
    ),
    latest_customer AS (
        SELECT
            lr.inventory_id,
            c.first_name || ' ' || c.last_name AS customer_name,
            lr.rental_date
        FROM latest_rental lr
        LEFT JOIN rental r
            ON r.inventory_id = lr.inventory_id
           AND r.rental_date = lr.rental_date
        LEFT JOIN customer c
            ON c.customer_id = r.customer_id
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY mf.title, ai.inventory_id) AS row_num,
        mf.title::text AS film_title,
        mf.language_name::text AS language,
        lc.customer_name::text AS customer_name,
        lc.rental_date::timestamp without time zone AS rental_date
    FROM matched_films mf
    JOIN available_inventory ai
        ON ai.film_id = mf.film_id
    LEFT JOIN latest_customer lc
        ON lc.inventory_id = ai.inventory_id
    ORDER BY mf.title, ai.inventory_id;
END;
$$;

SELECT * FROM core.films_in_stock_by_title('%love%');

SELECT * FROM core.films_in_stock_by_title('%love%', 1);


CREATE OR REPLACE FUNCTION core.new_movie(
    p_title text,
    p_release_year integer,
    p_language_name text
)
RETURNS TABLE (
    film_id integer,
    title text,
    release_year integer,
    language_name text,
    rental_duration integer,
    rental_rate numeric,
    replacement_cost numeric
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_film_id integer;
    v_language_id integer;
BEGIN
    IF p_title IS NULL OR btrim(p_title) = '' THEN
        RAISE EXCEPTION 'Movie title cannot be NULL or blank';
    END IF;

    IF p_release_year IS NULL THEN
        p_release_year := EXTRACT(YEAR FROM CURRENT_DATE)::integer;
    END IF;

    IF p_language_name IS NULL OR btrim(p_language_name) = '' THEN
        p_language_name := 'Klingon';
    END IF;

    IF p_release_year < 1888 OR p_release_year > EXTRACT(YEAR FROM CURRENT_DATE)::integer + 5 THEN
        RAISE EXCEPTION 'Release year % is outside allowed range', p_release_year;
    END IF;

    SELECT l.language_id
    INTO v_language_id
    FROM language l
    WHERE UPPER(l.name) = UPPER(p_language_name);

    IF v_language_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" does not exist in language table', p_language_name;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM film f
        WHERE UPPER(f.title) = UPPER(p_title)
    ) THEN
        RAISE EXCEPTION 'Movie "%" already exists', p_title;
    END IF;

    SELECT COALESCE(MAX(f.film_id), 0) + 1
    INTO v_film_id
    FROM film f;

    INSERT INTO film (
        film_id,
        title,
        description,
        release_year,
        language_id,
        original_language_id,
        rental_duration,
        rental_rate,
        length,
        replacement_cost,
        rating,
        last_update,
        special_features,
        fulltext
    )
    VALUES (
        v_film_id,
        btrim(p_title),
        'Inserted by core.new_movie',
        p_release_year,
        v_language_id,
        NULL,
        3,
        4.99,
        90,
        19.99,
        'PG',
        CURRENT_TIMESTAMP,
        ARRAY['Trailers']::text[],
        to_tsvector(btrim(p_title))
    );

    RETURN QUERY
    SELECT
        f.film_id,
        f.title::text,
        f.release_year::integer,
        l.name::text,
        f.rental_duration::integer,
        f.rental_rate,
        f.replacement_cost
    FROM film f
    JOIN language l
        ON l.language_id = f.language_id
    WHERE f.film_id = v_film_id;
END;
$$;

SELECT * FROM core.new_movie('My New Demo Film',2017, 'English');
