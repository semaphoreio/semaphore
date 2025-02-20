defmodule Guard.InstanceConfig.Models.Utils do
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
