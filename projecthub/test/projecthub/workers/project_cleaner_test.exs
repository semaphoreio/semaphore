defmodule Projecthub.Workers.ProjectCleanerTest do
  use Projecthub.DataCase
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias Projecthub.Models.Project
  alias Projecthub.Models.Repository
  alias Projecthub.Events
  alias Projecthub.Schedulers
  alias Projecthub.Repo

  describe "process/1" do
    test "Cleaner should only clean soft deleted projects whithin 30 days" do
      not_soft_deleted_projects =
        1..3
        |> Enum.map(fn _ ->
          {:ok, project} = Support.Factories.Project.create_with_repo()
          project.id
        end)

      _long_time_soft_deleted_projects =
        1..3
        |> Enum.map(fn _ ->
          {:ok, project} = Support.Factories.Project.create_with_repo(%{deleted_at: datetime_by_days_ago(31)})
          project.id
        end)

      recent_soft_deleted_projects =
        1..3
        |> Enum.map(fn _ ->
          {:ok, project} = Support.Factories.Project.create_with_repo(%{deleted_at: datetime_by_days_ago(1)})
          project.id
        end)

      with_mocks([
        {Repository, [:passthrough], [destroy: fn r -> {:ok, r} end]},
        {Events.ProjectDeleted, [], [publish: fn _ -> {:ok, nil} end]},
        {Schedulers, [], [delete_all: fn _p, _r -> {:ok, nil} end]},
        {Projecthub.Artifact, [], [destroy: fn _, _ -> nil end]}
      ]) do
        {:ok, _} = Projecthub.Workers.ProjectCleaner.process()

        projects = Project |> Repo.all() |> Enum.map(& &1.id) |> MapSet.new()
        assert projects == MapSet.new(not_soft_deleted_projects ++ recent_soft_deleted_projects)
      end
    end
  end

  defp datetime_by_days_ago(days_ago) do
    DateTime.utc_now()
    |> DateTime.add(-days_ago * 24 * 60 * 60)
    |> DateTime.truncate(:second)
  end
end
