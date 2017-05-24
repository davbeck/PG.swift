--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.3
-- Dumped by pg_dump version 9.6.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: example; Type: TABLE; Schema: public;
--

CREATE TABLE example (
    e_uuid uuid DEFAULT uuid_generate_v4(),
    e_text text,
    e_varchar_100 character varying(100),
    e_varchar character varying,
    e_int2 smallint,
    e_int4 integer,
    e_int8 bigint,
    e_oid oid,
    e_char character(1),
    e_date date,
    e_timestamp timestamp without time zone,
    e_timestamp_zoned timestamp with time zone,
    id integer NOT NULL,
    e_point point,
    e_circle circle,
    e_json json,
    e_jsonb jsonb,
    e_text_array text[],
    e_int_array integer[]
);

--
-- Name: example_id_seq; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE example_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: example_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE example_id_seq OWNED BY example.id;


--
-- Name: example id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY example ALTER COLUMN id SET DEFAULT nextval('example_id_seq'::regclass);


--
-- Data for Name: example; Type: TABLE DATA; Schema: public;
--

COPY example (e_uuid, e_text, e_varchar_100, e_varchar, e_int2, e_int4, e_int8, e_oid, e_char, e_date, e_timestamp, e_timestamp_zoned, id, e_point, e_circle, e_json, e_jsonb, e_text_array, e_int_array) FROM stdin;
a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	Hello World	Hello World	Hello World	100	65635	4294967395	65635	H	2017-05-22	2017-05-22 15:12:55.33301	2017-05-22 15:12:55.33301-07	1	\N	\N	\N	\N	\N	\N
b7ab0ffc-9367-4fe6-a737-2fa4e5de58d3	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	2	\N	\N	\N	\N	\N	\N
\.


--
-- Name: example_id_seq; Type: SEQUENCE SET; Schema: public;
--

SELECT pg_catalog.setval('example_id_seq', 2, true);


--
-- Name: example example_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY example
    ADD CONSTRAINT example_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

