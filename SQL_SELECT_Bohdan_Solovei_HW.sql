/*
Task 1 conditions:
- Show all animation movies
- Release year between 2017 and 2019 inclusive
- rental_rate > 1
- Sort alphabetically by title
*/
/*I'd recommend  suing solution CTE

CTE solution
*/
 /*JOIN types used:
- INNER JOIN public.film_category: keeps only films that have at least one category mapping
- INNER JOIN public.category: keeps only films whose mapped category exists and matches 'Animation'

Films without a category mapping are excluded, which matches the business logic.
*/
WITH animation_films AS (
    SELECT
        f.film_id,
        f.title,
        f.release_year,
        f.rating,
        f.rental_rate
    FROM public.film AS f
    INNER JOIN public.film_category AS fc
        ON fc.film_id = f.film_id
    INNER JOIN public.category AS c
        ON c.category_id = fc.category_id
    WHERE LOWER(c.name) = 'animation'
)
SELECT
    af.title,
    af.release_year,
    af.rating,
    af.rental_rate
FROM animation_films AS af
WHERE af.release_year BETWEEN 2017 AND 2019
  AND af.rental_rate > 1
ORDER BY af.title ASC;


/*
 * Subquery
JOIN types used inside subquery:
- INNER JOIN public.film_category
- INNER JOIN public.category
- The subquery returns only film_ids that belong to category 'Animation'.
- The outer query then filters films by those ids.
*/
SELECT
    f.title,
    f.release_year,
    f.rating,
    f.rental_rate
FROM public.film AS f
WHERE f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
  AND f.film_id IN (
        SELECT fc.film_id
        FROM public.film_category AS fc
        INNER JOIN public.category AS c
            ON c.category_id = fc.category_id
        WHERE c.name = 'Animation'
    )
ORDER BY f.title ASC;

/*
 * JOIN Solution
JOIN types used:
- INNER JOIN public.film_category
- INNER JOIN public.category
- Returns only films that are connected to the 'Animation' category.
*/
SELECT
    f.title,
    f.release_year,
    f.rating,
    f.rental_rate
FROM public.film AS f
INNER JOIN public.film_category AS fc
    ON fc.film_id = f.film_id
INNER JOIN public.category AS c
    ON c.category_id = fc.category_id
WHERE c.name = 'Animation'
  AND f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title ASC;

/*Task 2
Revenue earned by each store after March 2017 (since April), include concatenated address and revenue
for this task i would recommend using JOIN solution*/

/*

JOIN types used:
- INNER JOIN public.address in store_info: each store must have an address
- LEFT JOIN revenue_by_store to store_info: keeps all stores even if no matching payments exist

Why join types affect the result:
- INNER JOIN store -> address excludes stores with broken address references.
- LEFT JOIN ensures stores with no payments after 2017-03-31 still appear with 0 revenue.
*/
WITH store_info AS (
    SELECT
        s.store_id,
        CONCAT_WS(', ', a.address, a.address2) AS full_address
    FROM public.store AS s
    INNER JOIN public.address AS a
        ON a.address_id = s.address_id
),
revenue_by_store AS (
    SELECT
        st.store_id,
        SUM(p.amount) AS revenue
    FROM public.payment AS p
    INNER JOIN public.staff AS stf
        ON stf.staff_id = p.staff_id
    INNER JOIN public.store AS st
        ON st.store_id = stf.store_id
    WHERE p.payment_date >= DATE '2017-04-01'
    GROUP BY st.store_id
)
SELECT
    si.full_address AS address,
    COALESCE(rbs.revenue, 0) AS revenue
FROM store_info AS si
LEFT JOIN revenue_by_store AS rbs
    ON rbs.store_id = si.store_id
ORDER BY si.full_address ASC;

/*
JOIN types used:
- INNER JOIN public.address: store address is required
- Correlated subquery calculates revenue per store

Why this affects result:
- Main query returns one row per store.
- Correlated subquery aggregates only payments linked to that store through staff.
*/
SELECT
    CONCAT_WS(', ', a.address, a.address2) AS address,
    COALESCE((
        SELECT SUM(p.amount)
        FROM public.payment AS p
        INNER JOIN public.staff AS stf
            ON stf.staff_id = p.staff_id
        WHERE stf.store_id = s.store_id
          AND p.payment_date >= DATE '2017-04-01'
    ), 0) AS revenue
