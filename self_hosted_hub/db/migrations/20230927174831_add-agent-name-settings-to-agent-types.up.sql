begin;

ALTER TABLE agent_types ADD COLUMN name_assignment_origin text DEFAULT 'ASSIGNMENT_ORIGIN_AGENT';
ALTER TABLE agent_types ADD COLUMN release_name_after integer DEFAULT 0;
ALTER TABLE agent_types ADD COLUMN aws_account text DEFAULT '';
ALTER TABLE agent_types ADD COLUMN aws_role_name_patterns text DEFAULT '';

commit;
