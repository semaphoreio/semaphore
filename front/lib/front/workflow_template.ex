defmodule Front.WorkflowTemplate do
  @moduledoc """
  This module is intended for fetching simplest yaml template we have.
  Functions return contet of the file as string.
  """

  def simple(org_id) do
    new_project_onboarding? = FeatureProvider.feature_enabled?(:new_project_onboarding, param: org_id)

    templates_path =
      if new_project_onboarding? do
        Application.get_env(:front, :new_project_onboarding_workflow_templates_path)
      else
        Application.get_env(:front, :workflow_templates_path)
      end

    templates_path
    |> Path.join("templates/simple.yml")
    |> File.read!()
  end

  def set_machine_type(content, machine_type) do
    content
    |> String.replace("{{ machine_type }}", machine_type)
  end

  def set_os_image(content, os_image) do
    content
    |> String.replace("{{ os_image }}", os_image)
  end

  @doc """
  Fetches a workflow template from a given path.
  Returns {:ok, content} if template exists and path is valid,
  {:error, reason} otherwise.
  """
  def fetch_from_path(template_path) when is_binary(template_path) do
    full_path =
      Application.get_env(:front, :new_project_onboarding_workflow_templates_path)
      |> Path.join(template_path)

    if valid_template_path?(full_path) do
      case File.read(full_path) do
        {:ok, content} -> {:ok, content}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :invalid_path}
    end
  end

  def fetch_from_path(_), do: {:error, :invalid_path}

  @doc """
  Processes a template content by replacing machine type and OS image placeholders.
  """
  def process_template(content, params) do
    content = set_machine_type(content, params["machine_type"])

    case params["os_images"] do
      empty when empty == [] or is_nil(empty) ->
        set_os_image(content, ~s(''))

      [os_image | _] ->
        set_os_image(content, os_image)
    end
  end

  defp valid_template_path?(path) do
    !String.contains?(path, "..") and path != ""
  end
end
