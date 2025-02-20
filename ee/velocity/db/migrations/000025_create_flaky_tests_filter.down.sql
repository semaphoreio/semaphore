begin;
drop index if exists flaky_tests_filters_project_id_index;
drop index if exists flaky_tests_filters_project_id_name_uindex;
drop table if exists flaky_tests_filters;

end;