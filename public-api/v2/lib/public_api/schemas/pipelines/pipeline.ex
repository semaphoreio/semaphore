defmodule PublicAPI.Schemas.Pipelines.Pipeline do
  @moduledoc """
  Schema for the response of the Pipelines.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Pipelines.Pipeline",
    type: :object,
    properties: %{
      yaml_file_name: %Schema{
        type: :string,
        example: "semaphore.yml"
      },
      working_directory: %Schema{
        type: :string,
        example: ".semaphore"
      },
      wf_id: PublicAPI.Schemas.Common.id("Workflow"),
      terminated_by: %{PublicAPI.Schemas.Common.User.schema() | nullable: true},
      terminate_request: %Schema{
        type: :string,
        description: " It is empty string if there is no need for termination.
        Otherwise, it contains desired termination action (stop or cancel)",
        example: "stop"
      },
      stopping_at: timestamp(),
      state: %Schema{
        type: :string,
        description: "Pipeline states, the normal flow is
        INITIALIZING -> PENDING -> QUEUING (until older finishes) -> RUNNING -> DONE
        If termination is requested while pipeline is in RUNNING it goes to STOPPING",
        enum: ["INITIALIZING", "PENDING", "QUEUING", "RUNNING", "STOPPING", "DONE"]
      },
      running_at: timestamp(),
      result: %OpenApiSpex.Reference{"$ref": "#/components/schemas/Pipelines.Result"},
      result_reason: %Schema{
        type: :string,
        description: "Describes the result reason if result is not PASSED
         Reasons for result different from PASSED

         FAILED:
          - TEST - one or more of user tests failed
          - MALFORMED - Pipeline failed because YAML definition is malformed
          - STUCK  - Pipeline was stuck for some internal reason and then aborted
         STOPPED or CANCELED:
          - USER - terminated on users requests
          - INTERNAL - terminated for internal reasons (probably something was stuck)
          - STRATEGY - terminated based on selected cancelation strategy
          - FAST_FAILING - terminated because something other failed (in case of multiple subpipelines)
          - DELETED - terminated because branch was deleted while pipeline's build was running
          - TIMEOUT - Pipeline run longer than execution_time_limit and was terminated",
        enum: [
          "TEST",
          "MALFORMED",
          "STUCK",
          "USER",
          "INTERNAL",
          "STRATEGY",
          "FAST_FAILING",
          "DELETED",
          "TIMEOUT"
        ]
      },
      queuing_at: timestamp(),
      project_id: PublicAPI.Schemas.Common.id("Project"),
      org_id: PublicAPI.Schemas.Common.id("Organization"),
      ppl_id: PublicAPI.Schemas.Common.id("Pipeline"),
      pending_at: timestamp(),
      name: %Schema{
        type: :string,
        example: "Pipeline"
      },
      hook_id: %Schema{
        type: :string,
        format: :uuid,
        description: "The id of the hook recieved from VC provider",
        example: "cd7f6162-9b6e-435a-89a7-3968b542e9c7"
      },
      error_description: %Schema{
        type: :string,
        description: " Stores error description when pipeline is MALFORMED",
        example: ""
      },
      done_at: timestamp(),
      created_at: timestamp(),
      commit_sha: %Schema{
        type: :string,
        description: "Git commit sha for which pipeline was scheduled",
        example: "ac3f9796df42db976814e3fee670e11e3fd4b98a"
      },
      branch_name: %Schema{
        type: :string,
        description: "Name of git branch for which pipeline was scheduled",
        example: "main"
      },
      branch_id: %Schema{
        type: :string,
        format: :uuid,
        description: "ID of the branch in the UI",
        example: "a79557f2-dc4e-4807-ba89-601401eb3b1e"
      }
    }
  })
end
