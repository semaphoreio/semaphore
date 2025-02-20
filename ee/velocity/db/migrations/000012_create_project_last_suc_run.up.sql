begin;

create table project_last_successful_runs
(
    id                     uuid    not null,
    project_id             uuid    not null,
    organization_id        uuid    not null,
    pipeline_file_name     varchar not null,
    branch_name            varchar not null,
    last_successful_run_at timestamp without time zone not null,
    inserted_at            timestamp without time zone default now() not null,
    updated_at             timestamp without time zone default now() not null,
    constraint plsr_pk
        primary key (id)
);

create unique index plsr_unq_idx
    on project_last_successful_runs (project_id, pipeline_file_name, branch_name);

create index project_id_idx
    on project_last_successful_runs (project_id);
create index organization_id_idx
    on project_last_successful_runs (organization_id);
create index pipeline_file_name_idx
    on project_last_successful_runs (pipeline_file_name);


end;