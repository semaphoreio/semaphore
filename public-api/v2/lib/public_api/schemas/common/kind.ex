defmodule PublicAPI.Schemas.Common.Kind do
  @moduledoc """
  Kind of resource. Use it in each module to instantiate a schema for the kind.

  use PublicAPI.Schemas.Common.Kind, default: "Project"

  will create a module Kind with a schema that validates the kind to be value "Project"
  Then use ResourceKind.schema() in the resource object schema.
  """

  defmacro __using__(opts) do
    kind = Keyword.get(opts, :kind, "Project")

    quote do
      defmodule ResourceKind do
        @moduledoc false
        alias OpenApiSpex.Cast

        OpenApiSpex.schema(%{
          title: "Kind",
          description:
            "Kind is a string value representing the REST resource this object represents.
        Servers may infer this from the endpoint the client submits requests to. Cannot be
        updated. In CamelCase.",
          type: :string,
          readOnly: true,
          default: unquote(kind),
          example: unquote(kind),
          "x-validate": __MODULE__
        })

        def cast(context = %Cast{value: value}) when value in [unquote(kind)],
          do: Cast.ok(context)

        def cast(context),
          do: Cast.error(context, {:invalid_format, unquote(kind)})
      end
    end
  end
end
