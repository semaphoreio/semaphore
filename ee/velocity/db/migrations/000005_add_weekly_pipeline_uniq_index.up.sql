create unique index weekly_pipeline_metrics_uindex
    on weekly_pipeline_metrics (project_id, branch_id, pipeline_file_name, year, week_of_year);