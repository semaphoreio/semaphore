begin;

create table organization_project_metrics
(
    organization_id uuid                                      not null,
    project_id      uuid                                      not null,
    project_name    varchar                                   not null,
    metrics         jsonb                       default '{}'  not null,

    inserted_at     timestamp without time zone default now() not null,
    updated_at      timestamp without time zone default now() not null,
    constraint organization_project_metrics_pkey
        primary key (organization_id, project_id)
);

create unique index organization_project_metrics_unq_idx
    on organization_project_metrics (organization_id, project_id);


end;