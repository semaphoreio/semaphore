# Guard

Service for handling user authentication, user lifecycle management, organizations and git application configuration.

### Development

To start a iex session, for easier code execution:

``` bash
make console.ex
```

Or, you can start a container bash session by running

``` bash
console.bash
```

which has all the app's codebase, so you can later test it by running `iex -S mix run`

NOTE: On the first startup, if the db tables haven't been created yet, you need to set them up before starting the iex session, bt running:

``` bash
make test.ex.setup
```

### Tests:

``` bash
make test.ex [FILE=path_to_the_elixit_test_file.exs]
```
