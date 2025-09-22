defmodule EphemeralEnvironmentTypesTest do
  use EphemeralEnvironments.RepoCase

  test "list all ephemeral environment types" do
    result = Repo.query!("SELECT * FROM ephemeral_environment_types")

    IO.puts("Columns: #{inspect(result.columns)}")
    IO.puts("Rows: #{inspect(result.rows)}")

    assert is_list(result.rows)
  end
end
