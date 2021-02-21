# Todo App
To run the Todo web application:

1. Rename `TodoApp/axio/example-axio-env.rkt` file to `TodoApp/axio/axio-env.rkt`, and edit the appropriate values to match your environment.
2. Create a user in the database (see `main` in `TodoApp/models/user.rkt`)
2. `cd TodoApp/`
3. `racket todo-app.rkt 1`

You will need to put a web server, such as nginx, in front of the web app to serve static files such as the .css files; otherwise, you will have no styling.
