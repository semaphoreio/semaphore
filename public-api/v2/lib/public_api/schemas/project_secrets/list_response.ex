defmodule PublicAPI.Schemas.ProjectSecrets.ListResponse do
  @moduledoc """
  Schema for a secret list response
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "ProjectSecrets.ListResponse",
    type: :array,
    items: PublicAPI.Schemas.ProjectSecrets.Secret.schema()
  })
end
