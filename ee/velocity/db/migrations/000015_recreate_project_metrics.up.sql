begin;

drop table if exists project_metrics;

create table project_metrics
(
    project_id             uuid    not null,
    pipeline_file_name     varchar not null,
    collected_at           date    not null,
    organization_id        uuid    not null,
    branch_name            varchar not null,
    metrics            jsonb default '{}' not null,
    constraint project_metrics_pk
        primary key (project_id, pipeline_file_name, branch_name, collected_at)
);

create unique index pm_project_id_pipeline_file_name_collected_at_uindex
    on project_metrics (project_id, pipeline_file_name, collected_at);


end;