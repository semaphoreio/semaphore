defmodule Ppl.DefinitionReviser.WhenValidator do
  @moduledoc """
  Module traverses recursively through pipeline definition and evaluates all found
  'when' conditions for default params. If lexical, syntax or other error is found,
  it will be returned as ':mallformed' error and will cause pipeline to fail
  validation step in 'initializing' state, and go straight to 'done-failed-malformed'
  state.
  """

  alias Util.ToTuple

  @default_params %{
    "branch" => "", "tag" => "", "pull_request" => "", "working_dir" => "",
    "commit_sha" => "", "project_id" => ""
  }

   @default_params_for_promotions %{
    "branch" => "", "tag" => "", "result" => "", "result_reason" => "",
    "pull_request" => "", "working_dir" => "", "commit_sha" => "",
    "project_id" => ""
  }

  def validate(definition) do
    definition
    |> validate_pipeline()
    |> validate_promotions(definition)
  end

  defp validate_pipeline(definition) do
    pipeline = Map.drop(definition, ["promotions"])
    validate_({:ok, pipeline}, "#", false)
  end

  defp validate_promotions({:ok, _pipeline}, definition) do
    promotions = Map.get(definition, "promotions", %{})

    case validate_({:ok, promotions}, "#", true) do
      {:ok, _promotions} -> {:ok, definition}

      error -> error
    end
  end
  defp validate_promotions(error = {:error, _message}, _definition), do: error

  defp validate_({:ok, elem = %{"when" => when_expr}}, path, is_promotion) when is_binary(when_expr) do
      evaluate(elem, path, when_expr, is_promotion)
  end
  defp validate_({:ok, elem = %{"when" => bool_value}}, _path, _is_promotion)
    when is_boolean(bool_value), do: {:ok, elem}

  defp validate_({:ok, map}, path, is_promotion) when is_map(map) do
    map
    |> Enum.reduce_while({:ok, %{}}, fn {key, elem}, {:ok, acc} ->
      case validate_({:ok, elem}, path <> "/#{key}", is_promotion) do
        {:ok, value} -> {:cont, {:ok, Map.put(acc, key, value)}}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_({:ok, list}, path, is_promotion) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {elem, index}, {:ok, acc} ->
      case validate_({:ok, elem}, path <> "/#{index}", is_promotion) do
        {:ok, value} -> {:cont, {:ok, acc ++ [value]}}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_({:ok, elem}, _path, _is_promotion), do: {:ok, elem}

  defp evaluate(elem, path, when_expr, is_promotion) do
    params = if is_promotion, do: @default_params_for_promotions, else: @default_params

    case When.evaluate(when_expr, params, dry_run: true) do
      {:ok, result} when is_boolean(result) -> {:ok, elem}
      {:error, msg} -> "Invalid 'when' condition on path '#{path <> "/when"}': #{msg}"
                       |> ToTuple.error(:malformed)
    end
  end
end
