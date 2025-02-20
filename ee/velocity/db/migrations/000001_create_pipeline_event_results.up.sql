create table pipeline_event_results
(
    id                 bigserial primary key,
    pipeline_id        uuid                        not null,
    workflow_id        uuid                        not null,
    project_id         uuid                        not null,
    branch_id          uuid                        not null,
    pipeline_file_name varchar                     not null,
    pipeline_name      varchar                     not null,
    running_at         timestamp without time zone,
    done_at            timestamp without time zone not null,
    timestamp          timestamp without time zone not null,
    result             varchar                     not null,
    reason             varchar                     not null,
    state              varchar                     not null
);

begin;

create index per_project_id_branch_id_pipeline_file_name_idx
    on pipeline_event_results using btree (project_id, branch_id, pipeline_file_name);

create unique index pipeline_event_results_pipeline_id_unique_index on pipeline_event_results (pipeline_id);

end;