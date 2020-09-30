begin;

create table app_user (
  id            bigserial primary key,
  created_at    timestamptz not null default current_timestamp,
  password_hash character varying not null,
  password_salt character varying not null,
  username      character varying not null
);

create unique index user_username_idx on app_user (username);

create table todo (
  id           bigserial primary key,
  user_id      bigint,
  completed_at timestamptz,
  created_at   timestamptz not null default current_timestamp,
  description  character varying,
  title        character varying not null
);

alter table todo add constraint todo_user_fk
  foreign key (user_id) references app_user (id);

create index todo_user_id_idx on todo (user_id);

create table comment (
  id          bigserial primary key,
  user_id     bigint,
  todo_id     bigint,
  created_at  timestamptz default current_timestamp,
  description character varying
);

alter table comment add constraint comment_user_fk
  foreign key (user_id) references app_user (id);

create index comment_user_id_idx on comment (user_id);

alter table comment add constraint comment_todo_fk
  foreign key (todo_id) references todo (id) on delete cascade;

create index comment_todo_id_idx on comment (todo_id);

create table schema_migrations (
  version text primary key
);

insert into schema_migrations values ('initial-migration.sql');

commit;
