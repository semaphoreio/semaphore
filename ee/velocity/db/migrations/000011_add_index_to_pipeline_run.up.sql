begin;

create index pipeline_run_proj_idx
    on pipeline_runs (project_id);

create index pipeline_run_bid_idx
    on pipeline_runs (branch_id);

create index pipeline_run_bname_idx
    on pipeline_runs (branch_name);

create index pipeline_run_pfname_idx
    on pipeline_runs (pipeline_file_name);

create index pipeline_run_result_idx
    on pipeline_runs (result);

create index pipeline_run_reason_idx
    on pipeline_runs (reason);

end;