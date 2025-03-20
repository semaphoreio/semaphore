defmodule Support.Factories.Job do
  alias Zebra.Models.Job
  alias Zebra.LegacyRepo

  #
  # This @timestamp is generated and saved when the module is compiled.
  # We using cache for docker image in tests, so the tests will fail when
  # one would push changes that won't force the image to be rebuild.
  # It will also fail when we will rebuild the workflow the next day
  #
  @timestamp DateTime.utc_now() |> DateTime.truncate(:second)
  def timestamp do
    @timestamp
    |> NaiveDateTime.to_erl()
    |> :calendar.datetime_to_gregorian_seconds()
    |> Kernel.-(62_167_219_200)
  end

  @org_id Ecto.UUID.generate()
  @workflow_id Ecto.UUID.generate()
  @project_id Ecto.UUID.generate()
  @build_id Ecto.UUID.generate()
  @build_server_id Ecto.UUID.generate()
  @agent_id Ecto.UUID.generate()

  def workflow_id, do: @workflow_id
  def org_id, do: @org_id
  def project_id, do: @project_id

  @spec create(:enqueued | :finished | :pending | :scheduled | :started, map) :: any
  def create(state, params \\ %{})

  def create(state = :pending, params) do
    changeset =
      Job.changeset(
        %Job{},
        Map.merge(
          %{
            organization_id: @org_id,
            project_id: @project_id,
            build_id: @build_id,
            index: 0,
            machine_type: "e1-standard-2",
            machine_os_image: "ubuntu1804",
            name: "RSpec 1/3",
            spec: Job.encode_spec(spec()),
            aasm_state: Atom.to_string(state),
            created_at: @timestamp,
            updated_at: @timestamp
          },
          params
        )
      )

    LegacyRepo.insert(changeset)
  end

  def create(state = :enqueued, params) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    changeset =
      Job.changeset(
        %Job{},
        Map.merge(
          %{
            organization_id: @org_id,
            project_id: @project_id,
            build_id: @build_id,
            index: 0,
            machine_type: "e1-standard-2",
            machine_os_image: "ubuntu1804",
            name: "RSpec 1/3",
            spec: Job.encode_spec(spec()),
            aasm_state: Atom.to_string(state),
            created_at: @timestamp,
            updated_at: @timestamp,
            enqueued_at: now
          },
          params
        )
      )

    LegacyRepo.insert(changeset)
  end

  def create(state = :scheduled, params) do
    changeset =
      Job.changeset(
        %Job{},
        Map.merge(
          %{
            organization_id: @org_id,
            project_id: @project_id,
            build_id: @build_id,
            build_server_id: @build_server_id,
            index: 0,
            machine_type: "e1-standard-2",
            machine_os_image: "ubuntu1804",
            name: "RSpec 1/3",
            spec: Job.encode_spec(spec()),
            aasm_state: Atom.to_string(state),
            created_at: @timestamp,
            updated_at: @timestamp,
            enqueued_at: @timestamp,
            scheduled_at: @timestamp
          },
          params
        )
      )

    LegacyRepo.insert(changeset)
  end

  def create(state = :"waiting-for-agent", params) do
    changeset =
      Job.changeset(
        %Job{},
        Map.merge(
          %{
            organization_id: @org_id,
            project_id: @project_id,
            build_id: @build_id,
            build_server_id: @build_server_id,
            index: 0,
            machine_type: "s1-local",
            machine_os_image: "",
            name: "RSpec 1/3",
            spec: Job.encode_spec(spec()),
            aasm_state: Atom.to_string(state),
            created_at: @timestamp,
            updated_at: @timestamp,
            enqueued_at: @timestamp,
            scheduled_at: @timestamp
          },
          params
        )
      )

    LegacyRepo.insert(changeset)
  end

  def create(state = :started, params) do
    changeset =
      Job.changeset(
        %Job{},
        Map.merge(
          %{
            organization_id: @org_id,
            project_id: @project_id,
            build_id: @build_id,
            build_server_id: @build_server_id,
            index: 0,
            machine_type: "e1-standard-2",
            machine_os_image: "ubuntu1804",
            port: 60_000,
            name: "RSpec 1/3",
            spec: Job.encode_spec(spec()),
            agent_ip_address: "1.2.3.4",
            agent_ctrl_port: 443,
            agent_auth_token: "lol",
            aasm_state: Atom.to_string(state),
            created_at: @timestamp,
            updated_at: @timestamp,
            enqueued_at: @timestamp,
            scheduled_at: @timestamp,
            started_at: @timestamp
          },
          params
        )
      )

    LegacyRepo.insert(changeset)
  end

  def create(state = :finished, params) do
    changeset =
      Job.changeset(
        %Job{},
        Map.merge(
          %{
            organization_id: @org_id,
            project_id: @project_id,
            build_id: @build_id,
            build_server_id: @build_server_id,
            agent_id: @agent_id,
            index: 0,
            machine_type: "e1-standard-2",
            machine_os_image: "ubuntu1804",
            port: 60_000,
            name: "RSpec 1/3",
            agent_ip_address: "1.2.3.4",
            agent_ctrl_port: 443,
            agent_auth_token: "lol",
            spec: Job.encode_spec(spec()),
            aasm_state: Atom.to_string(state),
            created_at: @timestamp,
            updated_at: @timestamp,
            enqueued_at: @timestamp,
            scheduled_at: @timestamp,
            dispatched_at: @timestamp,
            started_at: @timestamp,
            finished_at: @timestamp
          },
          params
        )
      )

    LegacyRepo.insert(changeset)
  end

  def inject_request(job) do
    changeset =
      Job.changeset(job, %{
        request: %{
          "job_id" => job.id,
          "job_name" => job.name,
          "ssh_public_keys" => [],
          "files" => [],
          "env_vars" => [
            %{"name" => "TERM", "value" => "eHRlcm0="},
            %{"name" => "SEMAPHORE_GIT_BRANCH", "value" => "bWFzdGVy"},
            %{"name" => "SEMAPHORE_GIT_SHA", "value" => "SEVBRA=="}
          ],
          "commands" => [],
          "epilogue_always_commands" => [],
          "epilogue_on_pass_commands" => [],
          "epilogue_on_fail_commands" => [],
          "callbacks" => %{
            "finished" => "",
            "teardown_finished" => ""
          }
        }
      })

    LegacyRepo.update(changeset)
  end

  def spec do
    %Semaphore.Jobs.V1alpha.Job.Spec{
      agent:
        Semaphore.Jobs.V1alpha.Job.Spec.Agent.new(
          machine:
            Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.new(
              type: "e1-standard-2",
              os_image: "ubuntu1804"
            )
        ),
      commands: [],
      env_vars: [
        Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(
          name: "SEMAPHORE_WORKFLOW_ID",
          value: @workflow_id
        ),
        Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(
          name: "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK",
          value: "true"
        )
      ],
      epilogue_always_commands: [],
      files: [],
      project_id: "",
      secrets: []
    }
  end
end
