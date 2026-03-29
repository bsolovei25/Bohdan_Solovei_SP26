/*
Subtask 1
- Insert 3 real favorite movies into public.film
- Assign each movie to a genre in public.film_category
- Use INSERT ... SELECT instead of INSERT ... VALUES
- Set last_update = current_date
- Avoid duplicates
- Return inserted rows
- Separate transaction:
  If this block fails, only film/category inserts are rolled back.
  Previously committed blocks remain unchanged.

Why INSERT ... SELECT is better here:
- allows dynamic lookup of foreign keys (language_id, category_id)
- avoids hardcoded IDs
- makes the script rerunnable with WHERE NOT EXISTS
*/

BEGIN;

WITH movie_seed AS (
    SELECT
        v.title,
        v.description,
        v.release_year::public.year AS release_year,
        v.rental_duration,
        v.rental_rate,
        v.length_minutes,
        v.replacement_cost,
        v.rating::public.mpaa_rating AS rating,
        v.special_features,
        v.category_name
    FROM (
        VALUES
            (
                'Spirited Away',
                'During her family''s move to the suburbs, a ten-year-old girl wanders into a world ruled by spirits.',
                2001,
                7,
                4.99,
                125,
                19.99,
                'PG',
                ARRAY['Behind the Scenes', 'Commentaries']::text[],
                'Animation'
            ),
            (
                'The Dark Knight',
                'Batman faces the Joker, a criminal mastermind who pushes Gotham into chaos.',
                2008,
                14,
                9.99,
                152,
                29.99,
                'PG-13',
                ARRAY['Deleted Scenes', 'Behind the Scenes']::text[],
                'Action'
            ),
            (
                'Interstellar',
                'A team of explorers travels through a wormhole in space in an attempt to ensure humanity''s survival.',
                2014,
                21,
                19.99,
                169,
                39.99,
                'PG-13',
                ARRAY['Behind the Scenes', 'Trailers']::text[],
                'Sci-Fi'
            )
    ) AS v(
        title,
        description,
        release_year,
        rental_duration,
        rental_rate,
        length_minutes,
        replacement_cost,
        rating,
        special_features,
        category_name
    )
),
english_language AS (
    SELECT l.language_id
    FROM public.language AS l
    WHERE l.name = 'English'
),
inserted_films AS (
    INSERT INTO public.film (
        title,
        description,
        release_year,
        language_id,
        rental_duration,
        rental_rate,
        length,
        replacement_cost,
        rating,
        last_update,
        special_features
    )
    SELECT
        ms.title,
        ms.description,
        ms.release_year,
        el.language_id,
        ms.rental_duration,
        ms.rental_rate,
        ms.length_minutes,
        ms.replacement_cost,
        ms.rating,
        current_date,
        ms.special_features
    FROM movie_seed AS ms
    CROSS JOIN english_language AS el
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.film AS f
        WHERE UPPER(f.title) = UPPER(ms.title)
          AND f.release_year = ms.release_year
    )
    RETURNING
        film_id,
        title,
        release_year,
        rental_duration,
        rental_rate
),
target_films AS (
    SELECT
        f.film_id,
        f.title,
        f.release_year,
        ms.category_name
    FROM movie_seed AS ms
    INNER JOIN public.film AS f
        ON UPPER(f.title) = UPPER(ms.title)
       AND f.release_year = ms.release_year
),
inserted_film_categories AS (
    INSERT INTO public.film_category (
        film_id,
        category_id,
        last_update
    )
    SELECT
        tf.film_id,
        c.category_id,
        current_date
    FROM target_films AS tf
    INNER JOIN public.category AS c
        ON c.name = tf.category_name
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.film_category AS fc
        WHERE fc.film_id = tf.film_id
          AND fc.category_id = c.category_id
    )
    RETURNING
        film_id,
        category_id
)
SELECT
    f.film_id,
    f.title,
    f.release_year,
    f.rental_duration,
    f.rental_rate
FROM public.film AS f
WHERE UPPER(f.title) IN (
    UPPER('Spirited Away'),
    UPPER('The Dark Knight'),
    UPPER('Interstellar')
)
ORDER BY f.title;

COMMIT;



/*
Subtask 2
- Insert real actors into public.actor
- Link them in public.film_actor
- Avoid duplicates
- Set last_update = current_date
- Return inserted rows
- Separate transaction:
  If this block fails, actor / film_actor changes are rolled back.

How duplicates are avoided:
- actor uniqueness is checked by exact normalized first_name + last_name
- film_actor uniqueness is checked by actor_id + film_id
*/

BEGIN;

