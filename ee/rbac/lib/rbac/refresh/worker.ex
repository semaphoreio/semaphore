defmodule Rbac.Refresh.Worker do
  @moduledoc """
  Refreshing collaborators in an organization can take a significant
  amount of time and API calls to GitHub.

  This worker is an implementation of a statefull approach to the
  refresh action, which allows us to backoff in case of resource shortage,
  and to be alerted if anything gets stuck.
  """

  alias Rbac.Toolbox.{Periodic, Parallel, Duration}
  require Logger

  use Periodic

  def init(_opts) do
    super(%{
      name: "refresh_collaborators_worker",
      naptime: Duration.seconds(60),
      timeout: Duration.minutes(5)
    })
  end

  def perform do
    pending = load_pending()

    Watchman.submit("refresh.worker.requests.count", length(pending))

    pending |> Parallel.in_batches([batch_size: 10], &process_one/1)
  end

  def perform(request_id) do
    process_one(request_id)
  end

  #
  # The process one could be a bit complicated.
  # In short:
  #
  # 1. We open a transaction
  # 2. Referesh projects one-by-one
  # 3. After each project refresh we set a transaction savepoint
  #
  # Pseudocode
  #
  # OPEN TRANSACTION
  #
  #   for project in projects do
  #     err = refresh(project)
  #
  #     if has_err(err) {
  #       rollback_to_last_checkpoint()
  #       break
  #     }
  #
  #     set_savepoint()
  #   end
  #
  # COMMIT
  #

  defp process_one(request_id) do
    load_with_lock(request_id, [timeout: :infinity], fn request ->
      # request = load(request_id)
      refresh_projects(request, request.remaining_project_ids)
    end)
  end

  @savepoint_name "refresh_projects_savepoint"

  defp refresh_projects(request, []) do
    Watchman.increment("refresh.worker.request.done")
    request |> changeset(%{state: :done}) |> update()
  end

  defp refresh_projects(request, [project_id | rest]) do
    case Rbac.Refresh.Project.refresh_one(project_id) do
      :ok ->
        {:ok, request} = changeset(request, %{remaining_project_ids: rest}) |> update()

        Rbac.Repo.query("SAVEPOINT #{@savepoint_name}")

        refresh_projects(request, request.remaining_project_ids)

      e ->
        Watchman.increment("refresh.worker.error")

        Logger.error("Error while refreshing projects #{inspect(e)}")
        Rbac.Repo.query("ROLLBACK TO SAVEPOINT #{@savepoint_name}")
    end
  end

  defdelegate load_pending, to: Rbac.Repo.CollaboratorRefreshRequest
  defdelegate load_with_lock(id, options, fun), to: Rbac.Repo.CollaboratorRefreshRequest
  # defdelegate load(id), to: Rbac.Repo.CollaboratorRefreshRequest
  defdelegate changeset(record, params), to: Rbac.Repo.CollaboratorRefreshRequest

  def update(request), do: Rbac.Repo.update(request)
end
