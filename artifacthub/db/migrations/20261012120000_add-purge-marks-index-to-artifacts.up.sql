begin;

CREATE INDEX IF NOT EXISTS idx_artifacts_purge_marks ON artifacts (deleted_at, purge_requested_at)
    WHERE deleted_at IS NOT NULL OR purge_requested_at IS NOT NULL;

commit;
