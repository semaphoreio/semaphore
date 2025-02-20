defmodule Projecthub.AnalysisTest do
  use Projecthub.DataCase

  setup do
    stub_repohub_api()

    {:ok, project} = Support.Factories.Project.create_with_repo()

    project = Projecthub.Repo.preload(project, :sql_repository)

    {:ok, %{project: project}}
  end

  test "it analyzes the repository and returns a report", %{project: project} do
    {:ok, result} = Projecthub.Analysis.run(project.sql_repository)

    assert result == %{
             "docker" => %{"found" => false},
             "node" => %{"found" => false},
             "python" => %{"found" => false},
             "ruby" => %{"found" => true},
             "semaphore_yaml" => %{"found" => false}
           }
  end

  def stub_repohub_api do
    files_response =
      InternalApi.Repository.GetFilesResponse.new(
        files: [
          InternalApi.Repository.File.new(path: "Gemfile", content: "")
        ]
      )

    FunRegistry.set!(Support.FakeServices.Repohub, :get_files, files_response)
  end
end