WITH actor_seed AS (
    SELECT
        v.movie_title,
        v.first_name,
        v.last_name
    FROM (
        VALUES
            ('Spirited Away', 'Rumi', 'Hiiragi'),
            ('Spirited Away', 'Miyu', 'Irino'),
            ('Spirited Away', 'Mari', 'Natsuki'),

            ('The Dark Knight', 'Christian', 'Bale'),
            ('The Dark Knight', 'Heath', 'Ledger'),
            ('The Dark Knight', 'Aaron', 'Eckhart'),

            ('Interstellar', 'Matthew', 'McConaughey'),
            ('Interstellar', 'Anne', 'Hathaway'),
            ('Interstellar', 'Jessica', 'Chastain')
    ) AS v(movie_title, first_name, last_name)
),
inserted_actors AS (
    INSERT INTO public.actor (
        first_name,
        last_name,
        last_update
    )
    SELECT DISTINCT
        s.first_name,
        s.last_name,
        current_date
    FROM actor_seed AS s
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.actor AS a
        WHERE UPPER(a.first_name) = UPPER(s.first_name)
          AND UPPER(a.last_name) = UPPER(s.last_name)
    )
    RETURNING
        actor_id,
        first_name,
        last_name
),
actor_film_pairs AS (
    SELECT
        a.actor_id,
        f.film_id,
        s.movie_title,
        a.first_name,
        a.last_name
    FROM actor_seed AS s
    INNER JOIN public.actor AS a
        ON UPPER(a.first_name) = UPPER(s.first_name)
       AND UPPER(a.last_name) = UPPER(s.last_name)
    INNER JOIN public.film AS f
        ON UPPER(f.title) = UPPER(s.movie_title)
),
inserted_film_actor AS (
    INSERT INTO public.film_actor (
        actor_id,
        film_id,
        last_update
    )
    SELECT
        afp.actor_id,
        afp.film_id,
        current_date
    FROM actor_film_pairs AS afp
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.film_actor AS fa
        WHERE fa.actor_id = afp.actor_id
          AND fa.film_id = afp.film_id
    )
    RETURNING
        actor_id,
        film_id
)
SELECT
    afp.movie_title,
    afp.first_name,
    afp.last_name,
    afp.actor_id,
    afp.film_id
FROM actor_film_pairs AS afp
ORDER BY afp.movie_title, afp.last_name, afp.first_name;

COMMIT;



/*
Subtask 3
- Add favorite films to one store's inventory
- Avoid duplicate inventory rows for the same film/store pair
- Set last_update = current_date
- Return inserted rows

Why separate transaction:
- inventory is an independent step
- if it fails, rental/payment steps can be postponed without affecting inserted films/actors
*/

BEGIN;

WITH target_store AS (
    SELECT MIN(s.store_id) AS store_id
    FROM public.store AS s
),
target_films AS (
    SELECT
        f.film_id,
        f.title
    FROM public.film AS f
    WHERE UPPER(f.title) IN (
        UPPER('Spirited Away'),
        UPPER('The Dark Knight'),
        UPPER('Interstellar')
    )
),
inserted_inventory AS (
    INSERT INTO public.inventory (
        film_id,
        store_id,
        last_update
    )
    SELECT
        tf.film_id,
        ts.store_id,
        current_date
    FROM target_films AS tf
    CROSS JOIN target_store AS ts
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.inventory AS i
        WHERE i.film_id = tf.film_id
          AND i.store_id = ts.store_id
    )
    RETURNING
        inventory_id,
        film_id,
        store_id
)
SELECT
    i.inventory_id,
    i.store_id,
    f.title
FROM public.inventory AS i
INNER JOIN public.film AS f
    ON f.film_id = i.film_id
WHERE UPPER(f.title) IN (
    UPPER('Spirited Away'),
    UPPER('The Dark Knight'),
    UPPER('Interstellar')
)
ORDER BY f.title, i.store_id, i.inventory_id;

COMMIT;

/*
Subtask 4
- Find one customer with at least 43 rentals and 43 payments
- Reuse the same customer on reruns if the email already matches params.target_email
- Update personal data only in public.customer
- Do not update public.address
- Use any existing address from public.address
- Set last_update = current_date
- Double-check with SELECT before UPDATE
- Return updated row

Why separate transaction:
- customer identity change is business-sensitive
- preview SELECT is included before UPDATE
- if UPDATE fails, customer data remains unchanged after rollback
*/

BEGIN;

