defmodule Secrethub.Model.Content do
  @moduledoc """
  Schema model for secret content data
  """
  use Ecto.Schema

  alias Secrethub.Model.EnvVar
  alias Secrethub.Model.File

  # The content of a secret can have at most 6 MB.
  @max_size 1024 * 1024 * 6

  @primary_key false
  embedded_schema do
    embeds_many :env_vars, EnvVar, on_replace: :delete
    embeds_many :files, File, on_replace: :delete
  end

  def changeset(content, params) do
    content
    |> Ecto.Changeset.cast(params, [])
    |> Ecto.Changeset.cast_embed(:env_vars)
    |> Ecto.Changeset.cast_embed(:files)
    |> validate_size()
  end

  defp validate_size(changeset) do
    if total_size(changeset) > @max_size do
      changeset |> Ecto.Changeset.add_error(:size, "content is too big")
    else
      changeset
    end
  end

  defp total_size(changeset) do
    files = Ecto.Changeset.get_field(changeset, :files)
    vars = Ecto.Changeset.get_field(changeset, :env_vars)
    total_files_size(files) + total_vars_size(vars)
  end

  defp total_files_size(nil), do: 0

  defp total_files_size(files) do
    Enum.reduce(files, 0, fn file, size ->
      if file.content != nil, do: size + byte_size(file.content), else: size
    end)
  end

  defp total_vars_size(nil), do: 0

  defp total_vars_size(vars) do
    Enum.reduce(vars, 0, fn var, size ->
      if var.value != nil, do: size + byte_size(var.value), else: size
    end)
  end

  def validate(_, changeset) do
    changeset
    |> Ecto.Changeset.validate_change(:env_vars, &validate_content/2)
    |> Ecto.Changeset.validate_change(:files, &validate_content/2)
    |> Map.get(:errors, [])
    |> Enum.filter(fn
      {"", []} -> false
      _ -> true
    end)
  end

  defp validate_content(key, changesets) do
    Enum.map(changesets, fn changeset ->
      {key, consolidate_changeset_errors(changeset)}
    end)
    |> Enum.filter(fn
      {_, ""} -> false
      _ -> true
    end)
  end

  def consolidate_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join(
      ", ",
      fn {key, messages} ->
        messages
        |> Enum.map_join(", ", fn message ->
          m =
            if is_map(message),
              do: Enum.map(message, fn {k, v} -> "#{k} #{Enum.join(v, " ")}" end),
              else: message

          "#{key} #{m}"
        end)
      end
    )
  end
end
