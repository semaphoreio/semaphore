defmodule Front.Models.RepositoryIntegrator do
  @moduledoc """
  Module encapsulates functions for communication with repository integrator service.
  """

  alias InternalApi.RepositoryIntegrator.IntegrationType

  require Logger

  def get_repository_token(project, user_id) do
    Watchman.benchmark("repository_integrator.get_token.duration", fn ->
      req =
        InternalApi.RepositoryIntegrator.GetTokenRequest.new(
          project_id: project.id,
          user_id: user_id,
          integration_type: IntegrationType.value(project.integration_type),
          repository_slug: "#{project.repo_owner}/#{project.repo_name}"
        )

      {:ok, channel} =
        GRPC.Stub.connect(Application.fetch_env!(:front, :repository_integrator_grpc_endpoint))

      case InternalApi.RepositoryIntegrator.RepositoryIntegratorService.Stub.get_token(
             channel,
             req,
             timeout: 30_000
           ) do
        {:ok, res} ->
          {:ok, res.token}

        {:error, msg} ->
          Logger.error(
            "[RepositoryIntegrator model] Error while fetching repository token #{inspect(msg)}"
          )

          {:error, msg}
      end
    end)
  end

  @doc """
  Triggers a re-sync of the cached GitHub App repository/collaborator data.

  With an empty `repository_slug` the requesting user's installations are
  re-synced; with an "owner/repository" slug only that repository's data is
  refreshed.
  """
  def refresh_repositories(user_id, repository_slug \\ "", organization \\ "") do
    Watchman.benchmark("repository_integrator.refresh_repositories.duration", fn ->
      req =
        InternalApi.RepositoryIntegrator.RefreshRepositoriesRequest.new(
          user_id: user_id,
          integration_type: IntegrationType.value(:GITHUB_APP),
          repository_slug: repository_slug,
          organization: organization
        )

      case GRPC.Stub.connect(Application.fetch_env!(:front, :repository_integrator_grpc_endpoint)) do
        {:ok, channel} ->
          try do
            send_refresh(channel, req)
          after
            GRPC.Stub.disconnect(channel)
          end

        {:error, reason} ->
          Logger.error(
            "[RepositoryIntegrator model] Error while connecting to refresh repositories #{inspect(reason)}"
          )

          {:error, reason}
      end
    end)
  end

  defp send_refresh(channel, req) do
    case InternalApi.RepositoryIntegrator.RepositoryIntegratorService.Stub.refresh_repositories(
           channel,
           req,
           timeout: 30_000
         ) do
      {:ok, res} ->
        state =
          InternalApi.RepositoryIntegrator.RefreshRepositoriesResponse.SyncState.key(
            res.sync_state
          )

        {:ok, %{state: state, message: res.message}}

      {:error, msg} ->
        Logger.error(
          "[RepositoryIntegrator model] Error while refreshing repositories #{inspect(msg)}"
        )

        {:error, msg}
    end
  end
end
