defmodule Zebra.Apis.PublicJobApi.DebugTest do
  use Zebra.DataCase
  alias Support.Factories
  alias Zebra.Apis.PublicJobApi.Debug

  @org_id Ecto.UUID.generate()
  @project_id Ecto.UUID.generate()

  describe ".debug_job_params" do
    test "copy everything from job, except commands" do
      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          project_id: @project_id,
          organization_id: @org_id
        })

      {:ok, debug_job_params} = Debug.debug_job_params(job)

      assert debug_job_params == [
               organization_id: @org_id,
               project_id: @project_id,
               index: 0,
               machine_type: job.machine_type,
               machine_os_image: job.machine_os_image,
               execution_time_limit: 3600,
               name: "Debug Session for Job #{job.id}",
               spec:
                 Semaphore.Jobs.V1alpha.Job.Spec.new(
                   agent:
                     Semaphore.Jobs.V1alpha.Job.Spec.Agent.new(
                       machine:
                         Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.new(
                           os_image: "ubuntu1804",
                           type: "e1-standard-2"
                         )
                     ),
                   commands: ["sleep 3600"],
                   files: [
                     Semaphore.Jobs.V1alpha.Job.Spec.File.new(
                       content: "CgoK",
                       path: "commands.sh"
                     )
                   ],
                   env_vars: [
                     Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(
                       name: "SEMAPHORE_WORKFLOW_ID",
                       value: Factories.Job.workflow_id()
                     ),
                     Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(
                       name: "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK",
                       value: "true"
                     )
                   ]
                 )
             ]
    end
  end
end
