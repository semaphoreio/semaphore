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
    |> validate_regex_pattern_length()
    |> validate_regex_pattern()
    |> validate_default_value_format()
  end

  # Cap stored regex_pattern length unconditionally — even when
  # validate_input_format is false. Prevents an attacker from persisting
  # an arbitrarily large pattern that becomes a runtime hazard the
  # moment the toggle flips on.
  defp validate_regex_pattern_length(changeset) do
    pattern = Ecto.Changeset.get_field(changeset, :regex_pattern)
    max = Scheduler.SafeRegex.max_pattern_length()

    if is_binary(pattern) and byte_size(pattern) > max do
      Ecto.Changeset.add_error(
        changeset,
        :regex_pattern,
        "is too long (max #{max} bytes)"
      )
    else
      changeset
    end
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

      Keyword.has_key?(changeset.errors, :regex_pattern) ->
        # Length validator already raised; do not pile on.
        changeset

      true ->
        case Scheduler.SafeRegex.validate_pattern(pattern) do
          :ok ->
            changeset

          {:error, :pattern_too_long} ->
            # Defensive — should be unreachable because validate_regex_pattern_length
            # already runs unconditionally.
            Ecto.Changeset.add_error(
              changeset,
              :regex_pattern,
              "is too long (max #{Scheduler.SafeRegex.max_pattern_length()} bytes)"
            )

          {:error, :invalid_pattern} ->
            Ecto.Changeset.add_error(changeset, :regex_pattern, "is not a valid regex")
        end
    end
  end

  defp validate_default_value_format(changeset) do
    validate_input_format? = Ecto.Changeset.get_field(changeset, :validate_input_format)
    pattern = Ecto.Changeset.get_field(changeset, :regex_pattern)
    default_value = Ecto.Changeset.get_field(changeset, :default_value)

    cond do
      not validate_input_format? ->
        changeset

      not (is_binary(pattern) and pattern != "") ->
        changeset

      not (is_binary(default_value) and default_value != "") ->
        changeset

      true ->
        case Scheduler.SafeRegex.match(pattern, default_value) do
          {:ok, true} ->
            changeset

          {:ok, false} ->
            Ecto.Changeset.add_error(
              changeset,
              :default_value,
              "does not match regex_pattern"
            )

          {:error, :value_too_long} ->
            Ecto.Changeset.add_error(
              changeset,
              :default_value,
              "is too long (max #{Scheduler.SafeRegex.max_value_length()} bytes)"
            )

          {:error, _reason} ->
            Ecto.Changeset.add_error(
              changeset,
              :default_value,
              "could not be validated against regex_pattern"
            )
        end
    end
  end
end
