begin;
alter table project_settings
    drop column ci_branch_name;

alter table project_settings
    drop column ci_pipeline_file_name;
end;