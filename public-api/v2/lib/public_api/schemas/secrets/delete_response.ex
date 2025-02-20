defmodule PublicAPI.Schemas.Secrets.DeleteResponse do
  @moduledoc """
  Schema for a secret name
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Secrets.DeleteResponse",
    description: "",
    type: :object,
    properties: %{
      secret_id: PublicAPI.Schemas.Common.id("Secret")
    }
  })
end
