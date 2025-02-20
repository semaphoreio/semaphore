begin;

ALTER TABLE agent_types ADD requester_id uuid;

commit;