FROM public.store AS s
INNER JOIN public.address AS a
    ON a.address_id = s.address_id
ORDER BY address ASC;

/*
JOIN types used:
- INNER JOIN public.address: store must have an address
- LEFT JOIN public.staff: keeps stores even if no staff match
- LEFT JOIN public.payment with date filter in ON clause: keeps stores even if no payments match after 2017-03-31

Why LEFT JOIN matters:
- If the date filter were in WHERE instead of ON, stores with no qualifying payments would disappear.
- Keeping the filter in ON preserves all stores and allows zero revenue output.
*/
SELECT
    CONCAT_WS(', ', a.address, a.address2) AS address,
    COALESCE(SUM(p.amount), 0) AS revenue
FROM public.store AS s
INNER JOIN public.address AS a
    ON a.address_id = s.address_id
LEFT JOIN public.staff AS stf
    ON stf.store_id = s.store_id
LEFT JOIN public.payment AS p
    ON p.staff_id = stf.staff_id
   AND p.payment_date >= DATE '2017-04-01'
GROUP BY
    s.store_id,
    a.address,
    a.address2
ORDER BY address ASC;

/*Task 3
Top-5 actors by number of movies released since 2015
3A. CTE solution
For this task I would use JOIN solution
*/

/*

JOIN types used:
- INNER JOIN public.film_actor: keeps only actors with film participation records
- INNER JOIN public.film: keeps only films that exist and can be filtered by release_year

Why INNER JOIN affects the result:
- Actors without films since 2015 are excluded, which matches the business requirement.
*/
WITH actor_movie_counts AS (
    SELECT
        a.actor_id,
        a.first_name,
        a.last_name,
        COUNT(DISTINCT f.film_id) AS number_of_movies
    FROM public.actor AS a
    INNER JOIN public.film_actor AS fa
        ON fa.actor_id = a.actor_id
    INNER JOIN public.film AS f
        ON f.film_id = fa.film_id
    WHERE f.release_year >= 2015
    GROUP BY
        a.actor_id,
        a.first_name,
        a.last_name
)
SELECT
    amc.first_name,
    amc.last_name,
    amc.number_of_movies
FROM actor_movie_counts AS amc
ORDER BY
    amc.number_of_movies DESC,
    amc.last_name ASC,
    amc.first_name ASC
LIMIT 5;

/*

JOIN types used inside the subquery:
- INNER JOIN public.film_actor
- INNER JOIN public.film

Why this affects the result:
- The subquery counts only qualifying films for each actor.
- Actors with zero such films are excluded by the WHERE EXISTS condition.
*/
SELECT
    a.first_name,
    a.last_name,
    (
        SELECT COUNT(DISTINCT fa.film_id)
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f
            ON f.film_id = fa.film_id
        WHERE fa.actor_id = a.actor_id
          AND f.release_year >= 2015
    ) AS number_of_movies
FROM public.actor AS a
WHERE EXISTS (
    SELECT 1
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f
        ON f.film_id = fa.film_id
    WHERE fa.actor_id = a.actor_id
      AND f.release_year >= 2015
)
ORDER BY
    number_of_movies DESC,
    a.last_name ASC,
    a.first_name ASC
LIMIT 5;

/*

JOIN types used:
- INNER JOIN public.film_actor
- INNER JOIN public.film

Why INNER JOIN affects the result:
- Only actor-film links with existing films are counted.
- Actors without qualifying films are not returned.
*/
SELECT
    a.first_name,
    a.last_name,
    COUNT(DISTINCT f.film_id) AS number_of_movies
FROM public.actor AS a
INNER JOIN public.film_actor AS fa
    ON fa.actor_id = a.actor_id
INNER JOIN public.film AS f
    ON f.film_id = fa.film_id
