defmodule Front.Models.EnvironmentVariableTest do
  use ExUnit.Case
  alias Front.Models.EnvironmentVariable

  describe ".construct_list" do
    test "it constructs a list of envs from raw data" do
      raw_data =
        InternalApi.Secrethub.Secret.Data.new(
          env_vars: [
            InternalApi.Secrethub.Secret.EnvVar.new(
              name: "AWS_KEY",
              value: "123"
            ),
            InternalApi.Secrethub.Secret.EnvVar.new(
              name: "AWS_SECRET",
              value: "456"
            )
          ]
        )

      vars = EnvironmentVariable.construct_list(raw_data)

      assert Enum.count(vars) == 2

      first = List.first(vars)
      assert first.name == "AWS_KEY"
      assert first.value == "123"

      last = List.last(vars)
      assert last.name == "AWS_SECRET"
      assert last.value == "456"
    end
  end
end
