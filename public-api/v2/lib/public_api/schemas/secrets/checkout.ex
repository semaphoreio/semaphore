defmodule PublicAPI.Schemas.Secrets.Checkout do
  @moduledoc """
  Schema for the information about the last user of a secret.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Secrets.Checkout",
    description: "Collected information about last usage of the secret",
    type: :object,
    properties: %{
      job_id: PublicAPI.Schemas.Common.id("Job"),
      pipeline_id: PublicAPI.Schemas.Common.id("Pipeline"),
      workflow_id: PublicAPI.Schemas.Common.id("Workflow"),
      hook_id: PublicAPI.Schemas.Common.id("Hook"),
      project_id: PublicAPI.Schemas.Common.id("Project"),
      user_id: PublicAPI.Schemas.Common.id("User")
    },
    nullable: true
  })
end
