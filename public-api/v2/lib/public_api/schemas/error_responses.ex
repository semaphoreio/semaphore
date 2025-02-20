defmodule PublicAPI.Schemas.ErrorResponses do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  @moduledoc """
  Defines default error responses for the API.
  """

  defmodule Error do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Error",
      type: :object,
      properties: %{
        message: %Schema{
          type: :string
        },
        documentation_url: %Schema{
          type: :string,
          format: :uri,
          example: "https://docs.semaphoreci.com/api/error-codes/bad-request"
        }
      }
    })
  end

  defmodule Validation do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Error.Validation",
      description: "Resource validation failed",
      type: :object,
      properties: %{
        message: %Schema{
          type: :string
        },
        documentation_url: %Schema{
          type: :string,
          format: :uri,
          example: "https://docs.semaphoreci.com/api/error-codes/bad-request"
        },
        errors: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              field: %Schema{
                type: :string
              },
              message: %Schema{
                type: :string
              }
            }
          }
        }
      }
    })
  end
end