WHERE f.release_year >= 2015
GROUP BY
    a.actor_id,
    a.first_name,
    a.last_name
ORDER BY
    number_of_movies DESC,
    a.last_name ASC,
    a.first_name ASC
LIMIT 5;

/*Task 4
Number of Drama, Travel, Documentary films per year
4A. CTE solution
For this task i would use JOIN solution
**/

/*

JOIN types used:
- LEFT JOIN public.film_category: keeps release years from film even if a film has no category row
- LEFT JOIN public.category: keeps rows even if category is absent or different

Why LEFT JOIN affects the result:
- Preserves years from public.film.
- Missing category matches do not remove the year from the result.
*/
WITH genre_counts AS (
    SELECT
        f.release_year,
        SUM(CASE WHEN c.name = 'Drama' THEN 1 ELSE 0 END) AS number_of_drama_movies,
        SUM(CASE WHEN c.name = 'Travel' THEN 1 ELSE 0 END) AS number_of_travel_movies,
        SUM(CASE WHEN c.name = 'Documentary' THEN 1 ELSE 0 END) AS number_of_documentary_movies
    FROM public.film AS f
    LEFT JOIN public.film_category AS fc
        ON fc.film_id = f.film_id
    LEFT JOIN public.category AS c
        ON c.category_id = fc.category_id
    GROUP BY
        f.release_year
)
SELECT
    gc.release_year,
    COALESCE(gc.number_of_drama_movies, 0) AS number_of_drama_movies,
    COALESCE(gc.number_of_travel_movies, 0) AS number_of_travel_movies,
    COALESCE(gc.number_of_documentary_movies, 0) AS number_of_documentary_movies
FROM genre_counts AS gc
ORDER BY gc.release_year DESC;


/*

JOIN types used inside subqueries:
- INNER JOIN public.film_category
- INNER JOIN public.category

Why this affects the result:
- Outer query defines the set of years.
- Each correlated subquery counts films for one genre in that year.
*/
SELECT
    y.release_year,
    COALESCE((
        SELECT COUNT(*)
        FROM public.film AS f1
        INNER JOIN public.film_category AS fc1
            ON fc1.film_id = f1.film_id
        INNER JOIN public.category AS c1
            ON c1.category_id = fc1.category_id
        WHERE f1.release_year = y.release_year
          AND c1.name = 'Drama'
    ), 0) AS number_of_drama_movies,
    COALESCE((
        SELECT COUNT(*)
        FROM public.film AS f2
        INNER JOIN public.film_category AS fc2
            ON fc2.film_id = f2.film_id
        INNER JOIN public.category AS c2
            ON c2.category_id = fc2.category_id
        WHERE f2.release_year = y.release_year
          AND c2.name = 'Travel'
    ), 0) AS number_of_travel_movies,
    COALESCE((
        SELECT COUNT(*)
        FROM public.film AS f3
        INNER JOIN public.film_category AS fc3
            ON fc3.film_id = f3.film_id
        INNER JOIN public.category AS c3
            ON c3.category_id = fc3.category_id
        WHERE f3.release_year = y.release_year
          AND c3.name = 'Documentary'
    ), 0) AS number_of_documentary_movies
FROM (
    SELECT DISTINCT
        f.release_year
    FROM public.film AS f
) AS y
ORDER BY y.release_year DESC;

/*
JOIN types used:
- LEFT JOIN public.film_category
- LEFT JOIN public.category

Why LEFT JOIN affects the result:
- Keeps all years from public.film in the output.
- Years are not lost if some films do not have category rows.
*/
SELECT
    f.release_year,
    COALESCE(SUM(CASE WHEN c.name = 'Drama' THEN 1 ELSE 0 END), 0) AS number_of_drama_movies,
    COALESCE(SUM(CASE WHEN c.name = 'Travel' THEN 1 ELSE 0 END), 0) AS number_of_travel_movies,
    COALESCE(SUM(CASE WHEN c.name = 'Documentary' THEN 1 ELSE 0 END), 0) AS number_of_documentary_movies
FROM public.film AS f
LEFT JOIN public.film_category AS fc
    ON fc.film_id = f.film_id
