defmodule Front.Models.ArtifacthubTest do
  use ExUnit.Case

  import Mock

  alias Front.Models.Artifacthub
  alias InternalApi.Artifacthub.ArtifactService.Stub, as: Stub
  alias Support.FakeServices, as: FS
  alias Support.Stubs.DB

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    workflow_id =
      DB.first(:workflows)
      |> Map.get(:id)

    job_id =
      DB.first(:jobs)
      |> Map.get(:id)

    pipeline_id =
      DB.first(:pipelines)
      |> Map.get(:id)

    project_id =
      job_id
      |> Front.Models.Job.find()
      |> Map.get(:project_id)

    [
      job_id: job_id,
      workflow_id: workflow_id,
      project_id: project_id,
      pipeline_id: pipeline_id
    ]
  end

  describe ".list for project" do
    test "when request succeeds, it returns expected response", %{
      project_id: project_id
    } do
      {:ok, artifacts} = Artifacthub.list(project_id, "projects", project_id, "dir/subdir")

      have_proper_structure? =
        artifacts
        |> Enum.all?(fn
          %{is_directory: _, path: _, resource_name: _} -> true
          _ -> false
        end)

      includes_file? =
        artifacts
        |> Enum.any?(&(&1.is_directory == false and &1.resource_name == "README.md"))

      includes_directory? =
        artifacts
        |> Enum.any?(&(&1.is_directory == true and &1.resource_name == "testdir"))

      assert have_proper_structure? == true
      assert includes_file? == true
      assert includes_directory? == true
      assert length(artifacts) == 2
    end

    test "when artifacts listing fails, it returns error", %{
      project_id: project_id
    } do
      error = %GRPC.RPCError{status: 7, message: "Permission denied"}

      with_mock Stub, list_path: fn _c, _r, _o -> {:error, error} end do
        assert Artifacthub.list(project_id, "projects", project_id) == {:error, :grpc_req_failed}
      end
    end
  end

  describe ".list for workflows" do
    test "when request succeeds, it returns expected response", %{
      project_id: project_id,
      workflow_id: workflow_id
    } do
      {:ok, artifacts} = Artifacthub.list(project_id, "workflows", workflow_id, "dir/subdir")

      have_proper_structure? =
        artifacts
        |> Enum.all?(fn
          %{is_directory: _, path: _, resource_name: _} -> true
          _ -> false
        end)

      includes_file? =
        artifacts
        |> Enum.any?(&(&1.is_directory == false and &1.resource_name == "README.md"))

      includes_directory? =
        artifacts
        |> Enum.any?(&(&1.is_directory == true and &1.resource_name == "testdir"))

      assert have_proper_structure? == true
      assert includes_file? == true
      assert includes_directory? == true
      assert length(artifacts) == 2
    end

    test "when artifacts listing fails, it returns error", %{
      project_id: project_id,
      workflow_id: workflow_id
    } do
      error = %GRPC.RPCError{status: 7, message: "Permission denied"}

      with_mock Stub, list_path: fn _c, _r, _o -> {:error, error} end do
        assert Artifacthub.list(project_id, "workflows", workflow_id) ==
                 {:error, :grpc_req_failed}
      end
    end
  end

  describe ".list for pipeline" do
    test "when request succeeds, it returns expected response", %{
      pipeline_id: pipeline_id,
      project_id: project_id
    } do
      {:ok, artifacts} = Artifacthub.list(project_id, "pipelines", pipeline_id, "dir/subdir")

      have_proper_structure? =
        artifacts
        |> Enum.all?(fn
          %{is_directory: _, path: _, resource_name: _} -> true
          _ -> false
        end)

      includes_file? =
        artifacts
        |> Enum.any?(&(&1.is_directory == false and &1.resource_name == "README.md"))

      includes_directory? =
        artifacts
        |> Enum.any?(&(&1.is_directory == true and &1.resource_name == "testdir"))

      assert have_proper_structure? == true
      assert includes_file? == true
      assert includes_directory? == true
      assert length(artifacts) == 2
    end

    test "when artifacts listing fails, it returns error", %{
      pipeline_id: pipeline_id,
      project_id: project_id
    } do
      error = %GRPC.RPCError{status: 7, message: "Permission denied"}

      with_mock Stub, list_path: fn _c, _r, _o -> {:error, error} end do
        assert Artifacthub.list(project_id, "pipelines", pipeline_id) ==
                 {:error, :grpc_req_failed}
      end
    end
  end

  describe ".list for job" do
    test "when request succeeds, it returns expected response", %{
      job_id: job_id,
      project_id: project_id
    } do
      {:ok, artifacts} = Artifacthub.list(project_id, "jobs", job_id, "dir/subdir")

      have_proper_structure? =
        artifacts
        |> Enum.all?(fn
          %{is_directory: _, path: _, resource_name: _} -> true
          _ -> false
        end)

      includes_file? =
        artifacts
        |> Enum.any?(&(&1.is_directory == false and &1.resource_name == "README.md"))

      includes_directory? =
        artifacts
        |> Enum.any?(&(&1.is_directory == true and &1.resource_name == "testdir"))

      assert have_proper_structure? == true
      assert includes_file? == true
      assert includes_directory? == true
      assert length(artifacts) == 2
    end

    test "when artifacts listing fails, it returns error", %{
      job_id: job_id,
      project_id: project_id
    } do
      error = %GRPC.RPCError{status: 7, message: "Permission denied"}

      with_mock Stub, list_path: fn _c, _r, _o -> {:error, error} end do
        assert Artifacthub.list(project_id, "jobs", job_id) == {:error, :grpc_req_failed}
      end
    end
  end

  describe ".destroy" do
    test "it calls the api with correct params", %{project_id: project_id, job_id: job_id} do
      bucket_path = "artifacts/jobs/#{job_id}/tmp/test"
      artifact_path = "tmp/test"

      response = InternalApi.Artifacthub.DeletePathResponse.new()

      FunRegistry.set!(FS.ArtifactService, :delete_path, fn req, _s ->
        assert req.path == bucket_path

        response
      end)

      assert Artifacthub.destroy(project_id, "jobs", job_id, artifact_path)
    end
  end

  describe ".construct" do
    test "returns well formed map for an artifact", %{job_id: job_id} do
      bucket_path = "artifacts/jobs/#{job_id}/test/dir"

      artifact = %InternalApi.Artifacthub.ListItem{
        is_directory: true,
        name: bucket_path
      }

      expected = %Front.Models.Artifacthub{
        is_directory: true,
        path: "test/dir",
        resource_name: "dir"
      }

      assert Artifacthub.construct(artifact, "jobs", job_id) == expected
    end
  end

  describe ".fetch_file" do
    test "returns content of the file for existing files", %{job_id: job_id} do
      path = "dir/subdir/README.md"
      expected_url = "http://some/path/dir/subdir/README.md"

      with_mock HTTPoison, get: fn url -> mocked_get(url, expected_url) end do
        assert Artifacthub.fetch_file("store_id", "jobs", job_id, path) == {:ok, "Hello world"}
      end
    end

    test "returns error if the file does not exist" do
      path = "dir/non-existing-file.txt"

      assert {:error, :grpc_req_failed} =
               Artifacthub.fetch_file("store_id", "jobs", UUID.uuid4(), path)
    end

    test "returns error if fetching the file from signed url fails", %{job_id: job_id} do
      path = "dir/subdir/README.md"

      with_mock HTTPoison, get: fn _ -> {:error, "Server is temporarry unavaialble."} end do
        assert error = Artifacthub.fetch_file("store_id", "jobs", job_id, path)
        assert error == {:error, "Server is temporarry unavaialble."}
      end
    end

    test "returns not_found error if fetching from signed url returns 404 error", %{
      job_id: job_id
    } do
      path = "dir/some_other_file.txt"
      expected_url = "http://some/path/dir/subdir/README.md"

      with_mock HTTPoison, get: fn url -> mocked_get(url, expected_url) end do
        assert error = Artifacthub.fetch_file("store_id", "jobs", job_id, path)
        assert error == {:error, {:not_found, "Invalid url"}}
      end
    end
  end

  defp mocked_get(url, expected_url) do
    if url == expected_url do
      {:ok, %{status_code: 200, body: "Hello world"}}
    else
      {:ok, %{status_code: 404, body: "Invalid url"}}
    end
  end
end
