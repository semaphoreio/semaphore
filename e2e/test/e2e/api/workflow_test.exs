defmodule E2E.API.WorkflowTest do
  use ExUnit.Case, async: false

  @moduletag timeout: 300_000

  require Logger
  alias E2E.Clients.{Project, Workflow, Pipeline, Job}

  #
  # This module allows you to test multiple YAMLs already present in a GitHub repository.
  # It creates a workflow for the YAML specified, and ensures the workflow finishes successfully.
  #
  # On CI, we use https://github.com/rt-on-prem-tester-org/e2e-tests.
  # Just include the YAML you want to be tested in that repository,
  # and then include the path to it in the list below.
  #
  # For all the tests in this module, a single Semaphore project is created and shared,
  # being deleted after all the tests are finished.
  #

  setup_all do
    organization = Application.get_env(:e2e, :github_organization)
    repository = Application.get_env(:e2e, :github_repository)
    name = "test-project-#{:rand.uniform(1_000_000)}"
    repository_url = "git@github.com:#{organization}/#{repository}.git"
    {:ok, project} = Support.prepare_project(name, repository_url)

    on_exit(fn ->
      :ok = Project.delete(name)
    end)

    {:ok, project_id: project["metadata"]["id"]}
  end

  [
    ".semaphore/hello-world.yaml",
    ".semaphore/cache.yaml",
    ".semaphore/artifacts.yaml",
    ".semaphore/default-image.yaml"
  ]
  |> Enum.each(fn pipeline_file ->
    test "#{pipeline_file} works", %{project_id: project_id} do
      params = %{
        project_id: project_id,
        reference: Application.get_env(:e2e, :github_branch),
        commit_sha: "HEAD",
        pipeline_file: unquote(pipeline_file)
      }

      {:ok, workflow} = Workflow.trigger(params)
      workflow_id = workflow["workflow_id"]

      assert {:ok, pipelines} = Support.wait_for_workflow_to_finish(workflow_id)

      Enum.each(pipelines, fn pipeline ->
        if pipeline["result"] != "PASSED" do
          {:ok, job_ids} = Pipeline.failed_jobs_id(pipeline["ppl_id"])
          Enum.each(job_ids, fn job_id ->
            {:ok, events} = Job.events(job_id)
            Enum.each(events, fn event -> IO.puts(inspect(event)) end)
          end)
        end

        assert pipeline["wf_id"] == workflow_id
        assert pipeline["result"] == "PASSED"
      end)
    end
  end)
end
