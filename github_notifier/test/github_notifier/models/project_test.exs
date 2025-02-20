defmodule GithubNotifier.Models.ProjectTest do
  use ExUnit.Case

  alias GithubNotifier.Models.Project

  describe ".find" do
    test "when the project can be found by name => returns the project" do
      project = Support.Factories.project()

      response =
        InternalApi.Projecthub.DescribeResponse.new(
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
                   %{"level" => 1, "path" => ".semaphore/semaphore.yml"}
                 ]
               }
             }
    end

    test "when the project can't be found => it returns nil" do
      response =
        InternalApi.Projecthub.DescribeResponse.new(
          metadata: Support.Factories.response_meta(:NOT_FOUND)
        )

      GrpcMock.stub(ProjecthubMock, :describe, response)

      assert Project.find("231312312312-123-12-312-312") == nil
    end
  end
end
