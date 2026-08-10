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
                 ],
                 "skip_scheduled_run" => false,
                 "skip_manual_run" => false
               }
             }
    end

    test "carries the commit status trigger settings" do
      project = Support.Factories.project([], skip_scheduled_run: true, skip_manual_run: true)

      response =
        struct(InternalApi.Projecthub.DescribeResponse,
          metadata: Support.Factories.response_meta(),
          project: project
        )

      GrpcMock.stub(ProjecthubMock, :describe, response)

      found = Project.find(project.metadata.id)

      assert found.status["skip_scheduled_run"] == true
      assert found.status["skip_manual_run"] == true
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
