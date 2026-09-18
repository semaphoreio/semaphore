begin;
ALTER INDEX public.pipeline_summaries_pk SET (fillfactor = 70);
ALTER TABLE public.pipeline_summaries SET (
  autovacuum_vacuum_scale_factor = 0.02,
  autovacuum_analyze_scale_factor = 0.01,
  autovacuum_vacuum_threshold = 2000,
  autovacuum_analyze_threshold = 2000
);

end;