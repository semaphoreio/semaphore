begin;
create table pipeline_summaries
(
    id          bigserial
        constraint pipeline_summaries_pk
            primary key,
    project_id  uuid                        not null,
    pipeline_id uuid                        not null,
    total       int                         not null,
    passed      int                         not null,
    skipped     int                         not null,
    failed      int                         not null,
    errors      int                         not null,
    disabled    int                         not null,
    duration    bigint                      not null
);

create unique index pipeline_summaries_id_uindex
    on pipeline_summaries (id);

create unique index pipeline_summaries_project_id_pipeline_id_uindex
    on pipeline_summaries (project_id, pipeline_id);


create table job_summaries
(
    id          bigserial
        constraint job_summaries_pk
            primary key,
    project_id  uuid                        not null,
    pipeline_id uuid                        not null,
    job_id      uuid                        not null,
    total       int                         not null,
    passed      int                         not null,
    skipped     int                         not null,
    failed      int                         not null,
    errors      int                         not null,
    disabled    int                         not null,
    duration    bigint                      not null
);

create unique index job_summaries_id_uindex
    on job_summaries (id);

create unique index job_summaries_project_id_pipeline_id_uindex
    on job_summaries (project_id, pipeline_id, job_id);
end;
