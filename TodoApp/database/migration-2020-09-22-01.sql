begin;

alter table comment drop constraint comment_todo_fk;

alter table comment add constraint comment_todo_fk
  foreign key (todo_id) references todo (id)
  on delete cascade;

insert into schema_migrations values ('migration-2020-09-22-01.sql');

commit;
