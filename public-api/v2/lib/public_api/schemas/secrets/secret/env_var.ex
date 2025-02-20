defmodule PublicAPI.Schemas.Secrets.Secret.EnvVar do
  @moduledoc """
  Schema for a secret env var
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    type: :object,
    title: "Secrets.Secret.EnvVar",
    description: "EnvVar",
    properties: %{
      name: %Schema{
        type: :string,
        minLength: 1,
        example: "MY_SECRET",
        description: "Name of the environment variable"
      },
      value: %Schema{
        type: :string,
        minLength: 1,
        example: "secret",
        description: "Value of the environment variable"
      }
    },
    required: [:name, :value]
  })
end
