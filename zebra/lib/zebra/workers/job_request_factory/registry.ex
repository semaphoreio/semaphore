defmodule Zebra.Workers.JobRequestFactory.Registry do
  @moduledoc """
  Temporary container registry credentials for the organization's repositories.
  Like the cache, it never fails the job: without credentials, the job gets no
  registry variables.
  """

  require Logger

  alias InternalApi.Registry.GetCredentialsRequest, as: Request
  alias InternalApi.Registry.RegistryService.Stub
  alias Zebra.Workers.JobRequestFactory.{Cache, JobRequest}

  def find(org_id, repo_proxy, min_validity_seconds) do
    Watchman.benchmark("external.cachehub.get_registry_credentials", fn ->
      req = Request.new(organization_id: org_id, min_validity_seconds: min_validity_seconds)

      # Jobs of forked pull requests get no registry credentials, approved or not.
      with false <- Cache.forked_pr?(repo_proxy),
           {:ok, endpoint} <- Application.fetch_env(:zebra, :cachehub_api_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, response} <- grpc_get_credentials(channel, req) do
        handle_response(response, org_id)
      else
        true ->
          skipped(:forked_pr)
          {:ok, nil}

        e ->
          Logger.warning(
            "Failed to fetch registry credentials from cachehub. org_id=#{org_id} error=#{inspect(e)}"
          )

          failed(:grpc_error)
          {:ok, nil}
      end
    end)
  end

  @doc """
  A job that sets any SEMAPHORE_REGISTRY_* variable itself gets none of these,
  so its own registry settings are never mixed with them.
  """
  def env_vars(credentials, job_env_var_names \\ [])

  def env_vars(nil, _job_env_var_names), do: {:ok, []}

  def env_vars(credentials, job_env_var_names) do
    if Enum.any?(job_env_var_names, &registry_env_var?/1) do
      {:ok, []}
    else
      {:ok,
       [
         JobRequest.env_var("SEMAPHORE_REGISTRY_HOST", credentials.host),
         JobRequest.env_var("SEMAPHORE_REGISTRY_URL", url(credentials)),
         JobRequest.env_var("SEMAPHORE_REGISTRY_USERNAME", credentials.username),
         JobRequest.env_var("SEMAPHORE_REGISTRY_PASSWORD", credentials.password)
       ]}
    end
  end

  defp url(credentials),
    do: "#{credentials.host}/#{String.trim(credentials.repository_prefix, "/")}"

  defp grpc_get_credentials(channel, req),
    do: Stub.get_credentials(channel, req, timeout: 30_000),
    after: GRPC.Stub.disconnect(channel)

  defp handle_response(response, org_id) do
    required = [
      response.host,
      response.repository_prefix,
      response.username,
      response.password
    ]

    cond do
      not ok?(response) ->
        Logger.warning(
          "Cachehub returned non-OK status for registry credentials. org_id=#{org_id} status_code=#{inspect(status_code(response))}"
        )

        failed(:non_ok_response)
        {:ok, nil}

      Enum.any?(required, &blank?/1) ->
        Logger.warning("Cachehub returned incomplete registry credentials. org_id=#{org_id}")

        failed(:incomplete_credentials)
        {:ok, nil}

      true ->
        {:ok, response}
    end
  end

  defp ok?(%{status: %{code: code}}), do: code == InternalApi.ResponseStatus.Code.value(:OK)
  defp ok?(_response), do: false

  defp status_code(%{status: %{code: code}}), do: code
  defp status_code(_response), do: nil

  defp blank?(nil), do: true
  defp blank?(value), do: String.trim(value) == ""

  defp registry_env_var?(name) when is_binary(name),
    do: String.starts_with?(String.upcase(name), "SEMAPHORE_REGISTRY_")

  defp registry_env_var?(_name), do: false

  defp failed(reason) do
    Watchman.increment({"external.cachehub.get_registry_credentials.failed", [to_string(reason)]})
  end

  defp skipped(reason) do
    Watchman.increment(
      {"external.cachehub.get_registry_credentials.skipped", [to_string(reason)]}
    )
  end
end
