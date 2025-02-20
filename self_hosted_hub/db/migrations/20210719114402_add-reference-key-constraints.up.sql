begin;

ALTER TABLE agents ADD FOREIGN KEY(organization_id, agent_type_name) REFERENCES agent_types(organization_id, name);

commit;
