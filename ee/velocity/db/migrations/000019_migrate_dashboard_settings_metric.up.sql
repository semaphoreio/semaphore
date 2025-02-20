begin;

UPDATE metrics_dashboard_items
SET settings = jsonb_set(settings, '{Metric}', '"METRIC_PERFORMANCE"', false)
WHERE settings ->> 'Metric' ilike 'METRIC_PERFORMANCE%';



UPDATE metrics_dashboard_items
SET settings = jsonb_set(settings, '{Metric}', '"METRIC_FREQUENCY"', false)
WHERE settings ->> 'Metric' ilike 'METRIC_FREQUENCY%';



UPDATE metrics_dashboard_items
SET settings = jsonb_set(settings, '{Metric}', '"METRIC_RELIABILITY"', false)
WHERE settings ->> 'Metric' ilike 'METRIC_RELIABILITY%';

end;