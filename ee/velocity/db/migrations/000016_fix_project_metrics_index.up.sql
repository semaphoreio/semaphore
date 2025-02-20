begin;

-- we don't need an index if we have primary key defined using the same columns
drop index if exists pm_project_id_pipeline_file_name_collected_at_uindex;
    
end;
