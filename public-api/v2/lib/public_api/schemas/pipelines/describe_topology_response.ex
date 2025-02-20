defmodule PublicAPI.Schemas.Pipelines.DescribeTopologyResponse do
  @moduledoc """
  Schema for Pipelines.DescribeTopology response.
  """

  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Pipelines.DescribeTopologyResp",
    description: "Block topology description",
    type: :object,
    properties: %{
      blocks: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            name: %Schema{
              type: :string,
              description: "The name of the Block"
            },
            jobs: %Schema{
              type: :array,
              items: %Schema{
                type: :string
              },
              description: "The job names within the Block"
            },
            dependencies: %Schema{
              type: :array,
              items: %Schema{
                type: :string
              },
              description: "List of *block* names, this block depends on.
                              All listed blocks have to transition to done-passed
                              before this block can be scheduled."
            }
          }
        }
      },
      after_pipeline: %Schema{
        type: :object,
        properties: %{
          jobs: %Schema{
            type: :array,
            items: %Schema{
              type: :string,
              description:
                "The job names in after pipeline, empty list means no after_pipeline is present"
            }
          }
        }
      }
    }
  })
end
