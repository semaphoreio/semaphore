begin;

create table project_mttr
(
    id                 uuid                                      not null,
    project_id         uuid                                      not null,
    organization_id    uuid                                      not null,
    pipeline_file_name varchar                                   not null,
    branch_name        varchar                                   not null,
    failed_ppl_id      uuid                                      not null,
    failed_at          timestamp without time zone               not null,
    passed_ppl_id      uuid,
    passed_at          timestamp without time zone,
    inserted_at        timestamp without time zone default now() not null,
    updated_at         timestamp without time zone default now() not null,
    constraint project_mttr_pkey primary key (id)
);

create unique index project_mttr_unq_idx
    on project_mttr (project_id, pipeline_file_name, branch_name, failed_ppl_id);

create index mttr_project_id_idx
    on project_mttr (project_id);
create index mttr_branch_name_idx
    on project_mttr (branch_name);
create index mttr_pipeline_file_name_idx
    on project_mttr (pipeline_file_name);
create index mttr_passed_ppl_id_idx
    on project_mttr (passed_ppl_id);
end;