LEFT JOIN public.category AS c
    ON c.category_id = fc.category_id
GROUP BY
    f.release_year
ORDER BY
    f.release_year DESC;

/*Part 2. Show which three employees generated the most revenue in 2017*/
/*CTE solution
 * I would use CTE solution or JOIN solution
 * */
/*
JOIN types used:
- INNER JOIN public.staff: only payments linked to existing staff are included
- INNER JOIN public.store: only staff linked to existing stores are included
- INNER JOIN public.address: only stores with valid addresses are included
- LEFT JOIN last_payment_per_staff: keeps top revenue staff even if later enrichment fails


- INNER JOIN removes orphaned rows and ensures referential consistency.
- LEFT JOIN preserves aggregated revenue rows when attaching the "last store" information.
*/
WITH payments_2017 AS (
    SELECT
        p.payment_id,
        p.staff_id,
        p.amount,
        p.payment_date
    FROM public.payment AS p
    WHERE p.payment_date >= DATE '2017-01-01'
      AND p.payment_date < DATE '2018-01-01'
),
revenue_per_staff AS (
    SELECT
        p.staff_id,
        SUM(p.amount) AS total_revenue
    FROM payments_2017 AS p
    GROUP BY p.staff_id
),
last_payment_date_per_staff AS (
    SELECT
        p.staff_id,
        MAX(p.payment_date) AS last_payment_date
    FROM payments_2017 AS p
    GROUP BY p.staff_id
),
last_payment_per_staff AS (
    SELECT
        p.staff_id,
        MAX(p.payment_id) AS last_payment_id
    FROM payments_2017 AS p
    INNER JOIN last_payment_date_per_staff AS lpd
        ON lpd.staff_id = p.staff_id
       AND lpd.last_payment_date = p.payment_date
    GROUP BY p.staff_id
)
SELECT
    stf.first_name,
    stf.last_name,
    CONCAT_WS(', ', a.address, a.address2) AS last_store_address,
    rps.total_revenue
FROM revenue_per_staff AS rps
INNER JOIN public.staff AS stf
    ON stf.staff_id = rps.staff_id
LEFT JOIN last_payment_per_staff AS lpp
    ON lpp.staff_id = rps.staff_id
LEFT JOIN public.payment AS p_last
    ON p_last.payment_id = lpp.last_payment_id
LEFT JOIN public.staff AS stf_last
    ON stf_last.staff_id = p_last.staff_id
LEFT JOIN public.store AS s
    ON s.store_id = stf_last.store_id
LEFT JOIN public.address AS a
    ON a.address_id = s.address_id
ORDER BY
    rps.total_revenue DESC,
    stf.last_name ASC,
    stf.first_name ASC
LIMIT 3;


/*

JOIN types used:
- INNER JOIN public.staff in the main query: keeps only existing employees
- Correlated subqueries are used to calculate revenue and determine last store

How it affects the result:
- Main query returns staff members who have at least one payment in 2017.
- Correlated subqueries calculate the metrics for each staff member separately.
*/
SELECT
    stf.first_name,
    stf.last_name,
    (
        SELECT CONCAT_WS(', ', a.address, a.address2)
        FROM public.payment AS p
        INNER JOIN public.staff AS stf2
            ON stf2.staff_id = p.staff_id
        INNER JOIN public.store AS s
            ON s.store_id = stf2.store_id
        INNER JOIN public.address AS a
            ON a.address_id = s.address_id
        WHERE p.staff_id = stf.staff_id
          AND p.payment_date >= DATE '2017-01-01'
          AND p.payment_date < DATE '2018-01-01'
          AND p.payment_id = (
              SELECT MAX(p2.payment_id)
              FROM public.payment AS p2
              WHERE p2.staff_id = stf.staff_id
                AND p2.payment_date = (
                    SELECT MAX(p3.payment_date)
                    FROM public.payment AS p3
                    WHERE p3.staff_id = stf.staff_id
                      AND p3.payment_date >= DATE '2017-01-01'
                      AND p3.payment_date < DATE '2018-01-01'
                )
          )
    ) AS last_store_address,
    (
        SELECT SUM(p.amount)
        FROM public.payment AS p
        WHERE p.staff_id = stf.staff_id
          AND p.payment_date >= DATE '2017-01-01'
          AND p.payment_date < DATE '2018-01-01'
    ) AS total_revenue
