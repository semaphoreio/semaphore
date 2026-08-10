defmodule RepositoryHub.UniversalAdapterTest do
  use ExUnit.Case, async: true
  alias RepositoryHub.UniversalAdapter

  alias InternalApi.Projecthub.Project.Spec.Repository.Status

  doctest UniversalAdapter

  describe "fetch_commit_status/1" do
    test "keeps pipeline files and trigger settings from the status" do
      request =
        build_request(
          commit_status: %Status{
            pipeline_files: [
              %Status.PipelineFile{path: ".semaphore/semaphore.yml", level: :PIPELINE}
            ],
            skip_scheduled_run: true,
            skip_manual_run: true
          }
        )

      assert %{
               "pipeline_files" => [%{"path" => ".semaphore/semaphore.yml", "level" => "pipeline"}],
               "skip_scheduled_run" => true,
               "skip_manual_run" => true
             } == UniversalAdapter.fetch_commit_status(request)
    end

    test "keeps trigger settings when pipeline files are empty" do
      request =
        build_request(
          pipeline_file: ".semaphore/custom.yml",
          commit_status: %Status{pipeline_files: [], skip_manual_run: true}
        )

      assert %{
               "pipeline_files" => [%{"path" => ".semaphore/custom.yml", "level" => "pipeline"}],
               "skip_scheduled_run" => false,
               "skip_manual_run" => true
             } == UniversalAdapter.fetch_commit_status(request)
    end

    test "falls back to default pipeline file without trigger settings when status is missing" do
      request = build_request(commit_status: nil)

      assert %{
               "pipeline_files" => [%{"path" => ".semaphore/semaphore.yml", "level" => "pipeline"}]
             } == UniversalAdapter.fetch_commit_status(request)
    end

    test "round-trips trigger settings through the repository model" do
      request =
        build_request(
          commit_status: %Status{
            pipeline_files: [
              %Status.PipelineFile{path: ".semaphore/semaphore.yml", level: :BLOCK}
            ],
            skip_scheduled_run: true,
            skip_manual_run: true
          }
        )

      commit_status = UniversalAdapter.fetch_commit_status(request)

      model = RepositoryHub.RepositoryModelFactory.build_repository(commit_status: commit_status)
      status = RepositoryHub.Model.Repositories.to_grpc_model(model).commit_status

      assert status.skip_scheduled_run
      assert status.skip_manual_run
      assert [%Status.PipelineFile{path: ".semaphore/semaphore.yml", level: :BLOCK}] == status.pipeline_files
    end

    defp build_request(params) do
      struct(
        InternalApi.Repository.CreateRequest,
        Keyword.merge([pipeline_file: ".semaphore/semaphore.yml"], params)
      )
    end
  end
end
