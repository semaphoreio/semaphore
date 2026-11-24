defmodule Zebra.Workers.Agent.HostedAgent do
  require Logger
  import Ecto.Query

  defstruct [
    :id,
    :name,
    :ip_address,
    :ctrl_port,
    :auth_token,
    :ssh_port,
    :provider,
    :region,
    :zone
  ]

  alias FeatureProvider.Feature
  alias InternalApi.Chmura.Chmura.Stub
  alias InternalApi.Chmura.{OccupyAgentRequest, ReleaseAgentRequest}

  # A second provider with the same API can serve the hosted jobs of organizations
  # that have this feature. The job keeps the provider that gave it its agent, so the
  # release goes back to the same one even if the feature changes meanwhile.
  @secondary_provider "secondary"
  @secondary_provider_feature "secondary_hosted_agent_provider"

  # How jobs.request_provider names the default provider. A job without one was
  # built before it was stored, and follows the feature at dispatch.
  @default_provider "default"

  # Organizations whose jobs the secondary provider must keep in its home region,
  # the :chmura_secondary_home_region setting.
  @home_region_only_feature "secondary_hosted_agent_home_region_only"

  def secondary_provider, do: @secondary_provider

  # sobelow_skip ["Config.TLSVerify"]
  def http_options,
    do: [
      hackney: [
        :insecure,
        connect_timeout: 2_000,
        recv_timeout: 3_000
      ]
    ]

  # sends a HTTP message to the agent
  def send(host, port, token, path, payload) do
    url = "https://#{host}:#{port}#{path}"

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{token || ""}"}
    ]

    case HTTPoison.post(url, payload, headers, http_options()) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        :ok

      e ->
        Logger.error("Failed to send to #{url}. Error #{inspect(e)}")
        submit_send_errors(host, e)
        {:error, e}
    end
  end

  defp submit_send_errors(host, error) do
    host = String.replace(host, ".", "-")

    case error do
      {:ok, %HTTPoison.Response{body: body, status_code: 401}} ->
        if String.contains?(body, "signature is invalid") do
          Watchman.increment({"agent.send.error", ["401_invalid_signature", host]})
        else
          Watchman.increment({"agent.send.error", ["401_unknown", host]})
        end

      {:error, %HTTPoison.Error{reason: {:tls_alert, _}}} ->
        Watchman.increment({"agent.send.error", ["tls_alert", host]})

      {:error, _} ->
        Watchman.increment({"agent.send.error", ["unknown", host]})

      _ ->
        Watchman.increment({"agent.send.error", ["unknown", host]})
    end
  end

  @doc """
  For each provider, how many of the given jobs (in dispatch order) wait for
  it from each job onward, that job included: %{provider => %{job_id => n}},
  providers keyed like provider_for/1. Counting from the job onward leaves
  out the jobs ahead of it, which the same tick may already have served.
  With no secondary endpoint every job goes to the default provider, so no
  query is needed.
  """
  def waiting_by_provider([]), do: %{}

  def waiting_by_provider(job_ids) do
    if secondary_endpoint() do
      providers =
        Zebra.Models.Job
        |> where([j], j.id in ^job_ids)
        |> select([j], {j.id, j.request_provider, j.organization_id})
        |> Zebra.LegacyRepo.all()
        |> Map.new(fn {id, stored, org_id} -> {id, dispatch_provider(stored, org_id)} end)

      job_ids
      |> Enum.filter(&Map.has_key?(providers, &1))
      |> Enum.group_by(&Map.fetch!(providers, &1))
      |> Map.new(fn {provider, ids} -> {provider, waiting_from_each(ids)} end)
    else
      %{nil => waiting_from_each(job_ids)}
    end
  end

  defp waiting_from_each(ids) do
    n = length(ids)

    ids |> Enum.with_index() |> Map.new(fn {id, i} -> {id, n - i} end)
  end

  @doc """
  Asks the job's provider for an agent. waiting_by_provider is from
  waiting_by_provider/1: the job's count goes with the request, so the
  provider knows its whole queue even when the dispatcher stops asking after
  a NOT_FOUND. A job missing from it sends 0, which means unknown.
  """
  def occupy(job, waiting_by_provider \\ %{}) do
    provider = provider_for(job)
    waiting = waiting_by_provider |> Map.get(provider, %{}) |> Map.get(job.id, 0)

    Task.async(fn ->
      Watchman.benchmark("zebra.external.chmura.occupy", fn ->
        {machine_type, machine_os_image} = translate_machine(job)

        Logger.info("Occupying agent for job: #{job.id} ...")

        with {:ok, regions} <- preferred_regions(provider, job.organization_id),
             request =
               OccupyAgentRequest.new(
                 request_id: job.id,
                 organization_id: job.organization_id || "",
                 project_id: job.project_id || "",
                 waiting: waiting,
                 preferred_regions: regions,
                 machine:
                   InternalApi.Chmura.Agent.Machine.new(
                     type: machine_type,
                     os_image: machine_os_image
                   )
               ),
             {:ok, channel} <- connect(provider),
             {:ok, response} <- Stub.occupy_agent(channel, request, timeout: 30_000) do
          {:ok, construct_agent(response, provider)}
        else
          {:error, error} ->
            Logger.error(inspect(error))
            {:error, occupy_error(provider, error)}
        end
      end)
    end)
    |> Task.await(:infinity)
  end

  def release(job) do
    Watchman.benchmark("zebra.external.chmura.occupy", fn ->
      Logger.info("Releasing agent for job '#{job.id}' agent_id: '#{job.agent_id}'")

      request = ReleaseAgentRequest.new(agent_id: job.agent_id)

      with {:ok, channel} <- connect(job.agent_provider),
           {:ok, _} <- Stub.release_agent(channel, request, timeout: 30_000) do
        :ok
      else
        {:error, err} ->
          ids = "job_id:'#{job.id}' agent_id:'#{job.agent_id}'"
          Logger.error("Error while releasing agent #{ids}, err: #{inspect(err)}")
          {:error, error_message(err)}
      end
    end)
  end

  def construct_agent(response, provider \\ nil) do
    %__MODULE__{
      id: response.agent.id,
      name: "",
      ip_address: response.agent.ip_address,
      ctrl_port: response.agent.ctrl_port,
      auth_token: response.agent.auth_token || "",
      ssh_port: response.agent.ssh_port,
      provider: provider,
      region: present(response.agent.region),
      zone: present(response.agent.zone)
    }
  end

  # Providers that do not report where the agent runs leave these empty.
  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_value), do: nil

  # The regions the job may run in; empty allows any. Only the secondary provider
  # is restricted. A job that must stay home is not offered at all while the home
  # region is unknown, since the provider would then pick any region.
  defp preferred_regions(@secondary_provider, org_id) when is_binary(org_id) do
    case {home_region_only?(org_id), home_region()} do
      {false, _region} -> {:ok, []}
      {true, nil} -> {:error, :home_region_not_configured}
      {true, region} -> {:ok, [region]}
    end
  end

  defp preferred_regions(_provider, _org_id), do: {:ok, []}

  # If the organization's features cannot be read, the job stays home: waiting
  # for an agent there is safer than running it in a region it may not use.
  defp home_region_only?(org_id) do
    case FeatureProvider.list_features(param: org_id) do
      {:ok, features} ->
        Enum.any?(features, &(&1.type == @home_region_only_feature and Feature.enabled?(&1)))

      {:error, error} ->
        Logger.warning("No features for #{org_id}, home region only: #{inspect(error)}")
        Watchman.increment("zebra.occupy.home_region_only.unknown")
        true
    end
  end

  defp home_region do
    with region when is_binary(region) <-
           Application.get_env(:zebra, :chmura_secondary_home_region),
         region when region != "" <- String.trim(region) do
      region
    else
      _ -> nil
    end
  end

  @doc """
  The provider for a job whose request is being built, as jobs.request_provider
  stores it: the secondary one's name if its organization has the feature and an
  endpoint is configured, "default" otherwise.
  """
  def request_provider(job), do: provider_for_org(job.organization_id) || @default_provider

  @doc """
  The provider that serves the job's hosted agent, the secondary one or nil for
  the default: the one its request was built for, so a feature change never sends
  a built job elsewhere. Without a secondary endpoint every job uses the default.
  """
  def provider_for(job), do: dispatch_provider(job.request_provider, job.organization_id)

  defp dispatch_provider(stored, org_id) do
    cond do
      is_nil(secondary_endpoint()) -> nil
      stored == @default_provider -> nil
      stored == @secondary_provider -> @secondary_provider
      true -> provider_for_org(org_id)
    end
  end

  defp provider_for_org(org_id) do
    if secondary_endpoint() && secondary_provider_enabled?(org_id) do
      @secondary_provider
    else
      nil
    end
  end

  @doc "Whether an endpoint is configured for the secondary agent provider."
  def secondary_endpoint_configured?, do: secondary_endpoint() != nil

  defp secondary_provider_enabled?(nil), do: false

  defp secondary_provider_enabled?(org_id) do
    FeatureProvider.feature_enabled?(@secondary_provider_feature, param: org_id)
  end

  defp secondary_endpoint do
    case Application.get_env(:zebra, :chmura_secondary_endpoint) do
      endpoint when is_binary(endpoint) and endpoint != "" -> endpoint
      _ -> nil
    end
  end

  # Errors from the secondary provider are tagged, so the dispatcher can tell them
  # from the default provider's and keep serving other organizations' jobs.
  defp occupy_error(@secondary_provider, error), do: {:secondary_provider, error}
  defp occupy_error(_default, error), do: error

  defp connect(@secondary_provider) do
    case secondary_endpoint() do
      nil -> {:error, "no endpoint is configured for the secondary agent provider"}
      endpoint -> GRPC.Stub.connect(endpoint)
    end
  end

  defp connect(_default) do
    endpoint = Application.fetch_env!(:zebra, :chmura_endpoint)

    {:ok, channel} = GRPC.Stub.connect(endpoint)
    {:ok, channel}
  end

  defp error_message(%{message: message}), do: message
  defp error_message(message) when is_binary(message), do: message
  defp error_message(error), do: inspect(error)

  @spec translate_machine(job :: Zebra.Models.Job.t()) :: {String.t(), String.t()}
  defp translate_machine(job) do
    original_type = job.machine_type || ""
    original_os_image = job.machine_os_image || ""

    cond do
      e1_family?(original_type) and e1_to_f1_migration_enabled?(job.organization_id) ->
        {new_type, new_os_image} = attempt_mapping_to_f1(original_type, original_os_image)

        Watchman.increment(
          {"zebra.occupy.translation", [original_type, new_type, job.organization_id]}
        )

        {new_type, new_os_image}

      e2_family?(original_type) and e2_to_f1_migration_enabled?(job.organization_id) ->
        {new_type, new_os_image} = attempt_mapping_to_f1(original_type, original_os_image)

        Watchman.increment(
          {"zebra.occupy.translation", [original_type, new_type, job.organization_id]}
        )

        {new_type, new_os_image}

      true ->
        {original_type, original_os_image}
    end
  end

  @spec attempt_mapping_to_f1(String.t(), String.t()) :: {String.t(), String.t()}
  defp attempt_mapping_to_f1(original_type, original_os_image) do
    original_type
    |> case do
      "e1-standard-2" ->
        {"f1-standard-2", original_os_image}

      "e1-standard-4" ->
        {"f1-standard-2", original_os_image}

      "e1-standard-8" ->
        {"f1-standard-4", original_os_image}

      "e2-standard-2" ->
        {"f1-standard-2", original_os_image}

      "e2-standard-4" ->
        {"f1-standard-4", original_os_image}

      _ ->
        {original_type, original_os_image}
    end
  end

  @spec e1_to_f1_migration_enabled?(nil | String.t()) :: boolean()
  defp e1_to_f1_migration_enabled?(nil), do: false

  defp e1_to_f1_migration_enabled?(org_id) do
    FeatureProvider.feature_enabled?("e1_to_f1_migration", param: org_id)
  end

  @spec e1_family?(String.t()) :: boolean()
  defp e1_family?(machine_type) when is_binary(machine_type) do
    String.starts_with?(machine_type, "e1-")
  end

  defp e1_family?(_), do: false

  @spec e2_family?(String.t()) :: boolean()
  defp e2_family?(machine_type) when is_binary(machine_type) do
    String.starts_with?(machine_type, "e2-")
  end

  defp e2_family?(_), do: false

  @spec e2_to_f1_migration_enabled?(nil | String.t()) :: boolean()
  defp e2_to_f1_migration_enabled?(nil), do: false

  defp e2_to_f1_migration_enabled?(org_id) do
    FeatureProvider.feature_enabled?("e2_to_f1_migration", param: org_id)
  end
end
