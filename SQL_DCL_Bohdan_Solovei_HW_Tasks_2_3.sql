
DROP ROLE IF EXISTS rentaluser;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'rentaluser'
    ) THEN
        CREATE USER rentaluser WITH PASSWORD 'rentalpassword';
        RAISE NOTICE 'User rentaluser created';
    ELSE
        RAISE NOTICE 'User rentaluser already exists';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE dvdrental TO rentaluser;


GRANT SELECT ON TABLE public.customer TO rentaluser;


DROP ROLE IF EXISTS rental;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'rental'
    ) THEN
        CREATE ROLE rental NOLOGIN;
        RAISE NOTICE 'Role rental created';
    ELSE
        RAISE NOTICE 'Role rental already exists';
    END IF;
END
$$;
GRANT rental TO rentaluser;

GRANT INSERT, UPDATE ON TABLE public.rental TO rental;

grant SELECT on table public.rental to rental; 


GRANT USAGE, SELECT ON SEQUENCE public.rental_rental_id_seq TO rental;


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





SELECT session_user, current_user;


SELECT*
FROM public.customer
limit 10

INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
VALUES (CURRENT_TIMESTAMP, 2, 2, CURRENT_TIMESTAMP + INTERVAL '2 day', 1, CURRENT_TIMESTAMP);


UPDATE public.rental
SET last_update = CURRENT_TIMESTAMP
WHERE rental_id = (SELECT MAX(rental_id) FROM public.rental);



ALTER TABLE public.rental ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE policyname = 'rental_policy'
          AND tablename = 'rental'
    ) THEN
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
    END IF;
END
$$;


DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
          WHERE tablename = 'payment'
          AND policyname = 'payment_policy'
    ) THEN
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
    END IF;
END
$$;

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