-- Preview the customer that will be updated
WITH params AS (
    SELECT
        'Bohdan'::text AS target_first_name,
        'Solovei'::text AS target_last_name,
        'bsolovei25@gmail.com'::text AS target_email
),
eligible_customers AS (
    SELECT
        c.customer_id
    FROM public.customer AS c
    INNER JOIN (
        SELECT
            r.customer_id,
            COUNT(*) AS rental_count
        FROM public.rental AS r
        GROUP BY r.customer_id
    ) AS rc
        ON rc.customer_id = c.customer_id
    INNER JOIN (
        SELECT
            p.customer_id,
            COUNT(*) AS payment_count
        FROM public.payment AS p
        GROUP BY p.customer_id
    ) AS pc
        ON pc.customer_id = c.customer_id
    WHERE rc.rental_count >= 43
      AND pc.payment_count >= 43
),
target_customer AS (
    SELECT COALESCE(
        (
            SELECT c.customer_id
            FROM public.customer AS c
            CROSS JOIN params AS p
            WHERE UPPER(COALESCE(c.email, '')) = UPPER(p.target_email)
            LIMIT 1
        ),
        (
            SELECT MIN(ec.customer_id)
            FROM eligible_customers AS ec
        )
    ) AS customer_id
)
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.address_id,
    c.store_id
FROM public.customer AS c
INNER JOIN target_customer AS tc
    ON tc.customer_id = c.customer_id;

-- Actual update
WITH params AS (
    SELECT
        'Bohdan'::text AS target_first_name,
        'Solovei'::text AS target_last_name,
        'bsolovei25@gmail.com'::text AS target_email
),
target_store AS (
    SELECT MIN(s.store_id) AS store_id
    FROM public.store AS s
),
target_address AS (
    SELECT MIN(a.address_id) AS address_id
    FROM public.address AS a
),
eligible_customers AS (
    SELECT
        c.customer_id
    FROM public.customer AS c
    INNER JOIN (
        SELECT
            r.customer_id,
            COUNT(*) AS rental_count
        FROM public.rental AS r
        GROUP BY r.customer_id
    ) AS rc
        ON rc.customer_id = c.customer_id
    INNER JOIN (
        SELECT
            p.customer_id,
            COUNT(*) AS payment_count
        FROM public.payment AS p
        GROUP BY p.customer_id
    ) AS pc
        ON pc.customer_id = c.customer_id
    WHERE rc.rental_count >= 43
      AND pc.payment_count >= 43
),
target_customer AS (
    SELECT COALESCE(
        (
            SELECT c.customer_id
            FROM public.customer AS c
            CROSS JOIN params AS p
            WHERE UPPER(COALESCE(c.email, '')) = UPPER(p.target_email)
            LIMIT 1
        ),
        (
            SELECT MIN(ec.customer_id)
            FROM eligible_customers AS ec
        )
    ) AS customer_id
)
UPDATE public.customer AS c
SET
    first_name = p.target_first_name,
    last_name = p.target_last_name,
    email = p.target_email,
    address_id = ta.address_id,
    store_id = ts.store_id,
    last_update = current_date
FROM params AS p
CROSS JOIN target_store AS ts
CROSS JOIN target_address AS ta
INNER JOIN target_customer AS tc
    ON TRUE
WHERE c.customer_id = tc.customer_id
RETURNING
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.address_id,
    c.store_id,
    c.last_update;

COMMIT;


/*
Subtask 5
- Remove all records related to the target customer
- Keep rows in public.customer and public.inventory
- Double-check with SELECT before DELETE
- Delete from child table first (payment), then rental
- Return deleted rows

Why deleting is safe:
- scope is limited strictly to one customer identified by params.target_email
- payment is deleted before rental to preserve referential integrity
- no address, inventory, film, actor, or store rows are touched

What happens if transaction fails:
- rollback restores both payment and rental rows deleted in this block
*/

BEGIN;

-- Preview rows to be deleted
WITH params AS (
    SELECT 'bsolovei25@gmail.com'::text AS target_email
),
target_customer AS (
    SELECT c.customer_id
    FROM public.customer AS c
    CROSS JOIN params AS p
    WHERE UPPER(COALESCE(c.email, '')) = UPPER(p.target_email)
)
SELECT
    'payment' AS table_name,
    COUNT(*) AS row_count
FROM public.payment AS p
INNER JOIN target_customer AS tc
    ON tc.customer_id = p.customer_id

UNION ALL

SELECT
    'rental' AS table_name,
    COUNT(*) AS row_count
FROM public.rental AS r
INNER JOIN target_customer AS tc
    ON tc.customer_id = r.customer_id;

-- Delete payment rows first
WITH params AS (
    SELECT 'bsolovei25@gmail.com'::text AS target_email
),
target_customer AS (
    SELECT c.customer_id
    FROM public.customer AS c
    CROSS JOIN params AS p
    WHERE UPPER(COALESCE(c.email, '')) = UPPER(p.target_email)
)
DELETE FROM public.payment AS p
USING target_customer AS tc
WHERE p.customer_id = tc.customer_id
RETURNING
    p.payment_id,
    p.customer_id,
    p.rental_id,
    p.amount,
    p.payment_date;

