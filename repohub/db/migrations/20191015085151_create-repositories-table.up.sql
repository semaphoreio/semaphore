begin;

CREATE TABLE repositories (
  id                   uuid DEFAULT uuid_generate_v4() NOT NULL,
  project_id           uuid                            NOT NULL,

  name                 character varying(100),
  owner                character varying(100),
  hook_id              character varying(100),
  private              boolean,
  provider             character varying(100),
  url                  character varying(100),

  created_at           timestamp,
  updated_at           timestamp,

  commit_status        jsonb,
  whitelist            jsonb,
  pipeline_file        character varying(100),
  enable_commit_status boolean,

  PRIMARY KEY (id)
);

CREATE INDEX uix_repositories_project_id ON repositories USING btree (project_id);

commit;
