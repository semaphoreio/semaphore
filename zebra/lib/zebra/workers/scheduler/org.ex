defmodule Zebra.Workers.Scheduler.Org do
  require Logger

  @doc """
  Represents the currently known values for quotas. The actual values are
  loaded from the Organization API and cached for 15 minutes.
  """

  # 15 minutes
  @cache_timeout :timer.minutes(15)

  defstruct [:id, :username, :suspended, :verified, :machines, :features]

  @doc """
  Returns quota information for the given organization.

  {:ok, quotas} on success.
  """
  def load(org_id) do
    Zebra.Cache.fetch!("quotas-#{org_id}-v4", @cache_timeout, fn ->
      result =
        Wormhole.capture(__MODULE__, :fetch_org, [org_id],
          timeout: 10_500,
          stacktrace: true,
          skip_log: true
        )

      case result do
        {:ok, {:ok, org}} ->
          {:commit, {:ok, new(org, org_id)}}

        {:ok, error} ->
          {:ignore, error}

        error ->
          {:ignore, error}
      end
    end)
  end

  def fetch_org(org_id) do
    alias InternalApi.Organization.DescribeRequest, as: Request
    alias InternalApi.Organization.OrganizationService.Stub

    Watchman.benchmark("external.org_api.quotas.cold_load", fn ->
      req = Request.new(org_id: org_id)

      {:ok, ep} = Application.fetch_env(:zebra, :organization_api_endpoint)
      {:ok, ch} = GRPC.Stub.connect(ep)

      res = Stub.describe(ch, req, timeout: 3_000)

      case res do
        {:ok, res} ->
          if res.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
            {:ok, res.organization}
          else
            Logger.error(inspect(res))
            {:error, res}
          end

        {:error, e} ->
          Logger.error("Error fetching organization quotas: #{inspect(e)}")
          {:error, e}
      end
    end)
  end

  def new(org, org_id) do
    %__MODULE__{
      id: org_id,
      username: org.org_username,
      suspended: org.suspended,
      verified: org.verified
    }
  end

  def max_running_jobs(org_id) do
    FeatureProvider.feature_quota("max_paralellism_in_org", param: org_id)
  end

  def machine_quota(org_id, machine_type) do
    FeatureProvider.machine_quota("#{machine_type}", param: org_id)
  end
end
