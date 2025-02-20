defmodule Support.MockData do
  require Logger

  def mock do
    project_id = UUID.uuid4()
    org_id = UUID.uuid4()
    hook_id = UUID.uuid4()
    hook = %{id: hook_id, project_id: project_id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
    workflow_id = workflow.id

    pipeline =
      Support.Stubs.Pipeline.create_initial(workflow,
        name: "Pipeline #1",
        commit_sha: "75891a4469488cb714b6931bfd63ecb71180f7ad",
        branch_name: "master",
        working_directory: ".semaphore",
        yaml_file_name: "semaphore.yml"
      )

    info = %{
      project_id: project_id,
      hook_id: hook_id,
      workflow_id: workflow_id,
      pipeline_id: pipeline.id,
      org_id: org_id
    }

    Logger.info("mocked data: #{inspect(info)}")
  end
end
