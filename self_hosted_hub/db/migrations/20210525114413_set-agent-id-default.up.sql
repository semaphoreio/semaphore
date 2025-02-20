begin;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

alter table agents alter column id set default uuid_generate_v4();

commit;
