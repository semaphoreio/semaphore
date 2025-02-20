defmodule PublicAPI.SpecHelpers.Pagination do
  require OpenApiSpex

  @moduledoc """
  Helper functions for pagination for OpenAPI parameter specs,
  add params to your operation like this:

  ```
  use PublicAPI.SpecHelpers
  def open_api_operation(_) do
    %Operation{
      ...
      parameters:
        [
          Operation.parameter(
            :project_id,
            :query,
            %Schema{type: :string, format: :uuid},
            "The id of the project",
            required: true
          )
          ] ++ Pagination.offset_params()
          ...
          }
  """

  defmacro offset_params do
    quote do
      [
        OpenApiSpex.Operation.parameter(
          :page,
          :query,
          %OpenApiSpex.Schema{
            type: :integer,
            default: 1
          },
          "Page offset"
        ),
        OpenApiSpex.Operation.parameter(
          :page_size,
          :query,
          PublicAPI.Schemas.PageSize,
          "Page size"
        )
      ]
    end
  end

  defmacro token_params do
    quote do
      [
        OpenApiSpex.Operation.parameter(
          :page_token,
          :query,
          %OpenApiSpex.Schema{
            type: :string,
            default: ""
          },
          "Starting point for listing, if you are fetching first page leave it empty"
        ),
        OpenApiSpex.Operation.parameter(
          :page_size,
          :query,
          PublicAPI.Schemas.PageSize.schema(),
          "Page size"
        )
      ]
    end
  end

  defmacro token_links(operation_id) do
    quote do
      %OpenApiSpex.Link{
        operationId: unquote(operation_id),
        description: "Links to navigate through the paginated results",
        parameters: %{
          "next" => "",
          "prev" => ""
        }
      }
    end
  end
end
