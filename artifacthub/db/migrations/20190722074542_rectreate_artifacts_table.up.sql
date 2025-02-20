begin;

CREATE TABLE artifacts (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    bucket_name text,
    idempotency_token text,
    created timestamp with time zone,
    token uuid DEFAULT uuid_generate_v4() NOT NULL
);

ALTER TABLE ONLY artifacts
    ADD CONSTRAINT artifacts_pkey PRIMARY KEY (id);

CREATE UNIQUE INDEX uix_artifacts_idempotency_token ON artifacts USING btree (idempotency_token);

CREATE UNIQUE INDEX uix_artifacts_token ON artifacts USING btree (token);

commit;
