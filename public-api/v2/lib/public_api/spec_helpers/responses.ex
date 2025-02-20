defmodule PublicAPI.SpecHelpers.Responses do
  require OpenApiSpex
  alias OpenApiSpex.Operation

  @moduledoc """
  This macro adds default error responses to the operation responses.
  """

  defmacro with_errors(specific) do
    quote do
      Map.merge(
        %{
          400 =>
            Operation.response(
              "Bad Request",
              "application/json",
              PublicAPI.Schemas.ErrorResponses.Error
            ),
          401 =>
            Operation.response(
              "Unauthorized",
              "application/json",
              PublicAPI.Schemas.ErrorResponses.Error
            ),
          404 =>
            Operation.response(
              "Not Found",
              "application/json",
              PublicAPI.Schemas.ErrorResponses.Error
            ),
          500 =>
            Operation.response(
              "Internal Server Error",
              "application/json",
              PublicAPI.Schemas.ErrorResponses.Error
            ),
          422 =>
            Operation.response(
              "Validation Failed",
              "application/json",
              PublicAPI.Schemas.ErrorResponses.Validation
            )
        },
        unquote(specific)
      )
    end
  end
end
