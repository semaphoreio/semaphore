defmodule Gofer.Deployment.Model.Deployment.ObjectRule do
  @moduledoc """
  Holds deployment restriction for branches & tags
  """
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field(:type, Ecto.Enum, values: [:BRANCH, :TAG, :PR])
    field(:match_mode, Ecto.Enum, values: [:ALL, :EXACT, :REGEX])
    field(:pattern, :string)
  end

  def changeset(rule, params) do
    rule
    |> Ecto.Changeset.cast(params, ~w(type match_mode pattern)a)
    |> Ecto.Changeset.validate_required(~w(type match_mode)a)
    |> validate_pattern()
  end

  defp validate_pattern(changeset = %Ecto.Changeset{valid?: false}),
    do: changeset

  defp validate_pattern(changeset = %Ecto.Changeset{valid?: true}) do
    changeset
    |> Ecto.Changeset.get_field(:match_mode)
    |> case do
      :EXACT -> validate_plain_pattern(changeset)
      :REGEX -> validate_regex_pattern(changeset)
      :ALL -> changeset
    end
  end

  defp validate_plain_pattern(changeset = %Ecto.Changeset{}),
    do: Ecto.Changeset.validate_required(changeset, [:pattern])

  defp validate_regex_pattern(changeset = %Ecto.Changeset{}) do
    changeset
    |> Ecto.Changeset.validate_required([:pattern])
    |> Ecto.Changeset.validate_change(:pattern, &validate_regex/2)
  end

  defp validate_regex(:pattern, pattern) do
    case Regex.compile(pattern) do
      {:ok, _regex} -> []
      {:error, _reason} -> [pattern: "must be regex"]
    end
  end
end
