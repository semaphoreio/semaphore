begin;

CREATE TABLE retention_policies (
  id uuid DEFAULT uuid_generate_v4() NOT NULL,
  artifact_id uuid NOT NULL,

  project_level_policies  jsonb,
  workflow_level_policies jsonb,
  job_level_policies      jsonb,

  PRIMARY KEY(id),
  CONSTRAINT fk_artifact_id FOREIGN KEY(artifact_id) REFERENCES artifacts(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX uix_retention_policies_artifact_id ON retention_policies USING btree (artifact_id);

commit;