begin;
CREATE INDEX idx_project_metrics_optimization
    ON project_metrics (branch_name, collected_at, project_id);

end;