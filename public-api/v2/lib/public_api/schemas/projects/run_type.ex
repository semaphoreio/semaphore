defmodule PublicAPI.Schemas.Projects.RunType do
  @moduledoc """
  Schema for a run type of a project
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Projects.RunType",
    type: :string,
    enum: ~w(BRANCHES TAGS PULL_REQUESTS FORKED_PULL_REQUESTS)
  })
end
