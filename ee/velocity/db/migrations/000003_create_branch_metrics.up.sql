begin;
create table branch_metrics
(
    id                           bigserial primary key,
    project_id                   uuid not null,
    branch_id                    uuid not null,
    pipeline_yml_file            varchar not null,
    pipeline_name                varchar not null,
    latest_pipeline_runs         jsonb,
    weekly_metrics               jsonb
);

create unique index branch_metrics_unique_idx
    on branch_metrics (project_id, branch_id, pipeline_yml_file);

end;