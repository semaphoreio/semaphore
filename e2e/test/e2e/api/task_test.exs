defmodule E2E.API.TaskTest do
  use ExUnit.Case, async: false

  @moduletag timeout: 300_000

  require Logger
  alias E2E.Clients.Project

  setup do
    organization = Application.get_env(:e2e, :github_organization)
    repository = Application.get_env(:e2e, :github_repository)
    repository_url = "git@github.com:#{organization}/#{repository}.git"
    name = "test-project-#{:rand.uniform(1_000_000)}"

    # Create project with a task
    task_definitions = [%{
      "name" => "test-task",
      "status" => "ACTIVE",
      "description" => "Test periodic task",
      "at" => "0 * * * *",
      "pipeline_file" => ".semaphore/semaphore.yml",
      "branch" => "main",
      "parameters" => []
    }]

    {:ok, created_project} = Support.prepare_project(name, repository_url, task_definitions)
    on_exit(fn ->
      :ok = Project.delete(name)
    end)

    task = created_project["spec"]["tasks"] |> hd
    {:ok,
      project_id: created_project["metadata"]["id"],
      task_id: task["id"]
    }
  end

  test "run task with run_now and wait for completion", %{project_id: project_id, task_id: task_id} do
    # Trigger run_now
    {:ok, response} = E2E.Clients.Task.run_now(task_id)

    assert response["workflow_id"] != nil

    # Wait for workflow to complete
    workflow_id = response["workflow_id"]
    assert {:ok, pipelines} = Support.wait_for_workflow_to_finish(workflow_id)

    # Verify workflow success
    Enum.each(pipelines, fn pipeline ->
      assert pipeline["result"] == "PASSED", "Pipeline #{pipeline["ppl_id"]} failed"
    end)
  end
end
