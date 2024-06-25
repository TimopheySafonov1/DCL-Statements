-- 1. Create a new user with the username "rentaluser" and the password "rentalpassword". Give the user the ability to connect to the database but no other permissions.
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rentaluser') THEN
        CREATE USER rentaluser WITH PASSWORD 'rentalpassword';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE dvdrental TO rentaluser;

-- 2. Grant "rentaluser" SELECT permission for the "customer" table. Сheck to make sure this permission works correctly—write a SQL query to select all customers.
GRANT SELECT ON TABLE customer TO rentaluser;
SET ROLE rentaluser;
SELECT * FROM customer;
RESET ROLE;

-- 3. Create a new user group called "rental" and add "rentaluser" to the group.  
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rental') THEN
        CREATE ROLE rental NOLOGIN;
    END IF;
END
$$;

ALTER GROUP rental ADD USER rentaluser;

-- 4. Grant the "rental" group INSERT and UPDATE permissions for the "rental" table. Insert a new row and update one existing row in the "rental" table under that role. 
GRANT SELECT, INSERT, UPDATE ON TABLE rental TO rental;
GRANT USAGE ON SEQUENCE rental_rental_id_seq TO rental;

SET ROLE rentaluser;
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id) 
VALUES ('2024-06-23', 1, 1, NULL, 1)
ON CONFLICT DO NOTHING;


UPDATE rental SET return_date = '2024-06-25' WHERE rental_id = 32295 AND EXISTS (SELECT 1 FROM rental WHERE rental_id = 32295);
RESET ROLE;

-- 5. Revoke the "rental" group's INSERT permission for the "rental" table. Try to insert new rows into the "rental" table make sure this action is denied.
REVOKE INSERT ON TABLE rental FROM GROUP rental;

SET ROLE rentaluser;
-- This should raise an error
DO $$ 
BEGIN 
    BEGIN
        INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id) 
        VALUES ('2024-06-25', 1, 1, NULL, 1);
    EXCEPTION
        WHEN others THEN
            RAISE NOTICE 'Expected error: %', SQLERRM;
    END;
END 
$$;
RESET ROLE;

-- 6. Create a personalized role for any customer already existing in the dvd_rental database. The name of the role name must be client_{first_name}_{last_name} (omit curly brackets). The customer's payment and rental history must not be empty.
-- Configure that role so that the customer can only access their own data in the "rental" and "payment" tables. Write a query to make sure this user sees only their own data.
DO $$
BEGIN
    IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles WHERE rolname = 'client_LINDA_WILLIAMS') THEN
        CREATE ROLE client_LINDA_WILLIAMS LOGIN PASSWORD '55555';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE dvdrental TO client_LINDA_WILLIAMS;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE rental TO client_LINDA_WILLIAMS;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE payment TO client_LINDA_WILLIAMS;

ALTER TABLE rental ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT * FROM pg_policies WHERE policyname = 'rental_policy') THEN
        CREATE POLICY rental_policy ON rental
        FOR ALL
        USING (customer_id = current_setting('myapp.client_id')::integer);
    END IF;
    
    IF NOT EXISTS (SELECT * FROM pg_policies WHERE policyname = 'payment_policy') THEN
        CREATE POLICY payment_policy ON payment
        FOR ALL
        USING (customer_id = current_setting('myapp.client_id')::integer);
    END IF;
END
$$;

ALTER TABLE rental FORCE ROW LEVEL SECURITY;
ALTER TABLE payment FORCE ROW LEVEL SECURITY;

-- Set the client_id for client_LINDA_WILLIAMS
SET myapp.client_id = '3';

-- Switch to the client's role
SET ROLE client_LINDA_WILLIAMS;

-- Check the data accessible to the client role
SELECT * FROM payment WHERE customer_id = 3;
SELECT * FROM rental WHERE customer_id = 3;

-- Reset to the original role
RESET ROLE;
