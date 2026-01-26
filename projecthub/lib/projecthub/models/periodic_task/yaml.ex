defmodule Projecthub.Models.PeriodicTask.YAML do
  @moduledoc """
  Composes a YAML definition for a task using Ymlr for safe encoding.

  This ensures proper escaping of special characters (quotes, backslashes, etc.)
  in task fields like description and parameter values.
  """
  alias Projecthub.Models.PeriodicTask
  alias Projecthub.Models.Project

  @doc """
  Composes a YAML definition for a task
  """
  @spec compose(PeriodicTask.t(), Project.t()) :: String.t()
  def compose(%PeriodicTask{} = task, %Project{} = project) do
    build_task_map(task, project)
    |> Ymlr.document!()
  end

  defp build_task_map(task, project) do
    %{
      "apiVersion" => "v1.2",
      "kind" => "Schedule",
      "metadata" => build_metadata(task),
      "spec" => build_spec(task, project)
    }
  end

  defp build_metadata(task) do
    %{
      "name" => task.name || "",
      "id" => task.id || "",
      "description" => task.description || ""
    }
  end

  defp build_spec(task, project) do
    base = %{
      "project" => project.name || "",
      "recurring" => task.recurring,
      "paused" => task.status == :STATUS_INACTIVE,
      "at" => task.at || "",
      "reference" => build_reference(task.branch),
      "pipeline_file" => task.pipeline_file || ""
    }

    maybe_add_parameters(base, task.parameters)
  end

  defp maybe_add_parameters(spec, nil), do: spec
  defp maybe_add_parameters(spec, []), do: spec
  defp maybe_add_parameters(spec, params), do: Map.put(spec, "parameters", build_parameters(params))

  defp build_reference(branch) when is_binary(branch) do
    {ref_type, ref_name} = parse_reference(branch)
    %{"type" => ref_type, "name" => ref_name}
  end

  defp build_reference(_), do: %{"type" => "BRANCH", "name" => "master"}

  defp build_parameters(parameters) do
    Enum.map(parameters, &build_parameter/1)
  end

  defp build_parameter(param) do
    base = %{
      "name" => param.name,
      "required" => param.required
    }

    base
    |> maybe_add("description", param[:description])
    |> maybe_add("default_value", param[:default_value])
    |> maybe_add_list("options", param[:options])
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, _key, ""), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)

  defp maybe_add_list(map, _key, nil), do: map
  defp maybe_add_list(map, _key, []), do: map
  defp maybe_add_list(map, key, values), do: Map.put(map, key, values)

  # Parse different reference formats to type and name
  defp parse_reference("refs/heads/" <> branch_name), do: {"BRANCH", branch_name}
  defp parse_reference("refs/tags/" <> tag_name), do: {"TAG", tag_name}
  defp parse_reference("refs/pull/" <> pr_ref), do: {"PR", extract_pr_number(pr_ref)}

  defp parse_reference(branch_name) when is_binary(branch_name) and branch_name != "",
    do: {"BRANCH", branch_name}

  defp parse_reference(_), do: {"BRANCH", "master"}

  # Extract PR number from refs/pull/123/head format
  defp extract_pr_number(pr_ref) do
    case String.split(pr_ref, "/") do
      [pr_number | _] -> pr_number
      _ -> pr_ref
    end
  end
end
