begin;
alter table metrics_dashboard_items
    add notes text default '' not null;
end;