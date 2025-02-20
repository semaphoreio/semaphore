begin;

create table if not exists metrics_dashboards
(
    id              uuid                                      not null,
    name            varchar                                   not null,
    project_id      uuid                                      not null,
    organization_id uuid                                      not null,
    inserted_at     timestamp without time zone default now() not null,
    updated_at      timestamp without time zone default now() not null,
    constraint metrics_dashboards_pk
        primary key (id)
);

create unique index metrics_dashboards_name_project_id_uindex
    on metrics_dashboards (name, project_id);

create table if not exists metrics_dashboard_items
(
    id                   uuid                                                      not null,
    metrics_dashboard_id uuid references metrics_dashboards (id) on delete cascade not null,
    name                 varchar                                                   not null,
    branch_name          varchar                                                   not null,
    pipeline_file_name   varchar                                                   not null,
    settings             jsonb                       default '{}'                  not null,
    inserted_at          timestamp without time zone default now()                 not null,
    updated_at           timestamp without time zone default now()                 not null,
    constraint metrics_dashboard_items_pk
        primary key (id)
);

create index mdi_metrics_dashboard_id_index
    on metrics_dashboard_items (metrics_dashboard_id);

end;