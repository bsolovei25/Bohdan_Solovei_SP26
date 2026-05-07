WITH yearly_channel_sales AS (
    SELECT
        co.country_region,
        t.calendar_year,
        ch.channel_desc,
        SUM(s.amount_sold) AS amount_sold
    FROM sh.sales s
    JOIN sh.times t ON t.time_id = s.time_id
    JOIN sh.customers cu ON cu.cust_id = s.cust_id
    JOIN sh.countries co ON co.country_id = cu.country_id
    JOIN sh.channels ch ON ch.channel_id = s.channel_id
    WHERE t.calendar_year BETWEEN 1999 AND 2001
      AND co.country_region IN ('Americas', 'Asia', 'Europe')
    GROUP BY co.country_region, t.calendar_year, ch.channel_desc
),
calc AS (
    SELECT
        country_region,
        calendar_year,
        channel_desc,
        amount_sold,
        ROUND(
            amount_sold * 100.0 /
            SUM(amount_sold) OVER (
		    PARTITION BY country_region, calendar_year
		    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
			),
            2
        ) AS pct_by_channels
    FROM yearly_channel_sales
)
SELECT
    country_region,
    calendar_year,
    channel_desc,
    amount_sold,
    pct_by_channels AS "% BY CHANNELS",
    LAG(pct_by_channels) OVER (
        PARTITION BY country_region, channel_desc
        ORDER BY calendar_year
    ) AS "% PREVIOUS PERIOD",
    pct_by_channels -
    LAG(pct_by_channels) OVER (
        PARTITION BY country_region, channel_desc
        ORDER BY calendar_year
    ) AS "% DIFF"
FROM calc
ORDER BY country_region, calendar_year, channel_desc;

--task 2


WITH daily_sales AS (
    SELECT
        t.calendar_week_number,
        t.time_id,
        t.day_name,
        SUM(s.amount_sold) AS sales
    FROM sh.sales s
    JOIN sh.times t ON t.time_id = s.time_id
    WHERE t.calendar_year = 1999
      AND t.calendar_week_number BETWEEN 49 AND 51
    GROUP BY
        t.calendar_week_number,
        t.time_id,
        t.day_name
)
SELECT
    calendar_week_number,
    time_id,
    day_name,
    sales,
    SUM(sales) OVER (
        PARTITION BY calendar_week_number
        ORDER BY time_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cum_sum,
    AVG(sales) OVER (
        ORDER BY time_id
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS centered_3_day_avg
FROM daily_sales
ORDER BY time_id;

--Task 3
--ROW example 
SELECT
    t.time_id,
    SUM(s.amount_sold) AS daily_sales,
    SUM(SUM(s.amount_sold)) OVER (
        ORDER BY t.time_id
        ROWS BETWEEN 1 PRECEDING AND CURRENT ROW
    ) AS rows_frame_sum
FROM sh.sales s
JOIN sh.times t ON t.time_id = s.time_id
GROUP BY t.time_id
ORDER BY t.time_id;

-- RANGE exmple 

SELECT
    t.time_id,
    SUM(s.amount_sold) AS daily_sales,
    SUM(SUM(s.amount_sold)) OVER (
        ORDER BY t.time_id
        RANGE BETWEEN INTERVAL '3 days' PRECEDING AND CURRENT ROW
    ) AS range_frame_sum
FROM sh.sales s
JOIN sh.times t ON t.time_id = s.time_id
GROUP BY t.time_id
ORDER BY t.time_id;

--GROUP

WITH channel_sales AS (
    SELECT
        ch.channel_desc,
        p.prod_category,
        SUM(s.amount_sold) AS sales
    FROM sh.sales s
    JOIN sh.channels ch ON ch.channel_id = s.channel_id
    JOIN sh.products p ON p.prod_id = s.prod_id
    GROUP BY ch.channel_desc, p.prod_category
)
SELECT
    channel_desc,
    prod_category,
    sales,
    SUM(sales) OVER (
        ORDER BY channel_desc
        GROUPS BETWEEN 1 PRECEDING AND CURRENT ROW
    ) AS groups_frame_sum
FROM channel_sales
ORDER BY channel_desc, prod_category;