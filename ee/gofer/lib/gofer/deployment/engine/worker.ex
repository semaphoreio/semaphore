defmodule Gofer.Deployment.Engine.Worker do
  @moduledoc """
  Worker logic for synchronizing DT secrets with Secrethub
  """

  use GenServer, restart: :transient
  require Logger

  alias Gofer.Deployment.Model.DeploymentQueries
  alias Gofer.Deployment.Model.Deployment
  alias Deployment.EncryptedSecret

  alias Gofer.SecrethubClient

  @ttl_seconds 150
  @wait_time 5_000

  def start_link(deployment_id) do
    name = {:global, {__MODULE__, deployment_id}}
    GenServer.start_link(__MODULE__, deployment_id, name: name)
  end

  def init(deployment_id) do
    Logger.metadata(extra: inspect(deployment_id: deployment_id))
    Kernel.send(self(), :run)

    {:ok, deployment_id}
  end

  def handle_info(:run, deployment_id = state) do
    result =
      Watchman.benchmark("Gofer.deployments.engine.syncing", fn ->
        case DeploymentQueries.find_by_id(deployment_id) do
          {:ok, deployment} -> synchronize(deployment)
          {:error, :not_found} -> {:error, :not_found}
        end
      end)

    case result do
      {:ok, %Deployment{}} ->
        Logger.debug("deployment secret synced")
        Watchman.increment("Gofer.deployments.engine.synced")

        {:stop, :normal, state}

      {:error, reason = :already_synced} ->
        Logger.warn("deployment secret already synced")

        {:stop, {:shutdown, reason}, state}

      {:error, reason = :not_found} ->
        Logger.warn("deployment not found")

        {:stop, {:shutdown, reason}, state}

      {:error, reason = :ttl_exceeded} ->
        Logger.warn("deployment secret sync TTL exceeded")
        Watchman.increment("Gofer.deployments.engine.unsynced")

        {:stop, {:shutdown, reason}, state}

      {:error, reason} ->
        Logger.error("deployment sync failed", reason: inspect(reason))
        Watchman.increment("Gofer.deployments.engine.errors")

        Process.sleep(@wait_time)
        {:stop, {:restart, reason}, state}
    end
  end

  defp synchronize(%Deployment{state: :FINISHED}),
    do: {:error, :already_synced}

  defp synchronize(deployment = %Deployment{encrypted_secret: secret = %EncryptedSecret{}}) do
    request_type = secret.request_type

    case sync_secret(secret.request_type, gather_args(deployment)) do
      {:ok, response} -> resolve(deployment, request_type, response)
      {:error, reason} -> check_deadline(deployment, reason)
    end
  end

  defp gather_args(deployment = %Deployment{encrypted_secret: secret = %EncryptedSecret{}}) do
    [
      organization_id: deployment.organization_id,
      target_id: deployment.id,
      secret_id: deployment.secret_id,
      secret_name: secret_name(deployment),
      user_id: secret.requester_id,
      request_id: secret.unique_token,
      key_id: secret.key_id,
      aes256_key: secret.aes256_key,
      init_vector: secret.init_vector,
      payload: secret.payload
    ]
  end

  defp secret_name(%Deployment{id: id, secret_name: name}) when is_nil(name) or name == "",
    do: "DT" <> (id |> :erlang.md5() |> Base.encode16(case: :lower))

  defp secret_name(%Deployment{secret_name: name}), do: name

  defp sync_secret(request_type, request_args) do
    Kernel.apply(SecrethubClient, request_type, [request_args])
  end

  defp check_deadline(deployment = %Deployment{updated_at: updated_at}, reason) do
    elapsed_seconds = NaiveDateTime.utc_now() |> NaiveDateTime.diff(updated_at)

    if elapsed_seconds > @ttl_seconds do
      DeploymentQueries.fail_syncing(deployment, reason)
      {:error, :ttl_exceeded}
    else
      {:error, reason}
    end
  end

  defp resolve(deployment, :create, response),
    do: DeploymentQueries.pass_syncing(deployment, response)

  defp resolve(deployment, :update, response),
    do: DeploymentQueries.pass_syncing(deployment, response)

  defp resolve(deployment, :delete, _response),
    do: DeploymentQueries.prune_permanently(deployment)
end
