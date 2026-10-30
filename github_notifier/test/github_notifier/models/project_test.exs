defmodule GithubNotifier.Models.ProjectTest do
  use ExUnit.Case

  alias GithubNotifier.Models.Project

  describe ".find" do
    test "when the project can be found by name => returns the project" do
      project = Support.Factories.project()

      response =
        struct(InternalApi.Projecthub.DescribeResponse,
          metadata: Support.Factories.response_meta(),
          project: project
        )

      GrpcMock.stub(ProjecthubMock, :describe, response)

      assert Project.find(project.metadata.id) == %Project{
               :id => project.metadata.id,
               :org_id => project.metadata.org_id,
               :owner_id => project.metadata.owner_id,
               :url => project.spec.repository.url,
               :repository_id => project.spec.repository.id,
               :status => %{
                 "pipeline_files" => [
                   %{"level" => "PIPELINE", "path" => ".semaphore/semaphore.yml"}
                 ]
               }
             }
    end

    test "tolerates unknown fields on the status message" do
      project = Support.Factories.project()
      status = Map.put(project.spec.repository.status, :__unknown_fields__, [{99, 0, 1}])
      repository = %{project.spec.repository | status: status}
      project = %{project | spec: %{project.spec | repository: repository}}

      response =
        struct(InternalApi.Projecthub.DescribeResponse,
          metadata: Support.Factories.response_meta(),
          project: project
        )

      GrpcMock.stub(ProjecthubMock, :describe, response)

      found = Project.find(project.metadata.id)

      assert found.status["pipeline_files"] == [
               %{"level" => "PIPELINE", "path" => ".semaphore/semaphore.yml"}
             ]

      refute Map.has_key?(found.status, "__unknown_fields__")
    end

    test "when the project can't be found => it returns nil" do
      response =
        struct(InternalApi.Projecthub.DescribeResponse,
          metadata: Support.Factories.response_meta(:NOT_FOUND)
        )

      GrpcMock.stub(ProjecthubMock, :describe, response)

      assert Project.find("231312312312-123-12-312-312") == nil
    end
  end
end
