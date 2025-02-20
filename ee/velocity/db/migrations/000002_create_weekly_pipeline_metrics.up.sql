begin;
create table weekly_pipeline_metrics
(
    id                 bigserial primary key,
    project_id         uuid                                      not null,
    branch_id          uuid                                      not null,
    pipeline_file_name varchar                                   not null,
    pipeline_name      varchar                                   not null,
    week_of_year       int                                       not null,
    year               int                                       not null,
    average            bigint                                    not null,
    pass_rate          decimal(12, 2)                            not null,
    created_at         timestamp without time zone default NOW() not null,
    processed_at       timestamp without time zone
);

create index pm_project_id_branch_id_pipeline_file_name_kind_unique_idx
    on weekly_pipeline_metrics (project_id, branch_id, pipeline_file_name);

end;