defmodule PublicAPI.Schemas.Workflows.Workflow do
  @moduledoc """
  Schema for the response of the Workflows.Describe operation.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Workflows.Workflow",
    type: :object,
    properties: %{
      wf_id: PublicAPI.Schemas.Common.id("Workflow"),
      triggered_by: %Schema{
        type: :string,
        enum: ["HOOK", "SCHEDULE", "API", "MANUAL_RUN"]
      },
      requester_id: PublicAPI.Schemas.Common.id("User"),
      project_id: PublicAPI.Schemas.Common.id("Project"),
      initial_ppl_id: %Schema{
        description: "The ID of the initial pipeline that was ran by this workflow",
        type: :string,
        format: :uuid
      },
      hook_id: PublicAPI.Schemas.Common.id("Hook"),
      created_at: timestamp(),
      commit_sha: %Schema{
        type: :string,
        format: :"sha-1"
      },
      branch_id: PublicAPI.Schemas.Common.id("Branch")
    }
  })
end
