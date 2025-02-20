BEGIN;

drop index job_summaries_id_uindex;
drop index job_summaries_project_id_pipeline_id_uindex;

drop index pipeline_summaries_id_uindex;
drop index pipeline_summaries_project_id_pipeline_id_uindex;

alter table job_summaries
    drop column id;

alter table pipeline_summaries
    drop column id;


create unique index job_summaries_id_uindex
    on job_summaries (job_id);

create index job_summaries_project_id_pipeline_id_uindex
    on job_summaries (project_id, pipeline_id, job_id);
end;

create unique index pipeline_summaries_id_uindex
    on pipeline_summaries (pipeline_id);

create index pipeline_summaries_project_id_pipeline_id_uindex
    on pipeline_summaries (project_id, pipeline_id);

alter table job_summaries
    add constraint job_summaries_pk
        primary key (job_id);

alter table pipeline_summaries
    add constraint pipeline_summaries_pk
        primary key (pipeline_id);

END;