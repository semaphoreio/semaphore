begin;

create table if not exists flaky_tests_filters
(
    id              uuid                                      not null,
    name            varchar                                   not null,
    value           varchar                                   not null,
    project_id      uuid                                      not null,
    organization_id uuid                                      not null,
    inserted_at     timestamp without time zone default now() not null,
    updated_at      timestamp without time zone default now() not null,
    constraint flaky_tests_filters_pk
        primary key (id)
);

create index  flaky_tests_filters_project_id_index
    on flaky_tests_filters (project_id);

create unique index flaky_tests_filters_project_id_name_uindex
    on flaky_tests_filters (project_id, name);

end;