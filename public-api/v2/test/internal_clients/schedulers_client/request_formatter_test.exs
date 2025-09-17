defmodule InternalClients.Schedulers.RequestFormatterTest do
  use ExUnit.Case, async: true
  alias InternalClients.Schedulers.RequestFormatter
  alias InternalApi.PeriodicScheduler, as: API

  describe "form_request/1 with RunNowRequest" do
    test "formats request with missing reference defaults to empty" do
      params = %{
        task_id: "task-123",
        requester_id: "user-1",
        pipeline_file: "semaphore.yml"
      }

      {:ok, request} = RequestFormatter.form_request({API.RunNowRequest, params})

      assert request.id == "task-123"
      assert request.requester == "user-1"
      assert request.pipeline_file == "semaphore.yml"
      assert request.reference == "refs/heads/"
    end

    test "formats request with new reference structure for branch" do
      params = %{
        task_id: "task-123",
        requester_id: "user-1",
        reference: %{"type" => "branch", "name" => "feature-branch"},
        pipeline_file: "semaphore.yml"
      }

      {:ok, request} = RequestFormatter.form_request({API.RunNowRequest, params})

      assert request.id == "task-123"
      assert request.requester == "user-1"
      assert request.pipeline_file == "semaphore.yml"
      assert request.reference == "refs/heads/feature-branch"
    end

    test "formats request with new reference structure for tag" do
      params = %{
        task_id: "task-123",
        requester_id: "user-1",
        reference: %{"type" => "tag", "name" => "v1.0.0"},
        pipeline_file: "semaphore.yml"
      }

      {:ok, request} = RequestFormatter.form_request({API.RunNowRequest, params})

      assert request.id == "task-123"
      assert request.requester == "user-1"
      assert request.pipeline_file == "semaphore.yml"
      assert request.reference == "refs/tags/v1.0.0"
    end

    test "defaults reference type to branch when type is unknown" do
      params = %{
        task_id: "task-123",
        requester_id: "user-1",
        reference: %{"type" => "unknown-type", "name" => "some-ref"},
        pipeline_file: "semaphore.yml"
      }

      {:ok, request} = RequestFormatter.form_request({API.RunNowRequest, params})

      # defaults to branch for unknown types
      assert request.reference == "refs/heads/some-ref"
    end
  end

  describe "form_request/1 with PersistRequest" do
    test "formats request with new reference structure for branch" do
      params = %{
        name: "My Task",
        reference: %{"type" => "branch", "name" => "feature-branch"},
        pipeline_file: "semaphore.yml",
        organization_id: "org-1",
        project_id: "proj-1",
        requester_id: "user-1"
      }

      {:ok, request} = RequestFormatter.form_request({API.PersistRequest, params})

      assert request.name == "My Task"
      assert request.reference == "refs/heads/feature-branch"
      assert request.pipeline_file == "semaphore.yml"
    end

    test "formats request with new reference structure for tag" do
      params = %{
        name: "My Task",
        reference: %{"type" => "tag", "name" => "v1.0.0"},
        pipeline_file: "semaphore.yml",
        organization_id: "org-1",
        project_id: "proj-1",
        requester_id: "user-1"
      }

      {:ok, request} = RequestFormatter.form_request({API.PersistRequest, params})

      assert request.name == "My Task"
      assert request.reference == "refs/tags/v1.0.0"
      assert request.pipeline_file == "semaphore.yml"
    end

    test "defaults to empty reference when no reference is provided" do
      params = %{
        name: "My Task",
        pipeline_file: "semaphore.yml",
        organization_id: "org-1",
        project_id: "proj-1",
        requester_id: "user-1"
      }

      {:ok, request} = RequestFormatter.form_request({API.PersistRequest, params})

      assert request.name == "My Task"
      # empty reference default
      assert request.reference == "refs/heads/"
      assert request.pipeline_file == "semaphore.yml"
    end

    test "defaults reference type to branch when type is unknown" do
      params = %{
        name: "My Task",
        reference: %{"type" => "unknown-type", "name" => "some-ref"},
        pipeline_file: "semaphore.yml",
        organization_id: "org-1",
        project_id: "proj-1",
        requester_id: "user-1"
      }

      {:ok, request} = RequestFormatter.form_request({API.PersistRequest, params})

      assert request.name == "My Task"
      # defaults to branch for unknown types
      assert request.reference == "refs/heads/some-ref"
      assert request.pipeline_file == "semaphore.yml"
    end
  end
end
