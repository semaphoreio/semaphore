begin;

create table pipeline_runs
(
    pipeline_id uuid    not null
        constraint pipeline_runs_pk
            primary key,
    project_id          uuid not null,
    branch_id           uuid not null,
    branch_name         varchar not null,
    pipeline_file_name  varchar not null,
    result              varchar not null,
    reason              varchar not null,
    queueing_at         timestamp without time zone,
    running_at          timestamp without time zone,
    done_at             timestamp without time zone,
    created_at          timestamp without time zone,
    updated_at          timestamp without time zone
);

create unique index pipeline_runs_pipeline_id_uindex
    on pipeline_runs (pipeline_id);


create table project_metrics
(
    project_id             uuid    not null,
    pipeline_file_name     varchar not null,
    collected_at           date    not null,
    organization_id        uuid    not null,
    all_metrics            jsonb default '{}' not null,
    default_branch_metrics jsonb default '{}' not null,
    constraint project_metrics_pk
        primary key (project_id, pipeline_file_name, collected_at)
);

create unique index project_metrics_project_id_pipeline_file_name_collected_at_uindex
    on project_metrics (project_id, pipeline_file_name, collected_at);


end;