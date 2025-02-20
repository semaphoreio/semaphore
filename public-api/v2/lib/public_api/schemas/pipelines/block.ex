defmodule PublicAPI.Schemas.Pipelines.Block do
  @moduledoc """
  Schema for the response of the pipeline block.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Pipelines.Block",
    type: :object,
    properties: %{
      block_id: %Schema{
        type: :string,
        format: :uuid,
        example: "484e263a-424a-4820-bff0-bba436c54042"
      },
      name: %Schema{
        type: :string
      },
      build_req_id: %Schema{
        type: :string,
        format: :uuid
      },
      state: %Schema{
        type: :string,
        description: "States that describe blocks's execution.
        Normal block state transition looks like:
        INITIALIZING -> WAITING -> RUNNING -> DONE",
        enum: ["WAITING", "RUNNING", "STOPPING", "INITIALIZING", "DONE"]
      },
      result: %OpenApiSpex.Reference{"$ref": "#/components/schemas/Pipelines.Result"},
      result_reason: %Schema{
        type: :string,
        description: "Reasons for result different from PASSED

         FAILED:
          - TEST - one or more of user tests failed
          - MALFORMED - Block failed due to one of next:
                        - missing cmd_file, malformed job_matrix or multiple blocks with same name
          - STUCK  - Block was stuck for some internal reason and then aborted
         STOPPED or CANCELED:
          - USER - terminated on users requests
          - INTERNAL - terminated for internal reasons (probably something was stuck)
          - STRATEGY - terminated based on selected cancelation strategy
          - FAST_FAILING - terminated because something other failed (other block run in parallel)
          - DELETED - terminated because branch was deleted while blocks's build was running
          - TIMEOUT - Block run longer than execution_time_limit and was stopped
          - SKIPPED - Filtered out (not executed because did not satisfy filter conditions)",
        enum: ~w(TEST MALFORMED USER INTERNAL STRATEGY FAST_FAILING DELETED TIMEOUT SKIPPED)
      },
      error_description: %Schema{
        type: :string
      },
      jobs: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          description: "Job started within block",
          properties: %{
            name: %Schema{
              type: :string,
              description: "Job name"
            },
            index: %Schema{
              type: :integer,
              description: "Position in which it is definied in definition file within block"
            },
            job_id: %Schema{
              type: :string,
              format: :uuid,
              description: "Job unique identifier wthin build system"
            },
            status: %Schema{
              type: :string
            },
            result: %Schema{
              type: :string
            }
          }
        }
      }
    }
  })
end
