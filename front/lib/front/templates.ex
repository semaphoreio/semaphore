defmodule Front.Templates do
  def load_all(new_onboarding \\ false)

  def load_all(true) do
    load(new_project_onboarding_root_path())
  end

  def load_all(false) do
    load(root_path()) |> sort()
  end

  def setup do
    new_project_onboarding_root_path()
    |> Path.join("setup.json")
    |> File.read!()
    |> Poison.decode!()
  end

  defp load(root_path) do
    File.ls!(properties_path(root_path))
    |> read(root_path)
  end

  defp read(paths, root_path) do
    paths
    |> Enum.filter(fn property_file -> json_file?(property_file) end)
    |> Enum.map(fn property_file ->
      Path.join(properties_path(root_path), "#{property_file}")
      |> File.read!()
      |> Poison.decode!()
    end)
    |> Enum.map(fn properties ->
      properties
      |> Map.put(
        "template_content",
        Path.join(root_path, "#{properties["template_path"]}")
        |> File.read!()
      )
    end)
  end

  defp sort(templates) do
    %{pinned_templates: pinned_templates, other_templates: other_templates} =
      Enum.group_by(templates, fn template ->
        case template["pinned"] do
          true -> :pinned_templates
          _ -> :other_templates
        end
      end)

    [pinned_templates, other_templates]
  end

  # We are excluding swp files on dev machine
  defp json_file?(file_path) do
    !String.starts_with?(file_path, ".") && String.ends_with?(file_path, ".json")
  end

  defp root_path, do: Application.get_env(:front, :workflow_templates_path)

  defp new_project_onboarding_root_path,
    do: Application.get_env(:front, :new_project_onboarding_workflow_templates_path)

  defp properties_path(root_path), do: Path.join(root_path, "properties")
end
