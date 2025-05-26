defmodule Front.Models.SecretUpdater do
  require Logger

  alias Front.Models.ConfigFile
  alias Front.Models.EnvironmentVariable

  def consolidate(secret, env_vars_params, files_params) do
    new_env_vars = do_consolidate(secret.env_vars, env_vars_params, :env_var)
    new_files = do_consolidate(secret.files, files_params, :file)

    %{secret | env_vars: new_env_vars, files: new_files}
  end

  def do_consolidate(current_ones, new_ones, type) do
    init_acc = %{
      processed: [],
      new_by_old_key:
        new_ones
        |> Enum.filter(fn item ->
          valid_string?(item[old_key_as_string(type)]) &&
            valid_string?(item[key_as_string(type)]) &&
            (valid_string?(item["md5"]) || valid_string?(item[value_as_string(type)]))
        end)
        |> Map.new(&{&1[old_key_as_string(type)], &1})
    }

    %{processed: processed, new_by_old_key: new_by_old_key} =
      Enum.reduce(current_ones, init_acc, &accumulate_processed(&1, &2, type))

    filtered_new_params =
      new_ones
      |> Enum.filter(
        &(not valid_string?(&1[old_key_as_string(type)]) ||
            Map.has_key?(new_by_old_key, &1[old_key_as_string(type)]))
      )

    Enum.reverse(processed) ++ construct_new_ones(filtered_new_params, type)
  end

  defp construct_new_ones(new_ones, type) do
    new_ones
    |> Stream.filter(&valid_string?(&1[key_as_string(type)]))
    |> Stream.filter(&valid_string?(&1[value_as_string(type)]))
    |> Enum.into([], &new_from_params(&1, type))
  end

  defp accumulate_processed(current_file, acc, type) do
    matched_new_file = Map.get(acc.new_by_old_key, Map.get(current_file, key_as_atom(type)))

    if matched_new_file,
      do: merge_and_delete_new(acc, type, current_file, matched_new_file),
      else: acc
  end

  defp merge_and_delete_new(acc, type, current_file, new_file) do
    %{
      processed: [merge(current_file, new_file, type) | acc.processed],
      new_by_old_key: Map.delete(acc.new_by_old_key, new_file[old_key_as_string(type)])
    }
  end

  defp merge(current, new, :env_var), do: merge_env_var(current, new)
  defp merge(current, new, :file), do: merge_file(current, new)

  defp merge_env_var(_current_file, %{"name" => name, "value" => value})
       when value != "" and value != "undefined",
       do: %EnvironmentVariable{name: name, value: value}

  defp merge_env_var(current_var, %{"name" => name, "md5" => md5}) when md5 != "",
    do: %EnvironmentVariable{name: name, value: Map.get(current_var, :value, "")}

  defp merge_env_var(current_var, _new_file),
    do: %EnvironmentVariable{name: current_var.name, value: current_var.value}

  defp merge_file(_current_file, %{"path" => path, "content" => content})
       when content != "" and content != "undefined",
       do: %ConfigFile{path: path, content: content}

  defp merge_file(current_file, %{"path" => path, "md5" => md5}) when md5 != "",
    do: %ConfigFile{path: path, content: Map.get(current_file, :content, "")}

  defp merge_file(current_file, _new_file),
    do: %ConfigFile{path: current_file.path, content: current_file.content}

  defp new_from_params(new_one, :env_var),
    do: %EnvironmentVariable{name: new_one["name"], value: new_one["value"]}

  defp new_from_params(new_one, :file),
    do: %ConfigFile{path: new_one["path"], content: new_one["content"]}

  defp old_key_as_string(:env_var), do: "old_name"
  defp old_key_as_string(:file), do: "old_path"

  defp key_as_atom(:env_var), do: :name
  defp key_as_atom(:file), do: :path
  defp key_as_string(type), do: type |> key_as_atom() |> Atom.to_string()

  defp value_as_atom(:env_var), do: :value
  defp value_as_atom(:file), do: :content
  defp value_as_string(type), do: type |> value_as_atom() |> Atom.to_string()

  defp valid_string?(arg) when not is_binary(arg), do: false
  defp valid_string?("undefined"), do: false
  defp valid_string?(""), do: false
  defp valid_string?(_arg), do: true
end
