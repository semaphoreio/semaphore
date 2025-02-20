defmodule PublicAPI.SpecHelpers do
  @moduledoc """
  Contains helper modules for OpenApi specifications of
  PublicAPI handlers and schemas.
  """
  defmodule Operation do
    @moduledoc """
    Requires spec helper functions for OpenApi specification in
    handler plugs.
    """
    defmacro __using__(_opts) do
      quote do
        require PublicAPI.SpecHelpers.Pagination, as: Pagination
        require PublicAPI.SpecHelpers.Responses, as: Responses
        alias OpenApiSpex.{Operation, Schema}
        alias PublicAPI.Schemas
        import PublicAPI.Schemas.Common
      end
    end
  end

  defmodule Schema do
    @moduledoc """
    Requires spec helper functions for OpenApi specification in
    schemas.
    """
    defmacro __using__(_opts) do
      quote do
        require OpenApiSpex
        import PublicAPI.Schemas.Common
        alias OpenApiSpex.Schema
      end
    end
  end
end
