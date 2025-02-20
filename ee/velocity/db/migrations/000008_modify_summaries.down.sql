
drop index job_summaries_id_uindex;
drop index job_summaries_project_id_pipeline_id_uindex;

drop index pipeline_summaries_id_uindex;
drop index pipeline_summaries_project_id_pipeline_id_uindex;

alter table job_summaries
    drop constraint job_summaries_pk;

alter table pipeline_summaries
    drop constraint pipeline_summaries_pk;

alter table job_summaries
    add column id bigserial;

alter table pipeline_summaries
    add column id bigserial;

 add constraint job_summaries_pk
        primary key (id);

 add constraint pipeline_summaries_pk
        primary key (id);


create unique index job_summaries_id_uindex
    on job_summaries (id);

create unique index job_summaries_project_id_pipeline_id_uindex
    on job_summaries (project_id, pipeline_id, job_id);
end;

create unique index pipeline_summaries_id_uindex
    on pipeline_summaries (id);

create unique index pipeline_summaries_project_id_pipeline_id_uindex
    on pipeline_summaries (project_id, pipeline_id);


