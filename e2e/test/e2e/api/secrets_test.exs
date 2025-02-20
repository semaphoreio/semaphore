defmodule E2E.API.SecretsTest do
  use ExUnit.Case, async: false

  alias E2E.Clients.{Secret, Project, Workflow}

  describe "organization secrets" do
    test "create and fetch secret" do
      name = "test-secret-#{:rand.uniform(1000)}"
      secret = generate_secret(name)

      {:ok, response} = Secret.list()

      refute Enum.any?(Jason.decode!(response.body)["secrets"], fn s ->
               s["metadata"]["name"] == name
             end)

      {:ok, _} = Secret.create(secret)
      {:ok, response} = Secret.list()

      assert Enum.any?(Jason.decode!(response.body)["secrets"], fn s ->
               s["metadata"]["name"] == name
             end)
    end

    test "secrets are propagated into a project" do
      name = "test-secret-1"
      secret = generate_secret(name)
      {:ok, _} = Secret.create(secret)

      organization = Application.get_env(:e2e, :github_organization)
      repository = Application.get_env(:e2e, :github_repository)
      name = "test-project-#{:rand.uniform(1_000_000)}"
      repository_url = "git@github.com:#{organization}/#{repository}.git"
      {:ok, project} = Support.prepare_project(name, repository_url)
      
      on_exit(fn ->
        :ok = Project.delete(name)
      end)

      params = %{
        project_id: project["metadata"]["id"],
        reference: Application.get_env(:e2e, :github_branch),
        commit_sha: "HEAD",
        pipeline_file: unquote(".semaphore/secrets.yaml")
      }

      {:ok, workflow} = Workflow.trigger(params)
      workflow_id = workflow["workflow_id"]

      assert {:ok, pipelines} = Support.wait_for_workflow_to_finish(workflow_id)

      Enum.each(pipelines, fn pipeline ->
        assert pipeline["wf_id"] == workflow_id
        assert pipeline["result"] == "PASSED"
      end)
    end
  end

  defp generate_secret(name) do
    %{
      metadata: %{
        name: name
      },
      data: %{
        env_vars: [
          %{
            name: "TEST_ENV_NAME",
            value: "test_env_value"
          }
        ],
        files: [
          %{
            path: "test_file.txt",
            # content: "test_file_content", just base 64 encoded
            content: "dGVzdF9maWxlX2NvbnRlbnQ="
          }
        ]
      }
    }
  end
end
