--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.24
-- Dumped by pg_dump version 13.7 (Debian 13.7-0+deb11u1)

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
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


SET default_tablespace = '';

--
-- Name: branch_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.branch_metrics (
    id bigint NOT NULL,
    project_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    pipeline_yml_file character varying NOT NULL,
    pipeline_name character varying NOT NULL,
    latest_pipeline_runs jsonb,
    weekly_metrics jsonb
);


--
-- Name: branch_metrics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.branch_metrics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: branch_metrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.branch_metrics_id_seq OWNED BY public.branch_metrics.id;


--
-- Name: job_summaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_summaries (
    id bigint NOT NULL,
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
-- Name: job_summaries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.job_summaries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: job_summaries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.job_summaries_id_seq OWNED BY public.job_summaries.id;


--
-- Name: pipeline_event_buffer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline_event_buffer (
    id bigint NOT NULL,
    pipeline_id uuid NOT NULL,
    workflow_id uuid NOT NULL,
    project_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    pipeline_file_name character varying NOT NULL,
    pipeline_name character varying NOT NULL,
    running_at timestamp without time zone,
    done_at timestamp without time zone NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    result character varying NOT NULL,
    reason character varying NOT NULL,
    state character varying NOT NULL
);


--
-- Name: pipeline_event_buffer_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pipeline_event_buffer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pipeline_event_buffer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pipeline_event_buffer_id_seq OWNED BY public.pipeline_event_buffer.id;


--
-- Name: pipeline_event_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline_event_results (
    id bigint NOT NULL,
    pipeline_id uuid NOT NULL,
    workflow_id uuid NOT NULL,
    project_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    pipeline_file_name character varying NOT NULL,
    pipeline_name character varying NOT NULL,
    running_at timestamp without time zone,
    done_at timestamp without time zone NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    result character varying NOT NULL,
    reason character varying NOT NULL,
    state character varying NOT NULL
);


--
-- Name: pipeline_event_results_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pipeline_event_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pipeline_event_results_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pipeline_event_results_id_seq OWNED BY public.pipeline_event_results.id;


--
-- Name: pipeline_summaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline_summaries (
    id bigint NOT NULL,
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
-- Name: pipeline_summaries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pipeline_summaries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pipeline_summaries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pipeline_summaries_id_seq OWNED BY public.pipeline_summaries.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    dirty boolean NOT NULL
);


--
-- Name: weekly_pipeline_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.weekly_pipeline_metrics (
    id bigint NOT NULL,
    project_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    pipeline_file_name character varying NOT NULL,
    pipeline_name character varying NOT NULL,
    week_of_year integer NOT NULL,
    year integer NOT NULL,
    average bigint NOT NULL,
    pass_rate numeric(12,2) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    processed_at timestamp without time zone
);


--
-- Name: weekly_pipeline_metrics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.weekly_pipeline_metrics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: weekly_pipeline_metrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.weekly_pipeline_metrics_id_seq OWNED BY public.weekly_pipeline_metrics.id;


--
-- Name: branch_metrics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_metrics ALTER COLUMN id SET DEFAULT nextval('public.branch_metrics_id_seq'::regclass);


--
-- Name: job_summaries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_summaries ALTER COLUMN id SET DEFAULT nextval('public.job_summaries_id_seq'::regclass);


--
-- Name: pipeline_event_buffer id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_event_buffer ALTER COLUMN id SET DEFAULT nextval('public.pipeline_event_buffer_id_seq'::regclass);


--
-- Name: pipeline_event_results id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_event_results ALTER COLUMN id SET DEFAULT nextval('public.pipeline_event_results_id_seq'::regclass);


--
-- Name: pipeline_summaries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_summaries ALTER COLUMN id SET DEFAULT nextval('public.pipeline_summaries_id_seq'::regclass);


--
-- Name: weekly_pipeline_metrics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_pipeline_metrics ALTER COLUMN id SET DEFAULT nextval('public.weekly_pipeline_metrics_id_seq'::regclass);


--
-- Name: branch_metrics branch_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_metrics
    ADD CONSTRAINT branch_metrics_pkey PRIMARY KEY (id);


--
-- Name: job_summaries job_summaries_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_summaries
    ADD CONSTRAINT job_summaries_pk PRIMARY KEY (id);


--
-- Name: pipeline_event_buffer pipeline_event_buffer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_event_buffer
    ADD CONSTRAINT pipeline_event_buffer_pkey PRIMARY KEY (id);


--
-- Name: pipeline_event_results pipeline_event_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_event_results
    ADD CONSTRAINT pipeline_event_results_pkey PRIMARY KEY (id);


--
-- Name: pipeline_summaries pipeline_summaries_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_summaries
    ADD CONSTRAINT pipeline_summaries_pk PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: weekly_pipeline_metrics weekly_pipeline_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_pipeline_metrics
    ADD CONSTRAINT weekly_pipeline_metrics_pkey PRIMARY KEY (id);


--
-- Name: branch_metrics_unique_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX branch_metrics_unique_idx ON public.branch_metrics USING btree (project_id, branch_id, pipeline_yml_file);


--
-- Name: job_summaries_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX job_summaries_id_uindex ON public.job_summaries USING btree (id);


--
-- Name: job_summaries_project_id_pipeline_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX job_summaries_project_id_pipeline_id_uindex ON public.job_summaries USING btree (project_id, pipeline_id, job_id);


--
-- Name: per_project_id_branch_id_pipeline_file_name_buffer_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX per_project_id_branch_id_pipeline_file_name_buffer_idx ON public.pipeline_event_buffer USING btree (project_id, branch_id, pipeline_file_name);


--
-- Name: per_project_id_branch_id_pipeline_file_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX per_project_id_branch_id_pipeline_file_name_idx ON public.pipeline_event_results USING btree (project_id, branch_id, pipeline_file_name);


--
-- Name: pipeline_event_buffer_pipeline_id_unique_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pipeline_event_buffer_pipeline_id_unique_index ON public.pipeline_event_buffer USING btree (pipeline_id);


--
-- Name: pipeline_event_results_pipeline_id_unique_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pipeline_event_results_pipeline_id_unique_index ON public.pipeline_event_results USING btree (pipeline_id);


--
-- Name: pipeline_summaries_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pipeline_summaries_id_uindex ON public.pipeline_summaries USING btree (id);


--
-- Name: pipeline_summaries_project_id_pipeline_id_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pipeline_summaries_project_id_pipeline_id_uindex ON public.pipeline_summaries USING btree (project_id, pipeline_id);


--
-- Name: pm_project_id_branch_id_pipeline_file_name_kind_unique_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pm_project_id_branch_id_pipeline_file_name_kind_unique_idx ON public.weekly_pipeline_metrics USING btree (project_id, branch_id, pipeline_file_name);


--
-- Name: weekly_pipeline_metrics_uindex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX weekly_pipeline_metrics_uindex ON public.weekly_pipeline_metrics USING btree (project_id, branch_id, pipeline_file_name, year, week_of_year);


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.24
-- Dumped by pg_dump version 13.7 (Debian 13.7-0+deb11u1)

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
7	f
\.


--
-- PostgreSQL database dump complete
--

