defmodule PublicAPI.Schemas.PageSize do
  @moduledoc """
  Defines defaults for pagination page size parameter.
  """
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "PageSize",
    type: :integer,
    minimum: 1,
    maximum: 100,
    default: 20
  })
end
