defmodule PublicAPI.Schemas.DeploymentTargets.DeploymentTarget.ObjectRule do
  @moduledoc """
  Schemas for a deployment target object rule
  """
  alias OpenApiSpex.Cast
  require OpenApiSpex

  defmacro __using__(opts) do
    object = Keyword.get(opts, :object)
    capitalized_object = String.capitalize(object) |> String.to_atom()

    quote do
      defmodule :"ObjectRule#{unquote(capitalized_object)}" do
        @moduledoc false
        alias OpenApiSpex.Schema

        def schema() do
          %Schema{
            title: "DeploymentTargets.DeploymentTarget.ObjectRule.#{unquote(capitalized_object)}",
            oneOf: [
              %Schema{
                title:
                  "DeploymentTargets.DeploymentTarget.ObjectRule.#{unquote(capitalized_object)}.All",
                type: :string,
                enum: ~w(ALL),
                description: ~s(Allows all #{unquote(object)} to trigger a deployment)
              },
              %Schema{
                title:
                  "DeploymentTargets.DeploymentTarget.ObjectRule.#{unquote(capitalized_object)}.MatchType",
                description: "The pattern to match against the #{unquote(object)} name",
                type: :array,
                items: %Schema{
                  type: :object,
                  "x-validate":
                    PublicAPI.Schemas.DeploymentTargets.DeploymentTarget.ObjectRule.RegexValidator,
                  properties: %{
                    match_mode: %Schema{
                      type: :string,
                      enum: ~w(EXACT REGEX),
                      description: ~s(Indicates how pattern is matched.)
                    },
                    pattern: %Schema{
                      type: :string,
                      description: "The pattern to match against #{unquote(object)} the name.
                    If `match_mode` is `EXACT`, the pattern must match exactly.
                    If `match_mode` is `REGEX`, the pattern must be a valid regex."
                    }
                  }
                }
              }
            ]
          }
        end
      end
    end
  end

  defmodule RegexValidator do
    @moduledoc """
      Compiles the regex if match_mode is REGEX
    """
    alias OpenApiSpex.Cast

    def cast(ctx = %Cast{value: value}) do
      with {:ok, value} <- Cast.Object.cast(ctx),
           "REGEX" <- value.match_mode,
           {:ok, _} <-
             cast_regex(%{ctx | path: [:pattern | ctx.path], value: value.pattern}) do
        Cast.ok(%Cast{ctx | value: value})
      else
        "EXACT" ->
          Cast.ok(%Cast{ctx | value: value})

        e ->
          e
      end
    end

    def cast_regex(ctx) do
      case Regex.compile(ctx.value) do
        {:ok, _} ->
          Cast.ok(ctx)

        {:error, _} ->
          Cast.error(ctx, {:invalid_format, "Invalid regex"})
      end
    end
  end
end
