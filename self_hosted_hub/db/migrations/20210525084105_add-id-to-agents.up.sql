begin;

ALTER TABLE agents DROP CONSTRAINT agents_pkey;
ALTER TABLE agents ADD COLUMN id uuid;
ALTER TABLE agents ADD PRIMARY KEY (id);

commit;
