defmodule Front.ArtifacthubResourceTest do
  use ExUnit.Case

  alias Front.ArtifacthubResource, as: Subject

  @id "ee2e6241-f30b-4892-a0d5-bd900b713430"
  @kind "projects"

  describe ".get_relative_path" do
    test "removes google bucket prefix" do
      bucket_path = "artifacts/projects/#{@id}/test/dir"

      assert Subject.get_relative_path(bucket_path, @kind, @id) == "test/dir"
    end
  end

  describe ".get_name" do
    test "when resource name is file path it returns name" do
      req_path = "artifacts/projects/#{@id}/README.md"

      artifact_item = %InternalApi.Artifacthub.ListItem{
        is_directory: false,
        name: req_path
      }

      assert Subject.get_name(artifact_item, @kind, @id) == "README.md"
    end

    test "when resource name is directory it returns its name" do
      req_path = "artifacts/projects/#{@id}/monorepo/screenshots/failures/"

      artifact_item = %InternalApi.Artifacthub.ListItem{
        is_directory: true,
        name: req_path
      }

      assert Subject.get_name(artifact_item, @kind, @id) == "failures"
    end
  end
end
