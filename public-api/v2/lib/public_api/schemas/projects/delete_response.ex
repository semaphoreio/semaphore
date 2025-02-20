defmodule PublicAPI.Schemas.Projects.DeleteResponse do
  @moduledoc """
  Schema for a secret name
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Projects.DeleteResponse",
    description: "",
    type: :object,
    properties: %{
      project_id: PublicAPI.Schemas.Common.id("Project")
    }
  })
end
