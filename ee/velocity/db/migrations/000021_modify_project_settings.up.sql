begin;
alter table project_settings
    add ci_branch_name varchar default '' not null;

alter table project_settings
    add ci_pipeline_file_name varchar default '' not null;
end;