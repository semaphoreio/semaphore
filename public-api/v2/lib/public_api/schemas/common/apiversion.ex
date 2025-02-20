defmodule PublicAPI.Schemas.Common.ApiVersion do
  @moduledoc """
  Schema for the API version
  """
  use PublicAPI.SpecHelpers.Schema
  alias OpenApiSpex.Cast

  OpenApiSpex.schema(%{
    title: "ApiVersion",
    description: "ApiVersion defines the versioned schema of this representation of an object.
        Servers should convert recognized schemas to the latest internal value, and may reject
        unrecognized values.",
    type: :string,
    readOnly: true,
    default: "v2",
    example: "v2",
    "x-validate": __MODULE__
  })

  def cast(context = %Cast{value: value}) when value in ["v2"],
    do: Cast.ok(context)

  def cast(context),
    do: Cast.error(context, {:invalid_format, "API only supports v1"})
end
