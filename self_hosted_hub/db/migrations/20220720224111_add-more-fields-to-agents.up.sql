begin;

ALTER TABLE agents ADD last_state_change_at timestamp;
ALTER TABLE agents ADD idle_timeout         int     DEFAULT 0;
ALTER TABLE agents ADD single_job           boolean DEFAULT FALSE;
ALTER TABLE agents ADD disabled_reason      text    DEFAULT '';

commit;
