defmodule Projecthub.Models.PeriodicTask.YAML do
  @moduledoc """
  Composes a YAML definition for a task
  """
  alias Projecthub.Models.PeriodicTask
  alias Projecthub.Models.Project

  @doc """
  Composes a YAML definition for a task
  """
  @spec compose(PeriodicTask.t(), Project.t()) :: String.t()
  def compose(%PeriodicTask{} = task, %Project{} = project) do
    parameters_yml =
      unless empty?(task.parameters),
        do: compose_parameters_yaml(task.parameters, 2)

    [base_yml_definition(task, project), parameters_yml]
    |> Enum.reject(&empty?/1)
    |> Enum.map_join("\n", &String.trim(&1, "\n"))
    |> Kernel.<>("\n")
  end

  defp base_yml_definition(task, project) do
    reference_yml = compose_reference_yaml(task.branch, 2)

    """
    apiVersion: v1.2
    kind: Schedule
    metadata:
      name: \"#{task.name}\"
      id: \"#{task.id}\"
      description: \"#{task.description}\"
    spec:
      project: \"#{project.name}\"
      recurring: #{task.recurring}
      paused: #{task.status == :STATUS_INACTIVE}
      at: \"#{task.at}\"
    #{reference_yml}  pipeline_file: \"#{task.pipeline_file}\"
    """
  end

  defp compose_parameters_yaml(parameters_data, indent) do
    "#{indentation(indent)}parameters:\n" <>
      (parameters_data
       |> Enum.map(&compose_parameter_yaml(&1, indent))
       |> Enum.map_join("\n", &String.trim(&1, "\n")))
  end

  defp compose_parameter_yaml(data, indent) do
    required_fields = """
    #{indentation(indent)}- name: \"#{data.name}\"
    #{indentation(indent)}  required: #{data.required}
    """

    optional_fields =
      data
      |> Map.take(~w(description default_value)a)
      |> Enum.reject(&empty?(elem(&1, 1)))
      |> Enum.map_join("\n", &string_yaml_field(&1, indent + 2))

    options =
      unless empty?(data[:options]),
        do: list_yaml_field({"options", data[:options]}, indent + 2)

    [required_fields, optional_fields, options]
    |> Enum.reject(&empty?/1)
    |> Enum.map_join("\n", &String.trim(&1, "\n"))
    |> Kernel.<>("\n")
  end

  defp list_yaml_field({name, values}, indent) do
    values_string = Enum.map_join(values, "\n", &"#{indentation(indent)}- \"#{&1}\"")
    "#{indentation(indent)}#{name}:\n#{values_string}"
  end

  defp string_yaml_field({name, value}, indent),
    do: "#{indentation(indent)}#{name}: \"#{value}\""

  defp indentation(number),
    do: 0..(number - 1) |> Enum.map_join(fn _ -> " " end)

  # Composes reference YAML according to v1.2 spec
  defp compose_reference_yaml(branch, indent) when is_binary(branch) do
    {ref_type, ref_name} = parse_reference(branch)

    "#{indentation(indent)}reference:\n" <>
      "#{indentation(indent)}  type: #{ref_type}\n" <>
      "#{indentation(indent)}  name: \"#{ref_name}\"\n"
  end

  defp compose_reference_yaml(_, indent),
    do:
      "#{indentation(indent)}reference:\n#{indentation(indent)}  type: BRANCH\n#{indentation(indent)}  name: \"master\"\n"

  # Parse different reference formats to type and name
  defp parse_reference("refs/heads/" <> branch_name), do: {"BRANCH", branch_name}
  defp parse_reference("refs/tags/" <> tag_name), do: {"TAG", tag_name}
  defp parse_reference("refs/pull/" <> pr_ref), do: {"PR", extract_pr_number(pr_ref)}
  defp parse_reference(branch_name) when is_binary(branch_name) and branch_name != "", do: {"BRANCH", branch_name}
  defp parse_reference(_), do: {"BRANCH", "master"}

  # Extract PR number from refs/pull/123/head format
  defp extract_pr_number(pr_ref) do
    case String.split(pr_ref, "/") do
      [pr_number | _] -> pr_number
      _ -> pr_ref
    end
  end

  defp empty?(nil), do: true
  defp empty?(""), do: true
  defp empty?([]), do: true
  defp empty?(_), do: false
end