-- Delete rental rows next
WITH params AS (
    SELECT 'bsolovei25@gmail.com'::text AS target_email
),
target_customer AS (
    SELECT c.customer_id
    FROM public.customer AS c
    CROSS JOIN params AS p
    WHERE UPPER(COALESCE(c.email, '')) = UPPER(p.target_email)
)
DELETE FROM public.rental AS r
USING target_customer AS tc
WHERE r.customer_id = tc.customer_id
RETURNING
    r.rental_id,
    r.customer_id,
    r.inventory_id,
    r.rental_date,
    r.return_date;

COMMIT;


/*
Subtask 6
- Rent the 3 favorite movies for the target customer
- Insert corresponding payments
- Use first half of 2017 for payment_date
- Avoid duplicates
- Return inserted rental/payment rows

Important note:
- public.rental has last_update
- public.payment in dvdrental does not have last_update
*/

BEGIN;

WITH params AS (
    SELECT 'bsolovei25@gmail.com'::text AS target_email
),
target_customer AS (
    SELECT
        c.customer_id,
        c.store_id
    FROM public.customer AS c
    CROSS JOIN params AS p
    WHERE UPPER(COALESCE(c.email, '')) = UPPER(p.target_email)
),
target_staff AS (
    SELECT
        s.store_id,
        MIN(s.staff_id) AS staff_id
    FROM public.staff AS s
    INNER JOIN target_customer AS tc
        ON tc.store_id = s.store_id
    GROUP BY s.store_id
),
rental_seed AS (
    SELECT
        v.title,
        v.rental_date::timestamp AS rental_date
    FROM (
        VALUES
            ('Spirited Away', '2017-06-10 10:00:00'),
            ('The Dark Knight', '2017-06-11 11:00:00'),
            ('Interstellar', '2017-06-12 12:00:00')
    ) AS v(title, rental_date)
),
target_inventory AS (
    SELECT
        f.title,
        f.film_id,
        f.rental_duration,
        f.rental_rate,
        i.inventory_id,
        i.store_id
    FROM public.film AS f
    INNER JOIN public.inventory AS i
        ON i.film_id = f.film_id
    INNER JOIN target_customer AS tc
        ON tc.store_id = i.store_id
    WHERE UPPER(f.title) IN (
        UPPER('Spirited Away'),
        UPPER('The Dark Knight'),
        UPPER('Interstellar')
    )
),
inserted_rentals AS (
    INSERT INTO public.rental (
        rental_date,
        inventory_id,
        customer_id,
        return_date,
        staff_id,
        last_update
    )
    SELECT
        rs.rental_date,
        ti.inventory_id,
        tc.customer_id,
        rs.rental_date + (ti.rental_duration || ' days')::interval,
        ts.staff_id,
        current_date
    FROM rental_seed AS rs
    INNER JOIN target_inventory AS ti
        ON UPPER(ti.title) = UPPER(rs.title)
    CROSS JOIN target_customer AS tc
    INNER JOIN target_staff AS ts
        ON ts.store_id = tc.store_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.rental AS r
        WHERE r.customer_id = tc.customer_id
          AND r.inventory_id = ti.inventory_id
          AND r.rental_date = rs.rental_date
    )
    RETURNING
        rental_id,
        rental_date,
        inventory_id,
        customer_id,
        staff_id
),
inserted_payments AS (
    INSERT INTO public.payment (
        customer_id,
        staff_id,
        rental_id,
        amount,
        payment_date
    )
    SELECT
        ir.customer_id,
        ir.staff_id,
        ir.rental_id,
        ti.rental_rate,
        ir.rental_date
    FROM inserted_rentals AS ir
    INNER JOIN target_inventory AS ti
        ON ti.inventory_id = ir.inventory_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.payment AS p
        WHERE p.rental_id = ir.rental_id
          AND p.customer_id = ir.customer_id
    )
    RETURNING
        payment_id,
        customer_id,
        rental_id,
        amount,
        payment_date
)
SELECT
    f.title,
    r.rental_id,
    r.rental_date,
    p.payment_id,
    p.amount,
    p.payment_date
FROM inserted_rentals AS r
INNER JOIN inserted_payments AS p
    ON p.rental_id = r.rental_id
INNER JOIN public.inventory AS i
    ON i.inventory_id = r.inventory_id
INNER JOIN public.film AS f
    ON f.film_id = i.film_id
ORDER BY
    r.rental_date,
    f.title;

COMMIT;