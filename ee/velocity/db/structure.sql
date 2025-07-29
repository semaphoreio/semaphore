--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.24
-- Dumped by pg_dump version 15.13 (Debian 15.13-0+deb12u1)

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
-- Name: flaky_tests_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flaky_tests_filters (
    id uuid NOT NULL,
    name character varying NOT NULL,
    value character varying NOT NULL,
    project_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: job_summaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_summaries (
    project_id uuid NOT NULL,
    pipeline_id uuid NOT NULL,
    job_id uuid NOT NULL,
    total integer NOT NULL,
    passed integer NOT NULL,
    skipped integer NOT NULL,
    failed integer NOT NULL,
    errors integer NOT NULL,
    disabled integer NOT NULL,
    duration bigint NOT NULL,
    created_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: metrics_dashboard_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metrics_dashboard_items (
    id uuid NOT NULL,
    metrics_dashboard_id uuid NOT NULL,
    name character varying NOT NULL,
    branch_name character varying NOT NULL,
    pipeline_file_name character varying NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    notes text DEFAULT ''::text NOT NULL
);


--
-- Name: metrics_dashboards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metrics_dashboards (
    id uuid NOT NULL,
    name character varying NOT NULL,
    project_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: pipeline_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline_runs (
    pipeline_id uuid NOT NULL,
    project_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    branch_name character varying NOT NULL,
    pipeline_file_name character varying NOT NULL,
    result character varying NOT NULL,
    reason character varying NOT NULL,
    queueing_at timestamp without time zone,
    running_at timestamp without time zone,
    done_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: pipeline_summaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline_summaries (
    project_id uuid NOT NULL,
    pipeline_id uuid NOT NULL,
    total integer NOT NULL,
    passed integer NOT NULL,
    skipped integer NOT NULL,
    failed integer NOT NULL,
    errors integer NOT NULL,
    disabled integer NOT NULL,
    duration bigint NOT NULL,
    created_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: project_last_successful_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_last_successful_runs (
    id uuid NOT NULL,
    project_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    pipeline_file_name character varying NOT NULL,
    branch_name character varying NOT NULL,
    last_successful_run_at timestamp without time zone NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: project_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_metrics (
    project_id uuid NOT NULL,
    pipeline_file_name character varying NOT NULL,
    collected_at date NOT NULL,
    organization_id uuid NOT NULL,
    branch_name character varying NOT NULL,
    metrics jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: project_mttr; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_mttr (
    id uuid NOT NULL,
    project_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    pipeline_file_name character varying NOT NULL,
    branch_name character varying NOT NULL,
    failed_ppl_id uuid NOT NULL,
    failed_at timestamp without time zone NOT NULL,
    passed_ppl_id uuid,
    passed_at timestamp without time zone,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: project_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_settings (
    project_id uuid NOT NULL,
    organization_id uuid,
    cd_branch_name character varying NOT NULL,
    cd_pipeline_file_name character varying NOT NULL,
    ci_branch_name character varying DEFAULT ''::character varying NOT NULL,
    ci_pipeline_file_name character varying DEFAULT ''::character varying NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    dirty boolean NOT NULL
);


--
-- Name: flaky_tests_filters flaky_tests_filters_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flaky_tests_filters
    ADD CONSTRAINT flaky_tests_filters_pk PRIMARY KEY (id);


--
-- Name: job_summaries job_summaries_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_summaries
    ADD CONSTRAINT job_summaries_pk PRIMARY KEY (job_id);


--
-- Name: metrics_dashboard_items metrics_dashboard_items_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metrics_dashboard_items
    ADD CONSTRAINT metrics_dashboard_items_pk PRIMARY KEY (id);


--
-- Name: metrics_dashboards metrics_dashboards_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metrics_dashboards
    ADD CONSTRAINT metrics_dashboards_pk PRIMARY KEY (id);


--
-- Name: pipeline_runs pipeline_runs_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_runs
    ADD CONSTRAINT pipeline_runs_pk PRIMARY KEY (pipeline_id);


--
-- Name: pipeline_summaries pipeline_summaries_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_summaries
    ADD CONSTRAINT pipeline_summaries_pk PRIMARY KEY (pipeline_id);


--
-- Name: project_last_successful_runs plsr_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_last_successful_runs
    ADD CONSTRAINT plsr_pk PRIMARY KEY (id);


--
-- Name: project_metrics project_metrics_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_metrics
    ADD CONSTRAINT project_metrics_pk PRIMARY KEY (project_id, pipeline_file_name, branch_name, collected_at);


--
-- Name: project_mttr project_mttr_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_mttr
    ADD CONSTRAINT project_mttr_pkey PRIMARY KEY (id);


--
-- Name: project_settings ps_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_settings
    ADD CONSTRAINT ps_pk PRIMARY KEY (project_id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: flaky_tests_filters_project_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flaky_tests_filters_project_id_index ON public.flaky_tests_filters USING btree (project_id);


--
-- Name: flaky_tests_filters_project_id_name_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX flaky_tests_filters_project_id_name_uindex ON public.flaky_tests_filters USING btree (project_id, name);


--
-- Name: idx_project_metrics_optimization; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_metrics_optimization ON public.project_metrics USING btree (branch_name, collected_at, project_id);


--
-- Name: job_summaries_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX job_summaries_id_uindex ON public.job_summaries USING btree (job_id);


--
-- Name: job_summaries_project_id_pipeline_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_summaries_project_id_pipeline_id_uindex ON public.job_summaries USING btree (project_id, pipeline_id, job_id);


--
-- Name: mdi_metrics_dashboard_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mdi_metrics_dashboard_id_index ON public.metrics_dashboard_items USING btree (metrics_dashboard_id);


--
-- Name: metrics_dashboards_name_project_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX metrics_dashboards_name_project_id_uindex ON public.metrics_dashboards USING btree (name, project_id);


--
-- Name: mttr_branch_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mttr_branch_name_idx ON public.project_mttr USING btree (branch_name);


--
-- Name: mttr_passed_ppl_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mttr_passed_ppl_id_idx ON public.project_mttr USING btree (passed_ppl_id);


--
-- Name: mttr_pipeline_file_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mttr_pipeline_file_name_idx ON public.project_mttr USING btree (pipeline_file_name);


--
-- Name: mttr_project_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mttr_project_id_idx ON public.project_mttr USING btree (project_id);


--
-- Name: organization_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organization_id_idx ON public.project_last_successful_runs USING btree (organization_id);


--
-- Name: pipeline_file_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pipeline_file_name_idx ON public.project_last_successful_runs USING btree (pipeline_file_name);


--
-- Name: pipeline_run_bid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pipeline_run_bid_idx ON public.pipeline_runs USING btree (branch_id);


--
-- Name: pipeline_run_bname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pipeline_run_bname_idx ON public.pipeline_runs USING btree (branch_name);


--
-- Name: pipeline_run_pfname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pipeline_run_pfname_idx ON public.pipeline_runs USING btree (pipeline_file_name);


--
-- Name: pipeline_run_proj_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pipeline_run_proj_idx ON public.pipeline_runs USING btree (project_id);


--
-- Name: pipeline_run_reason_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pipeline_run_reason_idx ON public.pipeline_runs USING btree (reason);


--
-- Name: pipeline_run_result_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pipeline_run_result_idx ON public.pipeline_runs USING btree (result);


--
-- Name: pipeline_runs_pipeline_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pipeline_runs_pipeline_id_uindex ON public.pipeline_runs USING btree (pipeline_id);


--
-- Name: pipeline_summaries_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pipeline_summaries_id_uindex ON public.pipeline_summaries USING btree (pipeline_id);


--
-- Name: pipeline_summaries_project_id_pipeline_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pipeline_summaries_project_id_pipeline_id_uindex ON public.pipeline_summaries USING btree (project_id, pipeline_id);


--
-- Name: plsr_unq_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX plsr_unq_idx ON public.project_last_successful_runs USING btree (project_id, pipeline_file_name, branch_name);


--
-- Name: project_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_id_idx ON public.project_last_successful_runs USING btree (project_id);


--
-- Name: project_last_runs_project_id_last_run_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX project_last_runs_project_id_last_run_idx ON public.project_last_successful_runs USING btree (project_id, last_successful_run_at DESC);


--
-- Name: project_mttr_unq_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX project_mttr_unq_idx ON public.project_mttr USING btree (project_id, pipeline_file_name, branch_name, failed_ppl_id);


--
-- Name: metrics_dashboard_items metrics_dashboard_items_metrics_dashboard_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metrics_dashboard_items
    ADD CONSTRAINT metrics_dashboard_items_metrics_dashboard_id_fkey FOREIGN KEY (metrics_dashboard_id) REFERENCES public.metrics_dashboards(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.24
-- Dumped by pg_dump version 15.13 (Debian 15.13-0+deb12u1)

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
25	f
\.


--
-- PostgreSQL database dump complete
--

