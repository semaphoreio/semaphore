defmodule Badges.Models.ProjectTest do
  use ExUnit.Case

  alias Badges.Models.Project

  describe ".find" do
    test "when the project can't be found => it returns nil" do
      GrpcMock.stub(ProjectMock, :describe, fn _, _ ->
        InternalApi.Projecthub.DescribeResponse.new(
          metadata: Support.Factories.response_meta(:NOT_FOUND)
        )
      end)

      assert Project.find(
               "12345678-1234-5678-0000-010101010101",
               "12345678-1234-5678-0000-010101010101",
               nil
             ) ==
               nil
    end

    test "when the project can be found => it returns the project" do
      project = Support.Factories.project()

      GrpcMock.stub(ProjectMock, :describe, fn _, _ ->
        InternalApi.Projecthub.DescribeResponse.new(
          metadata: Support.Factories.response_meta(:OK),
          project: project
        )
      end)

      assert Project.find(
               "12345678-1234-5678-0000-010101010101",
               "12345678-1234-5678-0000-010101010101",
               nil
             ) ==
               %Project{
                 id: project.metadata.id,
                 pipeline_file: project.spec.repository.pipeline_file,
                 public: project.spec.public
               }
    end
  end
end
