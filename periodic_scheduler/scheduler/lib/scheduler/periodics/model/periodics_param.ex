defmodule Scheduler.Periodics.Model.PeriodicsParam do
  @moduledoc """
  Periodic parameter schema
  """
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :name, :string
    field :description, :string
    field :required, :boolean
    field :options, {:array, :string}, default: []
    field :default_value, :string
    field :regex_pattern, :string
    field :validate_input_format, :boolean, default: false
  end

  @all_fields ~w(name description required options default_value regex_pattern validate_input_format)a
  @required_fields ~w(name required)a

  def changeset(param, params \\ %{}) do
    param
    |> Ecto.Changeset.cast(params, @all_fields)
    |> Ecto.Changeset.validate_required(@required_fields)
    |> validate_regex_pattern()
    |> validate_default_value_format()
  end

  defp validate_regex_pattern(changeset) do
    validate_input_format? = Ecto.Changeset.get_field(changeset, :validate_input_format)
    pattern = Ecto.Changeset.get_field(changeset, :regex_pattern)

    cond do
      not validate_input_format? ->
        changeset

      is_nil(pattern) or pattern == "" ->
        Ecto.Changeset.add_error(
          changeset,
          :regex_pattern,
          "can't be blank when validate_input_format is true"
        )

      true ->
        case Regex.compile(pattern) do
          {:ok, _regex} ->
            changeset

          {:error, {reason, _pos}} ->
            Ecto.Changeset.add_error(
              changeset,
              :regex_pattern,
              "is not a valid regex: #{inspect(reason)}"
            )
        end
    end
  end

  defp validate_default_value_format(changeset) do
    validate_input_format? = Ecto.Changeset.get_field(changeset, :validate_input_format)
    pattern = Ecto.Changeset.get_field(changeset, :regex_pattern)
    default_value = Ecto.Changeset.get_field(changeset, :default_value)

    with true <- validate_input_format?,
         true <- is_binary(pattern) and pattern != "",
         true <- is_binary(default_value) and default_value != "",
         {:ok, regex} <- Regex.compile(pattern),
         false <- Regex.match?(regex, default_value) do
      Ecto.Changeset.add_error(
        changeset,
        :default_value,
        "does not match regex_pattern"
      )
    else
      _ -> changeset
    end
  end
end
