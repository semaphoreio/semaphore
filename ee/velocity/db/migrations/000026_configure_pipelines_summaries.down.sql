begin;
ALTER INDEX public.pipeline_summaries_pk RESET (fillfactor);
ALTER TABLE public.pipeline_summaries RESET (
  autovacuum_vacuum_scale_factor,
  autovacuum_analyze_scale_factor,
  autovacuum_vacuum_threshold,
  autovacuum_analyze_threshold
);
end;