begin;
create index project_last_runs_project_id_last_run_idx
    on project_last_successful_runs (project_id asc, last_successful_run_at desc);

end;