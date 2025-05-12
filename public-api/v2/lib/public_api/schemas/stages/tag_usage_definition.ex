defmodule PublicAPI.Schemas.Stages.TagUsageDefinition do
  @moduledoc """
  Schema for a stage's tag usage definition
  """
  alias ElixirLS.LanguageServer.Plugins.Ecto.Schema
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Stages.TagUsageDefinition",
    type: :object,
    required: [:from, :tags],
    properties: %{
      from: %Schema{
        type: :array,
        description: "The connection names from where we define our tags",
        items: %Schema{
          type: :string
        }
      },
      tags: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          required: [:name, :valueFrom],
          description: "The list of tags to use for our stage",
          properties: %{
            name: %Schema{
              type: :string,
              description: "The name of the tag"
            },
            valueFrom: %Schema{
              type: :string,
              description: "The expression that defines the value of the tag"
            }
          }
        }
      }
    }
  })
end
