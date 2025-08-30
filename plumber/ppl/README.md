# Ppl

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ppl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:ppl, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ppl](https://hexdocs.pm/ppl).

# Run tests

To run unit tests execute:
```
make postgres.run USER=root
make rabbitmq.run USER=root
make repo_proxy_ref.run USER=root
make unit-test
```

To run integration tests execute:
```
make postgres.run USER=root
make rabbitmq.run USER=root
make repo_proxy_ref.run USER=root
make task_ref.run USER=root
make integration-test
```

To run single test in console:
```
make console
MIX_ENV=test mix test <test-file-path>:<test-case-line-number>
```

## Development setup tips

Error after running `make postgres.run USER=root`:

```
** (Mix) The database for Ppl.EctoRepo couldn't be created: FATAL 28P01 (invalid_password): password authentication failed for user "postgres"
```

Make sure you are not running regular postgres as a service: `sudo service postgresql stop`.

---

Error after running `make unit-test` for the first time:

```
** (File.Error) could not make directory (with -p) "/home/dev/pipelines/ppl/_build/test/lib/sys2app/.mix": no such file or directory
```

Run the command with root for the first time: `make unit-test USER=root`.

