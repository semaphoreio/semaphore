defmodule Projecthub.Workers.ProjectCleanerTest do
  use Projecthub.DataCase

  alias Projecthub.Models.Project
  alias Projecthub.Models.Repository
  alias Projecthub.Events
  alias Projecthub.Schedulers

  describe "process/1" do
    test "Cleaner should only clean soft deleted projects whithin 30 days" do
      _not_soft_deleted_projects =
        1..3
        |> Enum.map(fn _ ->
          {:ok, project} = Support.Factories.Project.create_with_repo()
          project.id
        end)

      long_time_soft_deleted_projects =
        1..3
        |> Enum.map(fn _ ->
          {:ok, project} = Support.Factories.Project.create_with_repo(deleted_at: datetime_by_days_ago(31))
          project.id
        end)

      recent_soft_deleted_projects =
        1..3
        |> Enum.map(fn _ ->
          {:ok, project} = Support.Factories.Project.create_with_repo(deleted_at: datetime_by_days_ago(1))
          project.id
        end)

      Projecthub.Workers.ProjectCleaner.process()

      with_mocks([
        {Repository, [:passthrough], [destroy: fn r -> {:ok, r} end]},
        {Events.ProjectDeleted, [], [publish: fn _ -> {:ok, nil} end]},
        {Schedulers, [], [delete_all: fn _p, _r -> {:ok, nil} end]},
        {Projecthub.Artifact, [], [destroy: fn _, _ -> nil end]}
      ]) do
        {:ok, _} = Projecthub.Workers.ProjectCleaner.process()

        projects = Project |> Repo.select([:id]) |> Repo.all() |> Enum.map(& &1.id) |> MapSet.new()
        assert projects == MapSet.new(not_soft_deleted_projects ++ recent_soft_deleted_projects)
      end
    end
  end

  defp datetime_by_days_ago(days_ago) do
    DateTime.utc_now()
    |> DateTime.add(-days_ago, :day)
    |> DateTime.truncate(:second)
  end
end
