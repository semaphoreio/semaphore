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
end
