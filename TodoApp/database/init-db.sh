createdb todo

createdb todo-test

cat initial-migration.sql | psql todo

cat migration-2020-09-16-01.sql | psql todo

cat migration-2020-09-22-01.sql | psql todo

./init-test-db.sh
