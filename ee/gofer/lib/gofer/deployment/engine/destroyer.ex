defmodule Gofer.Deployment.Engine.Destroyer do
  @moduledoc """
  Listens to project deletion events and deletes all deployments for the project
  """
  require Logger

  alias Gofer.Deployment.Model.DeploymentQueries
  alias Gofer.Deployment.Engine.Supervisor

  use Tackle.Consumer,
    url: Application.get_env(:gofer, :amqp_url),
    service: "gofer.dt.destroyer",
    exchange: "project_exchange",
    routing_key: "deleted"

  @metric_name "dt.destroyer.duration"
  @log_prefix "[dt_destroyer] "

  def handle_message(message) do
    Watchman.benchmark({@metric_name, ["project"]}, fn ->
      event = InternalApi.Projecthub.ProjectDeleted.decode(message)

      log("Processing project: #{event.project_id}")

      {deleted, error} =
        DeploymentQueries.list_by_project(event.project_id)
        |> Enum.map(&delete_dt/1)
        |> Enum.reduce({0, 0}, &count_deleted/2)

      log("Deleted #{deleted} deployments for project: #{event.project_id} with #{error} errors")
    end)
  end

  def delete_dt(deployment) do
    unique_token = Ecto.UUID.generate()

    with {:ok, deployment} <-
           DeploymentQueries.delete(deployment.id, unique_token, %{
             requester_id: "project-dt-destroyer",
             unique_token: unique_token
           }),
         {:ok, _pid} <- Supervisor.start_worker(deployment.id) do
      {:ok, deployment.id}
    else
      {:error, :not_found} ->
        {:ok, deployment.id}

      {:error, reason} ->
        Logger.error(@log_prefix <> "Delete deployment target failed",
          extra: log_meta(deployment),
          reason: inspect(reason)
        )

        Watchman.increment("Gofer.deployments.destroyer.errors")

        {:error, reason}
    end
  end

  defp count_deleted({:ok, _}, _acc = {deleted, error}), do: {deleted + 1, error}
  defp count_deleted({:error, _}, _acc = {deleted, error}), do: {deleted, error + 1}

  defp log(message), do: Logger.info(@log_prefix <> message)
  defp log_meta(deployment), do: inspect(deployment_id: deployment.id)
end
