-- ROW_NUMBER() used to rank customers within each channel and select top 5.
-- Aggregation is done first to compute total sales per customer.
-- Percentage is calculated using total channel sales.

SELECT
    channel_desc,
    cust_last_name,
    cust_first_name,
    TO_CHAR(amount_sold, '9999999999990D00') AS amount_sold,
    TO_CHAR(ROUND(amount_sold / channel_total * 100, 4), '999999990D0000') || ' %' AS sales_percentage
FROM (
    SELECT
        channel_desc,
        cust_last_name,
        cust_first_name,
        amount_sold,
        SUM(amount_sold) OVER (PARTITION BY channel_desc) AS channel_total,
        ROW_NUMBER() OVER (
            PARTITION BY channel_desc
            ORDER BY amount_sold DESC
        ) AS rn
    FROM (
        SELECT
            ch.channel_desc,
            c.cust_last_name,
            c.cust_first_name,
            SUM(s.amount_sold) AS amount_sold
        FROM sh.sales s
        JOIN sh.customers c ON c.cust_id = s.cust_id
        JOIN sh.channels ch ON ch.channel_id = s.channel_id
        GROUP BY ch.channel_desc, c.cust_last_name, c.cust_first_name
    ) x
) y
WHERE rn <= 5
ORDER BY channel_desc, amount_sold DESC;




-- Sales of Photo products in Asia for 2000.
-- Crosstab is used to transform quarter values into q1, q2, q3, q4 columns.

CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT
    product_name,
    TO_CHAR(COALESCE(q1, 0), '9999999990D00') AS q1,
    TO_CHAR(COALESCE(q2, 0), '9999999990D00') AS q2,
    TO_CHAR(COALESCE(q3, 0), '9999999990D00') AS q3,
    TO_CHAR(COALESCE(q4, 0), '9999999990D00') AS q4,
    TO_CHAR(
        COALESCE(q1, 0) + COALESCE(q2, 0) + COALESCE(q3, 0) + COALESCE(q4, 0),
        '9999999990D00'
    ) AS year_sum
FROM crosstab(
    $$
    SELECT
        p.prod_name,
        'q' || t.calendar_quarter_number AS quarter_name,
        SUM(s.amount_sold)
    FROM sh.sales s
    JOIN sh.products p ON p.prod_id = s.prod_id
    JOIN sh.times t ON t.time_id = s.time_id
    JOIN sh.customers c ON c.cust_id = s.cust_id
    JOIN sh.countries co ON co.country_id = c.country_id
    WHERE p.prod_category = 'Photo'
      AND co.country_region = 'Asia'
      AND t.calendar_year = 2000
    GROUP BY p.prod_name, t.calendar_quarter_number
    ORDER BY p.prod_name, quarter_name
    $$,
    $$ VALUES ('q1'), ('q2'), ('q3'), ('q4') $$
) AS ct(product_name TEXT, q1 NUMERIC, q2 NUMERIC, q3 NUMERIC, q4 NUMERIC)
ORDER BY (COALESCE(q1, 0) + COALESCE(q2, 0) + COALESCE(q3, 0) + COALESCE(q4, 0)) DESC;


-- Top 300 customers by total sales for 1998, 1999, and 2001.
-- Ranking is calculated separately for every channel.

SELECT
    channel_desc,
    cust_id,
    cust_last_name,
    cust_first_name,
    TO_CHAR(amount_sold, '9999999999990D00') AS amount_sold
FROM (
    SELECT
        channel_desc,
        cust_id,
        cust_last_name,
        cust_first_name,
        amount_sold,
        ROW_NUMBER() OVER (
            PARTITION BY channel_desc
            ORDER BY amount_sold DESC
        ) AS rn
    FROM (
        SELECT
            ch.channel_desc,
            c.cust_id,
            c.cust_last_name,
            c.cust_first_name,
            SUM(s.amount_sold) AS amount_sold
        FROM sh.sales s
        JOIN sh.customers c ON c.cust_id = s.cust_id
        JOIN sh.channels ch ON ch.channel_id = s.channel_id
        JOIN sh.times t ON t.time_id = s.time_id
        WHERE t.calendar_year IN (1998, 1999, 2001)
        GROUP BY ch.channel_desc, c.cust_id, c.cust_last_name, c.cust_first_name
    ) x
) y
WHERE rn <= 300
ORDER BY channel_desc, amount_sold DESC;


-- Sales report for Jan, Feb, Mar 2000.
-- Conditional aggregation separates Americas and Europe sales into two columns.

SELECT
    t.calendar_month_desc,
    p.prod_category,
    TO_CHAR(SUM(CASE WHEN co.country_region = 'Americas' THEN s.amount_sold ELSE 0 END), '9999999990') AS "Americas SALES",
    TO_CHAR(SUM(CASE WHEN co.country_region = 'Europe' THEN s.amount_sold ELSE 0 END), '9999999990') AS "Europe SALES"
FROM sh.sales s
JOIN sh.products p ON p.prod_id = s.prod_id
JOIN sh.times t ON t.time_id = s.time_id
JOIN sh.customers c ON c.cust_id = s.cust_id
JOIN sh.countries co ON co.country_id = c.country_id
WHERE t.calendar_month_desc IN ('2000-01', '2000-02', '2000-03')
  AND co.country_region IN ('Americas', 'Europe')
GROUP BY t.calendar_month_desc, p.prod_category
ORDER BY t.calendar_month_desc, p.prod_category;