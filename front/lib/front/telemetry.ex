defmodule Front.Telemetry do
  @moduledoc """
  Telemetry module that sends metrics and metadata to telemetry public endpoint.
  The data sent includes:

  - Release version
  - Installation ID
  - Number of projects
  - Number of Organization members
  """
  require Logger

  alias Front.RBAC.Members
  alias Front.Models.Project

  @cache_key "telemetry_config"

  def perform do
    org_id = organization_id()
    org_members_count_task = Task.async(fn -> Members.count(org_id) end)
    projects_count_task = Task.async(fn -> Project.count(org_id) end)

    {:ok, projects_count} = Task.await(projects_count_task)
    {:ok, org_members_count} = Task.await(org_members_count_task)

    data = %{
      version: Application.fetch_env!(:front, :ce_version),
      installation_id: installation_id(),
      kube_version: kube_version(),
      org_members_count: org_members_count,
      projects_count: projects_count
    }

    Logger.info("Sending metrics to telemetry endpoint: #{inspect(data)}")

    submit(data)
  end

  defp submit(data) do
    headers = [
      "Content-type": "application/json"
    ]

    json_data = Jason.encode!(data)

    case HTTPoison.post(telemetry_endpoint(), json_data, headers, []) do
      {:ok, response} when response.status_code in [200, 201] ->
        Logger.info("Metrics sent to telemetry endpoint: #{inspect(response)}")
        :ok

      error ->
        Logger.error("Failed to send metrics to telemetry endpoint: #{inspect(error)}")
        :error
    end
  end

  defp organization_id, do: get("organization_id")
  defp installation_id, do: get("installation_id")
  defp kube_version, do: get("kube_version")
  defp telemetry_endpoint, do: get("telemetry_endpoint")

  defp get(field) do
    Cachex.get(:front_cache, @cache_key)
    |> case do
      {:ok, configs} when not is_nil(configs) ->
        configs.fields[field]

      _ ->
        get_from_api(field)
    end
  end

  defp get_from_api(field) do
    Front.Models.InstanceConfig.list_integrations(:CONFIG_TYPE_INSTALLATION_DEFAULTS)
    |> case do
      {:ok, integration} ->
        Cachex.put(:front_cache, @cache_key, integration)
        integration.fields[field]

      {:error, _} ->
        ""
    end
  end
end
