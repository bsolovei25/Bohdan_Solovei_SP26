CREATE SCHEMA IF NOT EXISTS labs;

DROP TABLE IF EXISTS labs.person;

CREATE TABLE labs.person (
    id integer NOT NULL,
    name varchar(15)
);

INSERT INTO labs.person VALUES
(1, 'Bob'),
(2, 'Alice'),
(3, 'Robert');

SET search_path TO labs;

SHOW search_path;

CREATE EXTENSION IF NOT EXISTS pageinspect;

SELECT p.id, p.name, p.ctid, p.xmin, p.xmax
FROM labs.person p
ORDER BY p.id;

SELECT t_xmin, t_xmax, t_ctid,
       tuple_data_split(
           'labs.person'::regclass,
           t_data,
           t_infomask,
           t_infomask2,
           t_bits
       )
FROM heap_page_items(get_raw_page('labs.person', 0));
 
BEGIN;

INSERT INTO labs.person VALUES (4, 'John');

SELECT p.id, p.name, p.ctid, p.xmin, p.xmax
FROM labs.person p
ORDER BY p.id;

COMMIT;


rollback 
BEGIN;

UPDATE labs.person
SET name = 'Alex'
WHERE id = 2;

SELECT p.id, p.name, p.ctid, p.xmin, p.xmax
FROM labs.person p
ORDER BY p.id;

COMMIT;

BEGIN;

DELETE FROM labs.person
WHERE id = 3;

SELECT p.id, p.name, p.ctid, p.xmin, p.xmax
FROM labs.person p
ORDER BY p.id;

COMMIT;

BEGIN;

INSERT INTO labs.person VALUES (999, 'Test');

SELECT p.id, p.name, p.ctid, p.xmin, p.xmax
FROM labs.person p
ORDER BY p.id;

COMMIT;

BEGIN;

DELETE FROM labs.person
WHERE id = 999;

SELECT p.id, p.name, p.ctid, p.xmin, p.xmax
FROM labs.person p
ORDER BY p.id;

COMMIT;

SELECT t_xmin,
       t_xmax,
       t_ctid,
       tuple_data_split(
           'labs.person'::regclass,
           t_data,
           t_infomask,
           t_infomask2,
           t_bits
       )
FROM heap_page_items(
     get_raw_page('labs.person',0)
);


VACUUM labs.person;

INSERT INTO labs.person
VALUES (5, 'Sarah');

SELECT * FROM labs.person;

VACUUM FULL labs.person;

SELECT t_xmin,
       t_xmax,
       t_ctid,
       tuple_data_split(
           'labs.person'::regclass,
           t_data,
           t_infomask,
           t_infomask2,
           t_bits
       )
FROM heap_page_items(
     get_raw_page('labs.person',0)
);
