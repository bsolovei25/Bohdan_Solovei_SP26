--Task2
-- 1. Create the login role with CONNECT only
DROP ROLE IF EXISTS rentaluser;
CREATE USER rentaluser WITH PASSWORD 'rentalpassword';

GRANT CONNECT ON DATABASE dvdrental TO rentaluser;

-- 2. Grant read access to customer only
GRANT SELECT ON TABLE public.customer TO rentaluser;

-- 3. Create group role and add rentaluser
DROP ROLE IF EXISTS rental;
CREATE ROLE rental NOLOGIN;
GRANT rental TO rentaluser;

-- 4. Grant INSERT and UPDATE on rental table to the group role
GRANT INSERT, UPDATE ON TABLE public.rental TO rental;

grant SELECT on table public.rental to rental; 

-- 5. If rental.rental_id uses a sequence, grant sequence usage too
GRANT USAGE, SELECT ON SEQUENCE public.rental_rental_id_seq TO rental;

-- Revoke INSERT from the group role
REVOKE INSERT ON TABLE public.rental FROM rental;




WITH eligible AS (
    SELECT c.customer_id, c.first_name, c.last_name
    FROM public.customer c
    WHERE EXISTS (SELECT 1 FROM public.rental  r WHERE r.customer_id = c.customer_id)
      AND EXISTS (SELECT 1 FROM public.payment p WHERE p.customer_id = c.customer_id)
    ORDER BY c.customer_id
    LIMIT 1
)
SELECT
    'CREATE ROLE client_' ||
    regexp_replace(upper(first_name), '[^A-Z0-9]+', '_', 'g') || '_' ||
    regexp_replace(upper(last_name),  '[^A-Z0-9]+', '_', 'g') ||
    ' LOGIN PASSWORD ''clientpassword'';' AS create_role_sql
FROM eligible;


--scripts for rentaluser to check insert and update operations 


SELECT session_user, current_user;

-- A. Read from customer should succeed
SELECT*
FROM public.customer
limit 10

-- B. Insert should succeed through group role membership
INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
VALUES (CURRENT_TIMESTAMP, 2, 2, CURRENT_TIMESTAMP + INTERVAL '2 day', 1, CURRENT_TIMESTAMP);

-- C. Update 
UPDATE public.rental
SET last_update = CURRENT_TIMESTAMP
WHERE rental_id = (SELECT MAX(rental_id) FROM public.rental);

--Task3

ALTER TABLE public.rental ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;

CREATE POLICY rental_policy
ON public.rental
FOR SELECT
USING (
    customer_id = (
        SELECT c.customer_id
        FROM public.customer c
        WHERE 'client_' || c.first_name || '_' || c.last_name = current_user
    )
);

CREATE POLICY payment_policy
ON public.payment
FOR SELECT
USING (
    customer_id = (
        SELECT c.customer_id
        FROM public.customer c
        WHERE 'client_' || c.first_name || '_' || c.last_name = current_user
    )
);

SELECT current_user;

SELECT customer_id, rental_id, inventory_id, rental_date
FROM public.rental;

SELECT customer_id, payment_id, rental_id, amount, payment_date
FROM public.payment;


SELECT *
FROM public.rental
WHERE customer_id <> (
    SELECT c.customer_id
    FROM public.customer c
    WHERE 'client_' || c.first_name || '_' || c.last_name = current_user
);


SELECT *
FROM public.payment
WHERE customer_id <> (
    SELECT c.customer_id
    FROM public.customer c
    WHERE 'client_' || c.first_name || '_' || c.last_name = current_user
);


