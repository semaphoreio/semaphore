begin;

create table project_settings
(
    project_id            uuid    not null,
    organization_id       uuid,
    cd_branch_name        varchar not null,
    cd_pipeline_file_name varchar not null,
    constraint ps_pk primary key (project_id)
);

end;