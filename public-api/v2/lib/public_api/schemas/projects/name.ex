defmodule PublicAPI.Schemas.Projects.Name do
  @moduledoc """
  Schema for a secret name
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Project.Name",
    type: :string,
    description: "Project name must match the regex",
    example: "my-project",
    minLength: 1,
    pattern: ~r/\A[\w\-\.]+\z/
  })
end
