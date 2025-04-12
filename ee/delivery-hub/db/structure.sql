--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.24
-- Dumped by pg_dump version 15.12 (Debian 15.12-0+deb12u2)

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
-- Name: canvases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.canvases (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    organization_id uuid NOT NULL,
    name character varying(128) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: event_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_sources (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    organization_id uuid NOT NULL,
    canvas_id uuid NOT NULL,
    name character varying(128) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    key bytea NOT NULL
);


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    source_id uuid NOT NULL,
    received_at timestamp without time zone NOT NULL,
    raw jsonb NOT NULL,
    state character varying(64) NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    dirty boolean NOT NULL
);


--
-- Name: stage_connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stage_connections (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    stage_id uuid NOT NULL,
    source_id uuid NOT NULL,
    type character varying(64) NOT NULL
);


--
-- Name: stage_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stage_events (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    stage_id uuid NOT NULL,
    source_id uuid NOT NULL,
    state character varying(64) NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: stages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(128) NOT NULL,
    organization_id uuid NOT NULL,
    canvas_id uuid NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: canvases canvases_organization_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.canvases
    ADD CONSTRAINT canvases_organization_id_name_key UNIQUE (organization_id, name);


--
-- Name: canvases canvases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.canvases
    ADD CONSTRAINT canvases_pkey PRIMARY KEY (id);


--
-- Name: event_sources event_sources_organization_id_canvas_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_sources
    ADD CONSTRAINT event_sources_organization_id_canvas_id_name_key UNIQUE (organization_id, canvas_id, name);


--
-- Name: event_sources event_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_sources
    ADD CONSTRAINT event_sources_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: stage_connections stage_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_connections
    ADD CONSTRAINT stage_connections_pkey PRIMARY KEY (id);


--
-- Name: stage_connections stage_connections_stage_id_source_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_connections
    ADD CONSTRAINT stage_connections_stage_id_source_id_key UNIQUE (stage_id, source_id);


--
-- Name: stage_events stage_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_events
    ADD CONSTRAINT stage_events_pkey PRIMARY KEY (id);


--
-- Name: stage_events stage_events_stage_id_source_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_events
    ADD CONSTRAINT stage_events_stage_id_source_id_key UNIQUE (stage_id, source_id);


--
-- Name: stages stages_organization_id_canvas_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_organization_id_canvas_id_name_key UNIQUE (organization_id, canvas_id, name);


--
-- Name: stages stages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_pkey PRIMARY KEY (id);


--
-- Name: uix_canvases_orgs; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX uix_canvases_orgs ON public.canvases USING btree (organization_id);


--
-- Name: uix_event_sources_canvas; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX uix_event_sources_canvas ON public.event_sources USING btree (canvas_id);


--
-- Name: uix_events_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX uix_events_source ON public.events USING btree (source_id);


--
-- Name: uix_stage_connections_stage; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX uix_stage_connections_stage ON public.stage_connections USING btree (stage_id);


--
-- Name: uix_stage_events_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX uix_stage_events_source ON public.stage_events USING btree (source_id);


--
-- Name: uix_stage_events_stage; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX uix_stage_events_stage ON public.stage_events USING btree (stage_id);


--
-- Name: uix_stages_canvas; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX uix_stages_canvas ON public.stages USING btree (canvas_id);


--
-- Name: event_sources event_sources_canvas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_sources
    ADD CONSTRAINT event_sources_canvas_id_fkey FOREIGN KEY (canvas_id) REFERENCES public.canvases(id);


--
-- Name: events events_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.event_sources(id);


--
-- Name: stage_connections stage_connections_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_connections
    ADD CONSTRAINT stage_connections_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.stages(id);


--
-- Name: stage_events stage_events_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_events
    ADD CONSTRAINT stage_events_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.stages(id);


--
-- Name: stages stages_canvas_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_canvas_id_fkey FOREIGN KEY (canvas_id) REFERENCES public.canvases(id);


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.24
-- Dumped by pg_dump version 15.12 (Debian 15.12-0+deb12u2)

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
20250412191124	f
\.


--
-- PostgreSQL database dump complete
--