FROM public.staff AS stf
WHERE EXISTS (
    SELECT 1
    FROM public.payment AS p
    WHERE p.staff_id = stf.staff_id
      AND p.payment_date >= DATE '2017-01-01'
      AND p.payment_date < DATE '2018-01-01'
)
ORDER BY
    total_revenue DESC,
    stf.last_name ASC,
    stf.first_name ASC
LIMIT 3;

/*

JOIN types used:
- INNER JOIN public.staff: only valid staff linked to payments are counted
- LEFT JOIN derived table with last payment data: keeps all revenue rows
- LEFT JOIN public.store and public.address: allows store enrichment without dropping rows

How JOIN types affect the result:
- INNER JOIN ensures only staff with payments in 2017 are aggregated.
- LEFT JOIN preserves staff revenue rows while adding optional last-store details.
*/
SELECT
    stf.first_name,
    stf.last_name,
    CONCAT_WS(', ', a.address, a.address2) AS last_store_address,
    revenue_data.total_revenue
FROM (
    SELECT
        p.staff_id,
        SUM(p.amount) AS total_revenue
    FROM public.payment AS p
    WHERE p.payment_date >= DATE '2017-01-01'
      AND p.payment_date < DATE '2018-01-01'
    GROUP BY p.staff_id
) AS revenue_data
INNER JOIN public.staff AS stf
    ON stf.staff_id = revenue_data.staff_id
LEFT JOIN (
    SELECT
        p.staff_id,
        MAX(p.payment_id) AS last_payment_id
    FROM public.payment AS p
    INNER JOIN (
        SELECT
            p2.staff_id,
            MAX(p2.payment_date) AS last_payment_date
        FROM public.payment AS p2
        WHERE p2.payment_date >= DATE '2017-01-01'
          AND p2.payment_date < DATE '2018-01-01'
        GROUP BY p2.staff_id
    ) AS max_dates
        ON max_dates.staff_id = p.staff_id
       AND max_dates.last_payment_date = p.payment_date
    WHERE p.payment_date >= DATE '2017-01-01'
      AND p.payment_date < DATE '2018-01-01'
    GROUP BY p.staff_id
) AS last_payment_data
    ON last_payment_data.staff_id = revenue_data.staff_id
LEFT JOIN public.payment AS p_last
    ON p_last.payment_id = last_payment_data.last_payment_id
LEFT JOIN public.staff AS stf_last
    ON stf_last.staff_id = p_last.staff_id
LEFT JOIN public.store AS s
    ON s.store_id = stf_last.store_id
LEFT JOIN public.address AS a
    ON a.address_id = s.address_id
ORDER BY
    revenue_data.total_revenue DESC,
    stf.last_name ASC,
    stf.first_name ASC
LIMIT 3;

/* Show which 5 movies were rented more than others, and what's the expected age of the audience for these movies?
 * I would use CTE solution
 * */

/*

JOIN types used:
- INNER JOIN public.inventory: keeps only rentals linked to existing inventory items
- INNER JOIN public.film: keeps only rentals linked to existing films

How JOIN types affect the result:
- Only films that were actually rented are included.
- Films without rentals are excluded, which matches the task.
*/
WITH rental_counts AS (
    SELECT
        f.film_id,
        f.title,
        f.rating,
        COUNT(r.rental_id) AS number_of_rentals
    FROM public.rental AS r
    INNER JOIN public.inventory AS i
        ON i.inventory_id = r.inventory_id
    INNER JOIN public.film AS f
        ON f.film_id = i.film_id
    GROUP BY
        f.film_id,
        f.title,
        f.rating
)
SELECT
    rc.title,
    rc.number_of_rentals,
    rc.rating,
    CASE
        WHEN rc.rating = 'G' THEN 'All ages'
        WHEN rc.rating = 'PG' THEN 'Parental guidance suggested'
        WHEN rc.rating = 'PG-13' THEN '13+'
        WHEN rc.rating = 'R' THEN '17+ (under 17 with accompanying parent or adult guardian)'
        WHEN rc.rating = 'NC-17' THEN '17+ only'
        ELSE 'Unknown'
    END AS expected_audience_age
