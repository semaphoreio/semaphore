defmodule Front.Artifacts.Folder do
  @doc """
  `contruct_navigation` creates navigation components
  for artifact folder browsing
  """

  def get_navigation(requested_path) do
    path_parts = String.split(requested_path, "/", trim: true)
    highest_index = length(path_parts) - 1

    construct_navigation(path_parts, highest_index)
  end

  defp construct_navigation(path_parts, highest_index) do
    {_, result} =
      Enum.reduce(path_parts, {0, []}, fn x, {index, parts} ->
        result = parts ++ [construct_component(parts, x, index, highest_index)]

        {index + 1, result}
      end)

    result
  end

  defp construct_component(preceding_components, name, current_index, last_index) do
    %{
      path: construct_component_path(preceding_components, name),
      name: name,
      last: current_index == last_index
    }
  end

  def construct_component_path(preceding_components, name) do
    if Enum.any?(preceding_components) do
      parent_dir =
        Enum.at(preceding_components, -1)
        |> Map.get(:path)

      "#{parent_dir}/#{name}"
    else
      name
    end
  end
end
