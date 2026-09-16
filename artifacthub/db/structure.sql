--
-- PostgreSQL database dump
--

\restrict c5DM45G2ju9aacAb9nk8b1G4LEox3vrPxWsL5h4vAx1pK04pXgmRXdmfqA3Vj5s

-- Dumped from database version 9.6.24
-- Dumped by pg_dump version 17.11 (Debian 17.11-0+deb13u1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


SET default_tablespace = '';

--
-- Name: artifacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artifacts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    bucket_name text,
    idempotency_token text,
    created timestamp with time zone,
    last_cleaned_at timestamp without time zone,
    deleted_at timestamp without time zone,
    purge_requested_at timestamp without time zone
);


--
-- Name: retention_policies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.retention_policies (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    artifact_id uuid NOT NULL,
    project_level_policies jsonb,
    workflow_level_policies jsonb,
    job_level_policies jsonb,
    scheduled_for_cleaning_at timestamp without time zone,
    last_cleaned_at timestamp without time zone
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    dirty boolean NOT NULL
);


--
-- Name: artifacts artifacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artifacts
    ADD CONSTRAINT artifacts_pkey PRIMARY KEY (id);


--
-- Name: retention_policies retention_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retention_policies
    ADD CONSTRAINT retention_policies_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: uix_artifacts_idempotency_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uix_artifacts_idempotency_token ON public.artifacts USING btree (idempotency_token);


--
-- Name: uix_retention_policies_artifact_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uix_retention_policies_artifact_id ON public.retention_policies USING btree (artifact_id);


--
-- Name: retention_policies fk_artifact_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retention_policies
    ADD CONSTRAINT fk_artifact_id FOREIGN KEY (artifact_id) REFERENCES public.artifacts(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict c5DM45G2ju9aacAb9nk8b1G4LEox3vrPxWsL5h4vAx1pK04pXgmRXdmfqA3Vj5s

--
-- PostgreSQL database dump
--

\restrict T4xtAcalrQRRg9IXb4g9UfmMhJoHKbh1RlXAkMXCbfPfvxp1s3SkVH0S0PtwfCI

-- Dumped from database version 9.6.24
-- Dumped by pg_dump version 17.11 (Debian 17.11-0+deb13u1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schema_migrations (version, dirty) FROM stdin;
20260916120000	f
\.


--
-- PostgreSQL database dump complete
--

\unrestrict T4xtAcalrQRRg9IXb4g9UfmMhJoHKbh1RlXAkMXCbfPfvxp1s3SkVH0S0PtwfCI