FROM rental_counts AS rc
ORDER BY
    rc.number_of_rentals DESC,
    rc.title ASC
LIMIT 5;


/*

JOIN types used:
- INNER JOIN public.inventory in correlated subquery
- INNER JOIN public.rental in correlated subquery

How it affects the result:
- Main query iterates over films.
- Correlated subquery counts how many rentals belong to each film.
- Only films with at least one rental are included.
*/
SELECT
    f.title,
    (
        SELECT COUNT(r.rental_id)
        FROM public.inventory AS i
        INNER JOIN public.rental AS r
            ON r.inventory_id = i.inventory_id
        WHERE i.film_id = f.film_id
    ) AS number_of_rentals,
    f.rating,
    CASE
        WHEN f.rating = 'G' THEN 'All ages'
        WHEN f.rating = 'PG' THEN 'Parental guidance suggested'
        WHEN f.rating = 'PG-13' THEN '13+'
        WHEN f.rating = 'R' THEN '17+ (under 17 with accompanying parent or adult guardian)'
        WHEN f.rating = 'NC-17' THEN '17+ only'
        ELSE 'Unknown'
    END AS expected_audience_age
FROM public.film AS f
WHERE EXISTS (
    SELECT 1
    FROM public.inventory AS i
    INNER JOIN public.rental AS r
        ON r.inventory_id = i.inventory_id
    WHERE i.film_id = f.film_id
)
ORDER BY
    number_of_rentals DESC,
    f.title ASC
LIMIT 5;

/*

JOIN types used:
- INNER JOIN public.inventory
- INNER JOIN public.rental

How JOIN types affect the result:
- Only films with actual rentals are returned.
- Films without inventory or rentals are excluded.
*/
SELECT
    f.title,
    COUNT(r.rental_id) AS number_of_rentals,
    f.rating,
    CASE
        WHEN f.rating = 'G' THEN 'All ages'
        WHEN f.rating = 'PG' THEN 'Parental guidance suggested'
        WHEN f.rating = 'PG-13' THEN '13+'
        WHEN f.rating = 'R' THEN '17+ (under 17 with accompanying parent or adult guardian)'
        WHEN f.rating = 'NC-17' THEN '17+ only'
        ELSE 'Unknown'
    END AS expected_audience_age
FROM public.film AS f
INNER JOIN public.inventory AS i
    ON i.film_id = f.film_id
INNER JOIN public.rental AS r
    ON r.inventory_id = i.inventory_id
GROUP BY
    f.film_id,
    f.title,
    f.rating
ORDER BY
    number_of_rentals DESC,
    f.title ASC
LIMIT 5;




/*

JOIN types used inside subqueries:
- INNER JOIN public.film_actor
- INNER JOIN public.film

How this affects the result:
- Main query iterates through actors.
- Correlated subquery finds latest release year per actor.
- Actors without films are excluded by WHERE EXISTS.
*/
SELECT
    a.first_name,
    a.last_name,
    (
        SELECT MAX(f.release_year)
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f
            ON f.film_id = fa.film_id
        WHERE fa.actor_id = a.actor_id
    ) AS latest_release_year,
    EXTRACT(YEAR FROM CURRENT_DATE)::int - (
        SELECT MAX(f.release_year)
        FROM public.film_actor AS fa
        INNER JOIN public.film AS f
            ON f.film_id = fa.film_id
        WHERE fa.actor_id = a.actor_id
    ) AS inactivity_gap_years
FROM public.actor AS a
WHERE EXISTS (
    SELECT 1
    FROM public.film_actor AS fa
    WHERE fa.actor_id = a.actor_id
)
ORDER BY
    inactivity_gap_years DESC,
    a.last_name ASC,
    a.first_name ASC;


