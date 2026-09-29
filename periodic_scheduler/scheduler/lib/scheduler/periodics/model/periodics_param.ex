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
    |> normalize_regex_pattern_when_validation_disabled()
    |> validate_regex_pattern_length()
    |> validate_regex_pattern()
    |> validate_default_value_format()
  end

  defp normalize_regex_pattern_when_validation_disabled(changeset) do
    case Ecto.Changeset.get_field(changeset, :validate_input_format) do
      false -> Ecto.Changeset.put_change(changeset, :regex_pattern, nil)
      _ -> changeset
    end
  end

  defp validate_regex_pattern_length(changeset) do
    pattern = Ecto.Changeset.get_field(changeset, :regex_pattern)
    max = Util.SafeRegex.max_pattern_length()

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
        changeset

      true ->
        case Util.SafeRegex.validate_pattern(pattern) do
          :ok ->
            changeset

          {:error, :pattern_too_long} ->
            Ecto.Changeset.add_error(
              changeset,
              :regex_pattern,
              "is too long (max #{Util.SafeRegex.max_pattern_length()} bytes)"
            )

          {:error, :invalid_pattern} ->
            Ecto.Changeset.add_error(changeset, :regex_pattern, "is not a valid regex")
        end
    end
  end

  defp validate_default_value_format(changeset) do
    if Keyword.has_key?(changeset.errors, :regex_pattern) do
      changeset
    else
      validate_input_format? = Ecto.Changeset.get_field(changeset, :validate_input_format)
      pattern = Ecto.Changeset.get_field(changeset, :regex_pattern)
      default_value = Ecto.Changeset.get_field(changeset, :default_value)

      if should_check_default_value?(validate_input_format?, pattern, default_value) do
        apply_default_value_match(changeset, pattern, default_value)
      else
        changeset
      end
    end
  end

  defp should_check_default_value?(validate_input_format?, pattern, default_value) do
    validate_input_format? and
      is_binary(pattern) and pattern != "" and
      is_binary(default_value) and default_value != ""
  end

  defp apply_default_value_match(changeset, pattern, default_value) do
    case Util.SafeRegex.match(pattern, default_value) do
      {:ok, true} ->
        changeset

      {:ok, false} ->
        Ecto.Changeset.add_error(changeset, :default_value, "does not match regex_pattern")

      {:error, :value_too_long} ->
        Ecto.Changeset.add_error(
          changeset,
          :default_value,
          "is too long (max #{Util.SafeRegex.max_value_length()} bytes)"
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
