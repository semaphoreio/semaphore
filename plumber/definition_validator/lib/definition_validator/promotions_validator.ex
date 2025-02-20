defmodule DefinitionValidator.PromotionsValidator do
  @moduledoc """
  Based on env variables restricts the usage of promotions.
  """

  def validate_yaml(""), do: {:error, {:malformed, "Empty string is not a valid YAML"}}

  def validate_yaml(definition) when is_map(definition) do
    with :ok <- check_promotions_in_ce(definition) do
      {:ok, definition}
    end
  end

  def validate_yaml(_), do: {:error, {:malformed, "Definition must be a map"}}

  defp check_promotions_in_ce(definition) do
    case {System.get_env("SKIP_PROMOTIONS"), has_promotions?(definition)} do
      {"true", true} -> {:error, {:malformed, "Promotions are not available in the Comunity edition of Semaphore."}}
      _ -> :ok
    end
  end

  defp has_promotions?(definition) do
    Map.has_key?(definition, "promotions") || Map.has_key?(definition, :promotions)
  end
end
