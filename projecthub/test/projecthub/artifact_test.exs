defmodule Projecthub.ArtifactTest do
  use Projecthub.DataCase
  alias Projecthub.Artifact
  alias Projecthub.Models.Project

  describe ".create_for_project" do
    test "when the response is received, it updates the project" do
      {:ok, project} = Support.Factories.Project.create(%{artifact_store_id: nil})
      refute project.artifact_store_id

      artifact_store_id = Ecto.UUID.generate()

      response =
        InternalApi.Artifacthub.CreateResponse.new(
          artifact: InternalApi.Artifacthub.Artifact.new(id: artifact_store_id)
        )

      FunRegistry.set!(Support.FakeServices.ArtifactService, :create, response)

      Artifact.create_for_project(project.id)
      reloaded_project = Project |> Repo.get(project.id)

      assert reloaded_project.artifact_store_id == artifact_store_id
    end

    test "when the response is not received, it doesn't update the project" do
      {:ok, project} = Support.Factories.Project.create(%{artifact_store_id: nil})

      response = {
        :error,
        %GRPC.RPCError{message: "Unknown", status: 2}
      }

      FunRegistry.set!(Support.FakeServices.ArtifactService, :create, response)

      Artifact.create_for_project(project.id)
      reloaded_project = Project |> Repo.get(project.id)

      assert reloaded_project.artifact_store_id == nil
    end
  end
end
