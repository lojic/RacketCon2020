begin;

alter table app_user add column email character varying;
alter table app_user add column is_admin boolean;

alter table todo add column priority integer;

insert into schema_migrations values ('migration-2020-09-16-01.sql');

commit;

