defmodule PublicAPI.Schemas.Secrets.Name do
  @moduledoc """
  Schema for a secret name
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Secret.Name",
    type: :string,
    description: "Secret name must match the regex",
    example: "my-secret",
    minLength: 1,
    pattern: ~r/^[@: -._a-zA-Z0-9]+$/
  })
end
