--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.24
-- Dumped by pg_dump version 15.10 (Debian 15.10-0+deb12u1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
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
-- Name: agent_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_types (
    organization_id uuid NOT NULL,
    name character varying(100) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    token_hash character varying(250),
    requester_id uuid,
    name_assignment_origin text DEFAULT 'ASSIGNMENT_ORIGIN_AGENT'::text,
    release_name_after integer DEFAULT 0,
    aws_account text DEFAULT ''::text,
    aws_role_name_patterns text DEFAULT ''::text
);


--
-- Name: agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agents (
    organization_id uuid NOT NULL,
    agent_type_name character varying(100) NOT NULL,
    name character varying(100) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    last_sync_at timestamp without time zone,
    token_hash character varying(250),
    last_sync_state character varying,
    last_sync_job_id character varying,
    assigned_job_id uuid,
    job_assigned_at timestamp without time zone,
    job_stop_requested_at timestamp without time zone,
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    version text DEFAULT ''::text,
    os text DEFAULT ''::text,
    arch text DEFAULT ''::text,
    pid integer DEFAULT 0,
    hostname text DEFAULT ''::text,
    user_agent text DEFAULT ''::text,
    ip_address text DEFAULT ''::text,
    disabled_at timestamp without time zone,
    last_state_change_at timestamp without time zone,
    idle_timeout integer DEFAULT 0,
    single_job boolean DEFAULT false,
    interrupted_at timestamp without time zone,
    interruption_grace_period integer DEFAULT 0,
    state text DEFAULT 'registered'::text,
    disconnected_at timestamp without time zone
);


--
-- Name: occupation_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.occupation_requests (
    organization_id uuid NOT NULL,
    agent_type_name character varying(100) NOT NULL,
    job_id uuid NOT NULL,
    created_at timestamp without time zone
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    dirty boolean NOT NULL
);


--
-- Name: agent_types agent_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_types
    ADD CONSTRAINT agent_types_pkey PRIMARY KEY (organization_id, name);


--
-- Name: agents agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_pkey PRIMARY KEY (id);


--
-- Name: occupation_requests occupation_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.occupation_requests
    ADD CONSTRAINT occupation_requests_pkey PRIMARY KEY (organization_id, agent_type_name, job_id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: uix_agent_name_in_orgs; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uix_agent_name_in_orgs ON public.agents USING btree (organization_id, name);


--
-- Name: uix_agent_orgs; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX uix_agent_orgs ON public.agents USING btree (organization_id, agent_type_name);


--
-- Name: uix_agent_types_orgs; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX uix_agent_types_orgs ON public.agent_types USING btree (organization_id);


--
-- Name: uix_occupation_req_org_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX uix_occupation_req_org_type ON public.agents USING btree (organization_id, agent_type_name);


--
-- Name: agents agents_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_organization_id_fkey FOREIGN KEY (organization_id, agent_type_name) REFERENCES public.agent_types(organization_id, name);


--
-- Name: occupation_requests occupation_requests_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.occupation_requests
    ADD CONSTRAINT occupation_requests_organization_id_fkey FOREIGN KEY (organization_id, agent_type_name) REFERENCES public.agent_types(organization_id, name);


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.24
-- Dumped by pg_dump version 15.10 (Debian 15.10-0+deb12u1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
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
20230930195246	f
\.


--
-- PostgreSQL database dump complete
--

