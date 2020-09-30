dropdb todo-test
createdb todo-test
pg_dump -O --no-acl -s todo | psql todo-test

