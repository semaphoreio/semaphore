defmodule PublicAPI.Schemas.Common do
  @moduledoc """
  Schema to use for timestamps in the API.
  """
  defmacro timestamp(title \\ "Timestamp", description \\ "Timestamp in ISO 8601 format") do
    alias OpenApiSpex.Schema

    quote do
      %Schema{
        title: unquote(title),
        description: unquote(description),
        type: :string,
        format: :"date-time"
      }
    end
  end

  defmacro id(resource \\ "ID") do
    alias OpenApiSpex.Schema

    quote do
      %Schema{
        title: unquote(resource) <> ".ID",
        description: "ID of a " <> unquote(resource),
        type: :string,
        format: :uuid,
        example: UUID.uuid4()
      }
    end
  end

  @doc """
  Takes properties of a schema and returns a list of schemas with same properties
  but different required fields.

  Example:
  ```
  > one_of(schema: %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            project_id: %Schema{
              title: "id of the project",
              type: :string,
              format: :uuid,
              example: UUID.uuid4()
            },
            wf_id: %Schema{
              title: "id of a workflow",
              type: :string,
              format: :uuid,
              example: UUID.uuid4()
            }
          }
        },
        combinations: [[:project_id], [:wf_id]])
   > [
                %OpenApiSpex.Schema{
                  type: :object,
                  properties: %{
                    project_id: %OpenApiSpex.Schema{
                      title: "id of the project",
                      type: :string,
                      format: :uuid,
                      example: UUID.uuid4()
                    },
                    wf_id: %OpenApiSpex.Schema{
                      title: "id of a workflow",
                      type: :string,
                      format: :uuid,
                      example: UUID.uuid4()
                    }
                  },
                  required: [:project_id]
                },
                %OpenApiSpex.Schema{
                  type: :object,
                  properties: %{
                    project_id: %OpenApiSpex.Schema{
                      title: "id of the project",
                      type: :string,
                      format: :uuid,
                      example: UUID.uuid4()
                    },
                    wf_id: %OpenApiSpex.Schema{
                      title: "id of a workflow",
                      type: :string,
                      format: :uuid,
                      example: UUID.uuid4()
                    }
                  },
                  required: [:wf_id]
                }
              ]

  """
  defmacro one_of(schema: schema, combinations: possibleRequired) do
    Enum.map(possibleRequired, fn req ->
      quote do
        %{unquote(schema) | required: unquote(req)}
      end
    end)
  end
end
