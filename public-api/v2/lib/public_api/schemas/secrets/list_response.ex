defmodule PublicAPI.Schemas.Secrets.ListResponse do
  @moduledoc """
  Schema for a secret list response
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Secrets.ListResponse",
    type: :array,
    items: PublicAPI.Schemas.Secrets.Secret.schema()
  })
end
