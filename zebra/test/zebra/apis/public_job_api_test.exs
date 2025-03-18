# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Zebra.Api.PublicJobApiTest do
  alias Support.Factories
  use Zebra.DataCase, async: false

  import Mox
  setup :set_mox_global

  @org_id Ecto.UUID.generate()
  @restricted_org_id Ecto.UUID.generate()
  @user_id Ecto.UUID.generate()
  @dt_id Ecto.UUID.generate()
  @job_id Ecto.UUID.generate()

  @authorized_projects [
    Ecto.UUID.generate()
  ]

  @options [
    metadata: %{
      "x-semaphore-user-id" => @user_id,
      "x-semaphore-org-id" => @org_id
    }
  ]

  @options_for_restricted_org [
    metadata: %{
      "x-semaphore-user-id" => @user_id,
      "x-semaphore-org-id" => @restricted_org_id
    }
  ]

  setup do
    GrpcMock.stub(Support.FakeServers.RBAC, :list_accessible_projects, fn _, _ ->
      InternalApi.RBAC.ListAccessibleProjectsResponse.new(project_ids: @authorized_projects)
    end)

    # Stub Auth calls
    GrpcMock.stub(Support.FakeServers.RBAC, :list_user_permissions, fn req, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        user_id: req.user_id,
        org_id: req.org_id,
        project_id: req.project_id,
        permissions: ["random", "project.job.rerun"]
      )
    end)

    GrpcMock.stub(Support.FakeServers.OrganizationApi, :describe, fn req, _ ->
      status = InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))

      restricted =
        case req.org_id do
          @org_id -> false
          @restricted_org_id -> true
        end

      organization =
        InternalApi.Organization.Organization.new(
          org_username: "zebraz-org",
          org_id: req.org_id,
          restricted: restricted
        )

      InternalApi.Organization.DescribeResponse.new(
        status: status,
        organization: organization
      )
    end)

    GrpcMock.stub(Support.FakeServers.RepositoryApi, :describe, fn _, _ ->
      key = "--BEGIN....lalalala..private_key...END---"

      repository =
        InternalApi.Repository.Repository.new(
          name: "test-repo",
          url: "git@github.com:/test-org/test-repo.git",
          provider: "github"
        )

      InternalApi.Repository.DescribeResponse.new(repository: repository, private_ssh_key: key)
    end)

    :ok
  end

  describe ".list_jobs" do
    test "when page_size is too high => it returns error" do
      alias Semaphore.Jobs.V1alpha.ListJobsRequest, as: Request
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request =
        Request.new(
          states: [
            Semaphore.Jobs.V1alpha.Job.Status.State.value(:PENDING)
          ],
          page_size: 5000
        )

      assert {:error, expected_error} = Stub.list_jobs(channel, request, @options)
      assert expected_error == %GRPC.RPCError{message: "Page size can't exceed 30", status: 3}
    end

    test "when every parameter is correct => it returns list of jobs" do
      alias Semaphore.Jobs.V1alpha.ListJobsRequest, as: Request
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          project_id: hd(@authorized_projects),
          organization_id: @org_id
        })

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(states: [Semaphore.Jobs.V1alpha.Job.Status.State.value(:PENDING)])

      {:ok, reply} = channel |> Stub.list_jobs(request, @options)

      assert reply.jobs == [
               %Semaphore.Jobs.V1alpha.Job{
                 metadata: %Semaphore.Jobs.V1alpha.Job.Metadata{
                   create_time: DateTime.to_unix(job.created_at),
                   update_time: DateTime.to_unix(job.updated_at),
                   finish_time: 0,
                   id: job.id,
                   name: "RSpec 1/3",
                   start_time: 0
                 },
                 spec: %Semaphore.Jobs.V1alpha.Job.Spec{
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
                       value: Factories.Job.workflow_id()
                     ),
                     Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(
                       name: "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK",
                       value: "true"
                     )
                   ],
                   epilogue_commands: [],
                   epilogue_always_commands: [],
                   epilogue_on_pass_commands: [],
                   epilogue_on_fail_commands: [],
                   files: [],
                   project_id: "",
                   secrets: []
                 },
                 status: %Semaphore.Jobs.V1alpha.Job.Status{
                   agent: nil,
                   result: Semaphore.Jobs.V1alpha.Job.Status.Result.value(:NONE),
                   state: Semaphore.Jobs.V1alpha.Job.Status.State.value(:PENDING)
                 }
               }
             ]
    end

    test "lists only authorized jobs" do
      alias Semaphore.Jobs.V1alpha.ListJobsRequest, as: Request
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      {:ok, job1} =
        Support.Factories.Job.create(:pending, %{
          project_id: hd(@authorized_projects),
          organization_id: @org_id
        })

      {:ok, _} = Support.Factories.Job.create(:pending, %{organization_id: @org_id})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(states: [Semaphore.Jobs.V1alpha.Job.Status.State.value(:PENDING)])

      {:ok, reply} = channel |> Stub.list_jobs(request, @options)

      assert Enum.map(reply.jobs, & &1.metadata.id) == [job1.id]
    end
  end

  describe ".get_job" do
    alias Semaphore.Jobs.V1alpha.GetJobRequest, as: Request
    alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

    test "when the job_id is not uuid => return invalid argument" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: "1234")

      assert Stub.get_job(channel, request, @options) ==
               {:error, %GRPC.RPCError{message: "Job id 1234 is invalid", status: 3}}
    end

    test "when the job is present and user can access it => returns serialized job" do
      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          project_id: hd(@authorized_projects),
          organization_id: @org_id
        })

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: job.id)

      {:ok, reply} = channel |> Stub.get_job(request, @options)

      assert reply == %Semaphore.Jobs.V1alpha.Job{
               metadata: %Semaphore.Jobs.V1alpha.Job.Metadata{
                 create_time: DateTime.to_unix(job.created_at),
                 update_time: DateTime.to_unix(job.updated_at),
                 finish_time: 0,
                 id: job.id,
                 name: "RSpec 1/3",
                 start_time: 0
               },
               spec: %Semaphore.Jobs.V1alpha.Job.Spec{
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
                     value: Factories.Job.workflow_id()
                   ),
                   Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.new(
                     name: "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK",
                     value: "true"
                   )
                 ],
                 epilogue_commands: [],
                 epilogue_always_commands: [],
                 epilogue_on_pass_commands: [],
                 epilogue_on_fail_commands: [],
                 files: [],
                 project_id: "",
                 secrets: []
               },
               status: %Semaphore.Jobs.V1alpha.Job.Status{
                 agent: nil,
                 result: Semaphore.Jobs.V1alpha.Job.Status.Result.value(:NONE),
                 state: Semaphore.Jobs.V1alpha.Job.Status.State.value(:PENDING)
               }
             }
    end

    test "when the job is not found => returns not found" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: @job_id)

      {:error, reply} = channel |> Stub.get_job(request, @options)

      assert reply == %GRPC.RPCError{
               message: "Job #{@job_id} not found",
               status: 5
             }
    end

    test "when the user is not authorized to see the job => returns not found" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{organization_id: @org_id})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: job.id)

      {:error, reply} = channel |> Stub.get_job(request, @options)

      assert reply == %GRPC.RPCError{message: "Job #{job.id} not found", status: 5}
    end
  end

  describe ".get_job_debug_ssh_key" do
    alias Semaphore.Jobs.V1alpha.GetJobDebugSSHKeyRequest, as: Request
    alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

    test "when the job_id is not uuid => return invalid argument" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: "1234")

      assert Stub.get_job_debug_ssh_key(channel, request, @options) == {
               :error,
               %GRPC.RPCError{message: "Job id 1234 is invalid", status: 3}
             }
    end

    test "when the job is present and running => return key" do
      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:started, %{
          project_id: hd(@authorized_projects),
          private_ssh_key: Zebra.RSA.generate().private_key,
          organization_id: @org_id,
          build_id: task.id
        })

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: job.id)

      {:ok, reply} = channel |> Stub.get_job_debug_ssh_key(request, @options)

      assert reply == %Semaphore.Jobs.V1alpha.JobDebugSSHKey{
               key: job.private_ssh_key
             }
    end

    test "when the job is not found => returns not found" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: @job_id)

      {:error, reply} = channel |> Stub.get_job_debug_ssh_key(request, @options)

      assert reply == %GRPC.RPCError{
               message: "Job #{@job_id} not found",
               status: 5
             }
    end

    test "when the user is not authorized to see the job => returns not found" do
      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:pending, %{organization_id: @org_id, build_id: task.id})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: job.id)

      {:error, reply} = channel |> Stub.get_job_debug_ssh_key(request, @options)

      assert reply == %GRPC.RPCError{
               message: "Job #{job.id} not found",
               status: 5
             }
    end

    test "when job is self-hosted => raise error" do
      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:started, %{
          project_id: hd(@authorized_projects),
          private_ssh_key: nil,
          organization_id: @org_id,
          build_id: task.id,
          machine_type: "s1-hosted-linux"
        })

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: job.id)

      {:error, reply} = channel |> Stub.get_job_debug_ssh_key(request, @options)

      assert reply == %GRPC.RPCError{
               message: "SSH keys are not available for self-hosted jobs",
               status: 7
             }
    end

    test "when the project belongs to restricted org and have default permissions => raise error" do
      mock_repo_proxy(:BRANCH, "master", "test-org/test-repo", "")
      mock_project([], [], false)

      {:ok, task} = Support.Factories.Task.create()

      get_job_debug_ssh_key_fails_permission_check(
        "You are not allowed to attach jobs on the default branch of this project",
        task.id
      )
    end

    test "when the project belongs to restricted org and blocks attach on default branch => raise error" do
      mock_repo_proxy(:BRANCH, "master", "test-org/test-repo", "")
      mock_project([], [])

      {:ok, task} = Support.Factories.Task.create()

      get_job_debug_ssh_key_fails_permission_check(
        "You are not allowed to attach jobs on the default branch of this project",
        task.id
      )
    end

    test "when the project belongs to restricted org and allows attach on default branch => gets the key" do
      alias InternalApi.Projecthub.Project.Spec.PermissionType

      mock_repo_proxy(:BRANCH, "master", "test-org/test-repo", "")
      mock_project([], [PermissionType.value(:DEFAULT_BRANCH)])

      {:ok, task} = Support.Factories.Task.create()
      get_job_debug_ssh_key_passes_permission_check(task.id)
    end

    test "when the project belongs to restricted org and blocks attach on non default branch => raise error" do
      mock_repo_proxy(:BRANCH, "some-non-default-branch", "test-org/test-repo", "")
      mock_project([], [])

      {:ok, task} = Support.Factories.Task.create()

      get_job_debug_ssh_key_fails_permission_check(
        "You are not allowed to attach jobs on non default branches of this project",
        task.id
      )
    end

    test "when the project belongs to restricted org and allows attach on non default branch => gets the key" do
      alias InternalApi.Projecthub.Project.Spec.PermissionType

      mock_repo_proxy(:BRANCH, "some-non-default-branch", "test-org/test-repo", "")
      mock_project([], [PermissionType.value(:NON_DEFAULT_BRANCH)])

      {:ok, task} = Support.Factories.Task.create()
      get_job_debug_ssh_key_passes_permission_check(task.id)
    end

    test "when the project belongs to restricted org and blocks attach on tag => raise error" do
      mock_repo_proxy(:TAG, "", "test-org/test-repo", "")
      mock_project([], [])

      {:ok, task} = Support.Factories.Task.create()

      get_job_debug_ssh_key_fails_permission_check(
        "You are not allowed to attach jobs on a tag of this project",
        task.id
      )
    end

    test "when the project belongs to restricted org and allows attach on tag => gets the key" do
      alias InternalApi.Projecthub.Project.Spec.PermissionType

      mock_repo_proxy(:TAG, "", "test-org/test-repo", "")
      mock_project([], [PermissionType.value(:TAG)])

      {:ok, task} = Support.Factories.Task.create()
      get_job_debug_ssh_key_passes_permission_check(task.id)
    end

    test "when the project belongs to restricted org and blocks attach on pull request => raise error" do
      mock_repo_proxy(:PR, "", "test-org/test-repo", "test-org/test-repo")
      mock_project([], [])

      {:ok, task} = Support.Factories.Task.create()

      get_job_debug_ssh_key_fails_permission_check(
        "You are not allowed to attach jobs on a pull request of this project",
        task.id
      )
    end

    test "when the project belongs to restricted org and allows attach on pull request => gets the key" do
      alias InternalApi.Projecthub.Project.Spec.PermissionType

      mock_repo_proxy(:PR, "", "test-org/test-repo", "test-org/test-repo")
      mock_project([], [PermissionType.value(:PULL_REQUEST)])

      {:ok, task} = Support.Factories.Task.create()
      get_job_debug_ssh_key_passes_permission_check(task.id)
    end

    test "when the project belongs to restricted org and blocks attach on forked pull request => raise error" do
      mock_repo_proxy(:PR, "", "test-org/test-repo", "forked/test-repo")
      mock_project([], [])

      {:ok, task} = Support.Factories.Task.create()

      get_job_debug_ssh_key_fails_permission_check(
        "You are not allowed to attach jobs on a forked pull request of this project",
        task.id
      )
    end

    test "when the project belongs to restricted org and allows attach on forked pull request => gets the key" do
      alias InternalApi.Projecthub.Project.Spec.PermissionType

      mock_repo_proxy(:PR, "", "test-org/test-repo", "forked/test-repo")
      mock_project([], [PermissionType.value(:FORKED_PULL_REQUEST)])

      {:ok, task} = Support.Factories.Task.create()
      get_job_debug_ssh_key_passes_permission_check(task.id)
    end

    test "when the project belongs to restricted org and blocks debug on project => raise error" do
      mock_project([], [])

      get_job_debug_ssh_key_fails_permission_check(
        "You are not allowed to debug this project",
        nil
      )
    end

    test "when the project belongs to restricted org and allows debug on project => gets the key" do
      alias InternalApi.Projecthub.Project.Spec.PermissionType

      mock_project([PermissionType.value(:EMPTY)], [])
      get_job_debug_ssh_key_passes_permission_check(nil)
    end

    test "when the job is not running => return not found" do
      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:finished, %{
          project_id: hd(@authorized_projects),
          private_ssh_key: Zebra.RSA.generate().private_key,
          organization_id: @org_id,
          build_id: task.id
        })

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: job.id)

      {:error, reply} = channel |> Stub.get_job_debug_ssh_key(request, @options)

      assert reply == %GRPC.RPCError{
               message: "Job's debug SSH is only available while the job is running",
               status: 9
             }
    end
  end

  describe ".create_job" do
    alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

    test "empty name => raise error" do
      job =
        Semaphore.Jobs.V1alpha.Job.new(
          metadata: Semaphore.Jobs.V1alpha.Job.Metadata.new(name: ""),
          spec: Semaphore.Jobs.V1alpha.Job.Spec.new(
            agent:
              Semaphore.Jobs.V1alpha.Job.Spec.Agent.new(
                machine:
                  Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.new(
                    type: "e1-standard-2",
                    os_image: "ubuntu1804"
                  )
              ),
            project_id: hd(@authorized_projects)
          )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:error, reply} = channel |> Stub.create_job(job, @options)

      assert reply == %GRPC.RPCError{
               message: "name: can't be blank",
               status: 3
             }
    end

    test "when the user can't create a pipeline => raise error" do
      GrpcMock.stub(Support.FakeServers.RBAC, :list_user_permissions, fn req, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          user_id: req.user_id,
          org_id: req.org_id,
          project_id: req.project_id,
          permissions: ["project.random.permission"]
        )
      end)

      job =
        Semaphore.Jobs.V1alpha.Job.new(
          metadata: Semaphore.Jobs.V1alpha.Job.Metadata.new(name: "RSpec 1/3"),
          spec:
            Semaphore.Jobs.V1alpha.Job.Spec.new(
              agent:
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.new(
                  machine:
                    Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.new(
                      type: "e1-standard-2",
                      os_image: "ubuntu1804"
                    )
                ),
              project_id: hd(@authorized_projects)
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:error, reply} = channel |> Stub.create_job(job, @options)

      assert reply == %GRPC.RPCError{
               message: "You are not allowed to run pipelines on this project",
               status: 7
             }
    end

    test "when the user can access the project => creates job" do
      job =
        Semaphore.Jobs.V1alpha.Job.new(
          metadata: Semaphore.Jobs.V1alpha.Job.Metadata.new(name: "RSpec 1/3"),
          spec:
            Semaphore.Jobs.V1alpha.Job.Spec.new(
              agent:
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.new(
                  machine:
                    Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.new(
                      type: "e1-standard-2",
                      os_image: "ubuntu1804"
                    )
                ),
              project_id: hd(@authorized_projects)
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:ok, reply} = channel |> Stub.create_job(job, @options)

      assert reply.metadata.name == job.metadata.name
      assert reply.spec.project_id == job.spec.project_id
      assert reply.spec.agent.machine.type == job.spec.agent.machine.type
      assert reply.spec.agent.machine.os_image == job.spec.agent.machine.os_image
    end

    test "when a self-hosted agent type is used => raise error" do
      job =
        Semaphore.Jobs.V1alpha.Job.new(
          metadata: Semaphore.Jobs.V1alpha.Job.Metadata.new(name: "RSpec 1/3"),
          spec:
            Semaphore.Jobs.V1alpha.Job.Spec.new(
              agent:
                Semaphore.Jobs.V1alpha.Job.Spec.Agent.new(
                  machine: Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.new(type: "s1-testing")
                ),
              project_id: hd(@authorized_projects)
            )
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:error, reply} = channel |> Stub.create_job(job, @options)

      assert reply == %GRPC.RPCError{
               message: "Self-hosted agent type is not allowed",
               status: 3
             }
    end
  end

  describe ".create_debug_job" do
    test "when the user can't create a pipeline => raise error" do
      GrpcMock.stub(Support.FakeServers.RBAC, :list_user_permissions, fn req, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          user_id: req.user_id,
          org_id: req.org_id,
          project_id: req.project_id,
          permissions: ["project.random.permission"]
        )
      end)

      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          project_id: hd(@authorized_projects),
          organization_id: @org_id,
          build_id: task.id
        })

      req = Semaphore.Jobs.V1alpha.CreateDebugJobRequest.new(job_id: job.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:error, reply} = channel |> Stub.create_debug_job(req, @options)

      assert reply == %GRPC.RPCError{
               message: "You are not allowed to run pipelines on this project",
               status: 7
             }
    end

    test "when the project belongs to restricted org and blocks debug on default branch => raise error" do
      mock_repo_proxy(:BRANCH, "master", "test-org/test-repo", "")
      mock_project([], [])

      create_debug_job_fails_permission_check(
        "You are not allowed to debug jobs on the default branch of this project"
      )
    end

    test "when the project belongs to restricted org and allows debug on default branch => creates job" do
      alias InternalApi.Projecthub.Project.Spec.PermissionType

      mock_repo_proxy(:BRANCH, "master", "test-org/test-repo", "")
      mock_project([PermissionType.value(:DEFAULT_BRANCH)], [])
      create_debug_job_passes_permission_check()
    end

    test "when the project belongs to restricted org and blocks debug on non default branch => raise error" do
      mock_repo_proxy(:BRANCH, "some-non-default-branch", "test-org/test-repo", "")
      mock_project([], [])

      create_debug_job_fails_permission_check(
        "You are not allowed to debug jobs on non default branches of this project"
      )
    end

    test "when the project belongs to restricted org and allows debug on non default branch => creates job" do
      alias InternalApi.Projecthub.Project.Spec.PermissionType

      mock_repo_proxy(:BRANCH, "some-non-default-branch", "test-org/test-repo", "")
      mock_project([PermissionType.value(:NON_DEFAULT_BRANCH)], [])
      create_debug_job_passes_permission_check()
    end

    test "when the project belongs to restricted org and blocks debug on tag => raise error" do
      mock_repo_proxy(:TAG, "", "test-org/test-repo", "")
      mock_project([], [])

      create_debug_job_fails_permission_check(
        "You are not allowed to debug jobs on a tag of this project"
      )
    end

    test "when the project belongs to restricted org and allows debug on tag => creates job" do
      alias InternalApi.Projecthub.Project.Spec.PermissionType

      mock_repo_proxy(:TAG, "", "test-org/test-repo", "")
      mock_project([PermissionType.value(:TAG)], [])
      create_debug_job_passes_permission_check()
    end

    test "when deployment target API fails => raise error" do
      GrpcMock.stub(Support.FakeServers.DeploymentTargetsApi, :verify, fn _, _ ->
        raise GRPC.RPCError, status: GRPC.Status.internal(), message: "some message"
      end)

      mock_repo_proxy(:BRANCH, "master", "test-org/test-repo", "")

      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          project_id: hd(@authorized_projects),
          organization_id: @org_id,
          deployment_target_id: @dt_id,
          build_id: task.id
        })

      req = Semaphore.Jobs.V1alpha.CreateDebugJobRequest.new(job_id: job.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:error, reply} = channel |> Stub.create_debug_job(req, @options)

      assert reply == %GRPC.RPCError{
               message: "Unable to verify access to deployment target #{@dt_id}",
               status: 13
             }
    end

    test "when deployment target forbids user => raise error" do
      GrpcMock.stub(Support.FakeServers.DeploymentTargetsApi, :verify, fn _, _ ->
        InternalApi.Gofer.DeploymentTargets.VerifyResponse.new(
          status: InternalApi.Gofer.DeploymentTargets.VerifyResponse.Status.value(:BANNED_SUBJECT)
        )
      end)

      mock_repo_proxy(:BRANCH, "master", "test-org/test-repo", "")

      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          project_id: hd(@authorized_projects),
          organization_id: @org_id,
          deployment_target_id: @dt_id,
          build_id: task.id
        })

      req = Semaphore.Jobs.V1alpha.CreateDebugJobRequest.new(job_id: job.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:error, reply} = channel |> Stub.create_debug_job(req, @options)

      assert reply == %GRPC.RPCError{
               message:
                 "You are not allowed to access Deployment Target[#{@dt_id}]: BANNED_SUBJECT",
               status: 7
             }
    end

    test "when the project belongs to restricted org and blocks debug on pull request => raise error" do
      mock_repo_proxy(:PR, "", "test-org/test-repo", "test-org/test-repo")
      mock_project([], [])

      create_debug_job_fails_permission_check(
        "You are not allowed to debug jobs on a pull request of this project"
      )
    end

    test "when the project belongs to restricted org and allows debug on pull request => creates job" do
      alias InternalApi.Projecthub.Project.Spec.PermissionType

      mock_repo_proxy(:PR, "", "test-org/test-repo", "test-org/test-repo")
      mock_project([PermissionType.value(:PULL_REQUEST)], [])
      create_debug_job_passes_permission_check()
    end

    test "when the project belongs to restricted org and blocks debug on forked pull request => raise error" do
      mock_repo_proxy(:PR, "", "test-org/test-repo", "forked/test-repo")
      mock_project([], [])

      create_debug_job_fails_permission_check(
        "You are not allowed to debug jobs on a forked pull request of this project"
      )
    end

    test "when the project belongs to restricted org and allows debug on forked pull request => creates job" do
      alias InternalApi.Projecthub.Project.Spec.PermissionType

      mock_repo_proxy(:PR, "", "test-org/test-repo", "forked/test-repo")
      mock_project([PermissionType.value(:FORKED_PULL_REQUEST)], [])
      create_debug_job_passes_permission_check()
    end

    test "when organization api fails => raise error" do
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      GrpcMock.stub(Support.FakeServers.OrganizationApi, :describe, fn _, _ ->
        raise "i refuse to return"
      end)

      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          project_id: hd(@authorized_projects),
          organization_id: @org_id,
          build_id: task.id
        })

      req = Semaphore.Jobs.V1alpha.CreateDebugJobRequest.new(job_id: job.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:error, reply} = channel |> Stub.create_debug_job(req, @options)

      assert reply == %GRPC.RPCError{
               message: "Error looking up #{@org_id}",
               status: 13
             }
    end

    test "when repo proxy api fails => raise error" do
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      GrpcMock.stub(Support.FakeServers.RepoProxyApi, :describe, fn _, _ ->
        raise "muahhahaaha"
      end)

      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          project_id: hd(@authorized_projects),
          organization_id: @restricted_org_id,
          build_id: task.id
        })

      req = Semaphore.Jobs.V1alpha.CreateDebugJobRequest.new(job_id: job.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:error, reply} = channel |> Stub.create_debug_job(req, @options_for_restricted_org)

      assert reply == %GRPC.RPCError{
               message: "Error checking org permissions",
               status: 13
             }
    end

    test "when project api fails => raise error" do
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      GrpcMock.stub(Support.FakeServers.ProjecthubApi, :describe, fn _, _ ->
        raise "muahhahaaha"
      end)

      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          project_id: hd(@authorized_projects),
          organization_id: @restricted_org_id,
          build_id: task.id
        })

      req = Semaphore.Jobs.V1alpha.CreateDebugJobRequest.new(job_id: job.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:error, reply} = channel |> Stub.create_debug_job(req, @options_for_restricted_org)

      assert reply == %GRPC.RPCError{
               message: "Error checking org permissions",
               status: 13
             }
    end

    test "when project api fails with metadata error => raise error" do
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub
      alias InternalApi.Projecthub.ResponseMeta

      GrpcMock.stub(Support.FakeServers.ProjecthubApi, :describe, fn _, _ ->
        InternalApi.Projecthub.DescribeResponse.new(
          metadata:
            ResponseMeta.new(
              status:
                ResponseMeta.Status.new(
                  code: ResponseMeta.Code.value(:FAILED_PRECONDITION),
                  message: "muahhahaaha"
                )
            )
        )
      end)

      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          project_id: hd(@authorized_projects),
          organization_id: @restricted_org_id,
          build_id: task.id
        })

      req = Semaphore.Jobs.V1alpha.CreateDebugJobRequest.new(job_id: job.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:error, reply} = channel |> Stub.create_debug_job(req, @options_for_restricted_org)

      assert reply == %GRPC.RPCError{
               message: "Error checking org permissions",
               status: 13
             }
    end

    test "when the user can access the project => creates job" do
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      {:ok, task} = Support.Factories.Task.create()

      {:ok, job} =
        Support.Factories.Job.create(:pending, %{
          project_id: hd(@authorized_projects),
          organization_id: @org_id,
          build_id: task.id
        })

      req = Semaphore.Jobs.V1alpha.CreateDebugJobRequest.new(job_id: job.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:ok, reply} = channel |> Stub.create_debug_job(req, @options)

      assert reply.metadata.name == "Debug Session for Job #{job.id}"
      assert reply.spec.agent.machine.type == job.machine_type
      assert reply.spec.agent.machine.os_image == job.machine_os_image
    end
  end

  describe ".create_debug_project" do
    test "when the user can't create a pipeline => raise error" do
      GrpcMock.stub(Support.FakeServers.RBAC, :list_user_permissions, fn req, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          user_id: req.user_id,
          org_id: req.org_id,
          project_id: req.project_id,
          permissions: ["project.random.permission"]
        )
      end)

      mock_project([], [])

      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      {:ok, task} = Support.Factories.Task.create()

      {:ok, _} =
        Support.Factories.Job.create(:pending, %{
          project_id: hd(@authorized_projects),
          organization_id: @org_id,
          build_id: task.id
        })

      req =
        Semaphore.Jobs.V1alpha.CreateDebugProjectRequest.new(project_id: hd(@authorized_projects))

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:error, reply} = channel |> Stub.create_debug_project(req, @options)

      assert reply == %GRPC.RPCError{
               message: "You are not allowed to run pipelines on this project",
               status: 7
             }
    end

    test "when the project belongs to restricted org and blocks empty debug session => raise error" do
      mock_repo_proxy(:BRANCH, "master", "test-org/test-repo", "")
      mock_project([], [])
      create_debug_project_fails_permission_check("You are not allowed to debug this project")
    end

    test "when the project belongs to restricted org and allows empty debug=> creates job" do
      alias InternalApi.Projecthub.Project.Spec.PermissionType

      mock_repo_proxy(:BRANCH, "master", "test-org/test-repo", "")
      mock_project([PermissionType.value(:EMPTY)], [])
      create_debug_project_passes_permission_check()
    end

    test "when organization api fails => raise error" do
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub
      alias InternalApi.Projecthub.Project.Spec.PermissionType

      mock_project([PermissionType.value(:EMPTY)], [])

      GrpcMock.stub(Support.FakeServers.OrganizationApi, :describe, fn _, _ ->
        raise "i refuse to return"
      end)

      req =
        Semaphore.Jobs.V1alpha.CreateDebugProjectRequest.new(
          project_id_or_name: hd(@authorized_projects)
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:error, reply} = channel |> Stub.create_debug_project(req, @options)

      assert reply == %GRPC.RPCError{
               message: "Error looking up #{@org_id}",
               status: 13
             }
    end

    test "when project api fails => raise error" do
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      GrpcMock.stub(Support.FakeServers.ProjecthubApi, :describe, fn _, _ ->
        raise "muahhahaaha"
      end)

      req =
        Semaphore.Jobs.V1alpha.CreateDebugProjectRequest.new(
          project_id_or_name: hd(@authorized_projects)
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:error, reply} = channel |> Stub.create_debug_project(req, @options_for_restricted_org)

      assert reply == %GRPC.RPCError{
               message: "Error checking org permissions",
               status: 13
             }
    end

    test "when the user can access the project => creates job" do
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub
      alias InternalApi.Projecthub.Project.Spec.PermissionType

      mock_project([PermissionType.value(:EMPTY)], [])

      req =
        Semaphore.Jobs.V1alpha.CreateDebugProjectRequest.new(
          project_id_or_name: hd(@authorized_projects),
          machine_type: "g1-standard-4"
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:ok, reply} = channel |> Stub.create_debug_project(req, @options)

      assert reply.metadata.name == "Debug Session for project zebra"
      assert reply.spec.agent.machine.type == "g1-standard-4"
      assert reply.spec.agent.machine.os_image == "ubuntu1804"
    end
  end

  describe ".stop_job" do
    test "when the job is present and user can access it => requests an async stop" do
      alias Zebra.Models.{Job, JobStopRequest}

      alias Semaphore.Jobs.V1alpha.StopJobRequest, as: Request
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      {:ok, job} =
        Support.Factories.Job.create(:started, %{
          project_id: hd(@authorized_projects),
          organization_id: @org_id
        })

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: job.id)

      job = Job.reload(job)

      assert {:ok, %Semaphore.Jobs.V1alpha.Empty{}} = channel |> Stub.stop_job(request, @options)

      assert {:ok, stop_request} = JobStopRequest.find_by_job_id(job.id)

      assert stop_request != nil
      assert stop_request.job_id == job.id
    end

    test "idempotent requests" do
      alias Zebra.Models.JobStopRequest

      alias Semaphore.Jobs.V1alpha.StopJobRequest, as: Request
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      {:ok, job} =
        Support.Factories.Job.create(:started, %{
          project_id: hd(@authorized_projects),
          organization_id: @org_id
        })

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: job.id)

      1..3
      |> Enum.each(fn _ ->
        assert {:ok, %Semaphore.Jobs.V1alpha.Empty{}} =
                 channel |> Stub.stop_job(request, @options)
      end)

      assert {:ok, stop_request} = JobStopRequest.find_by_job_id(job.id)
      assert stop_request != nil
      assert stop_request.job_id == job.id
    end

    test "when the job is not found => returns not found" do
      alias Semaphore.Jobs.V1alpha.StopJobRequest, as: Request
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: @job_id)

      {:error, reply} = channel |> Stub.stop_job(request, @options)

      assert reply == %GRPC.RPCError{
               message: "Job #{@job_id} not found",
               status: 5
             }
    end

    test "when the user is not authorized to see the job => returns not found" do
      alias Semaphore.Jobs.V1alpha.StopJobRequest, as: Request
      alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

      {:ok, job} = Support.Factories.Job.create(:pending, %{organization_id: @org_id})

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = Request.new(job_id: job.id)

      {:error, reply} = channel |> Stub.stop_job(request, @options)

      assert reply == %GRPC.RPCError{message: "Job #{job.id} not found", status: 5}
    end
  end

  # Utility functions
  def mock_repo_proxy(hook_type, branch_name, repo_slug, pr_slug) do
    GrpcMock.stub(Support.FakeServers.RepoProxyApi, :describe, fn _, _ ->
      status = InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))

      hook =
        InternalApi.RepoProxy.Hook.new(
          repo_slug: repo_slug,
          git_ref_type: InternalApi.RepoProxy.Hook.Type.value(hook_type),
          pr_slug: pr_slug,
          branch_name: branch_name
        )

      %InternalApi.RepoProxy.DescribeResponse{status: status, hook: hook}
    end)
  end

  def mock_project(debug_permissions, attach_permissions, custom_permissions \\ true) do
    GrpcMock.stub(Support.FakeServers.ProjecthubApi, :describe, fn _, _ ->
      alias InternalApi.Projecthub.ResponseMeta
      alias InternalApi.Projecthub.Project

      meta = ResponseMeta.new(status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK)))

      project =
        Project.new(
          metadata:
            Project.Metadata.new(
              id: hd(@authorized_projects),
              name: "zebra"
            ),
          spec:
            Project.Spec.new(
              repository:
                Project.Spec.Repository.new(url: "git@github.com:/test-org/test-repo.git"),
              custom_permissions: custom_permissions,
              debug_permissions: debug_permissions,
              attach_permissions: attach_permissions
            )
        )

      InternalApi.Projecthub.DescribeResponse.new(metadata: meta, project: project)
    end)
  end

  def get_job_debug_ssh_key_fails_permission_check(message, build_id) do
    alias Semaphore.Jobs.V1alpha.GetJobDebugSSHKeyRequest, as: Request
    alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

    {:ok, job} =
      Support.Factories.Job.create(:pending, %{
        project_id: hd(@authorized_projects),
        organization_id: @restricted_org_id,
        build_id: build_id
      })

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")

    request = Request.new(job_id: job.id)

    {:error, reply} = channel |> Stub.get_job_debug_ssh_key(request, @options_for_restricted_org)

    assert reply == %GRPC.RPCError{
             message: message,
             status: 7
           }
  end

  def get_job_debug_ssh_key_passes_permission_check(build_id) do
    alias Semaphore.Jobs.V1alpha.GetJobDebugSSHKeyRequest, as: Request
    alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

    {:ok, job} =
      Support.Factories.Job.create(:started, %{
        project_id: hd(@authorized_projects),
        private_ssh_key: Zebra.RSA.generate().private_key,
        organization_id: @restricted_org_id,
        build_id: build_id
      })

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")

    request = Request.new(job_id: job.id)

    {:ok, reply} = channel |> Stub.get_job_debug_ssh_key(request, @options_for_restricted_org)

    assert reply == %Semaphore.Jobs.V1alpha.JobDebugSSHKey{
             key: job.private_ssh_key
           }
  end

  def create_debug_job_fails_permission_check(message) do
    alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

    {:ok, task} = Support.Factories.Task.create()

    {:ok, job} =
      Support.Factories.Job.create(:pending, %{
        project_id: hd(@authorized_projects),
        organization_id: @restricted_org_id,
        build_id: task.id
      })

    req = Semaphore.Jobs.V1alpha.CreateDebugJobRequest.new(job_id: job.id)

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")

    {:error, reply} = channel |> Stub.create_debug_job(req, @options_for_restricted_org)

    assert reply == %GRPC.RPCError{
             message: message,
             status: 7
           }
  end

  def create_debug_job_passes_permission_check do
    alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

    {:ok, task} = Support.Factories.Task.create()

    {:ok, job} =
      Support.Factories.Job.create(:pending, %{
        project_id: hd(@authorized_projects),
        organization_id: @restricted_org_id,
        build_id: task.id
      })

    req = Semaphore.Jobs.V1alpha.CreateDebugJobRequest.new(job_id: job.id)

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, reply} = channel |> Stub.create_debug_job(req, @options_for_restricted_org)
    assert reply.metadata.name == "Debug Session for Job #{job.id}"

    request = Semaphore.Jobs.V1alpha.GetJobDebugSSHKeyRequest.new(job_id: reply.metadata.id)

    # this means it passed the permission checks, but failed because the job isn't running yet
    {:error, reply} = channel |> Stub.get_job_debug_ssh_key(request, @options_for_restricted_org)

    assert reply == %GRPC.RPCError{
             message: "Job's debug SSH is only available while the job is running",
             status: 9
           }
  end

  def create_debug_project_fails_permission_check(message) do
    alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

    {:ok, task} = Support.Factories.Task.create()

    {:ok, _} =
      Support.Factories.Job.create(:pending, %{
        project_id: hd(@authorized_projects),
        organization_id: @restricted_org_id,
        build_id: task.id
      })

    req =
      Semaphore.Jobs.V1alpha.CreateDebugProjectRequest.new(
        project_id_or_name: hd(@authorized_projects)
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")

    {:error, reply} = channel |> Stub.create_debug_project(req, @options_for_restricted_org)

    assert reply == %GRPC.RPCError{
             message: message,
             status: 7
           }
  end

  def create_debug_project_passes_permission_check do
    alias Semaphore.Jobs.V1alpha.JobsApi.Stub, as: Stub

    req =
      Semaphore.Jobs.V1alpha.CreateDebugProjectRequest.new(
        project_id_or_name: hd(@authorized_projects)
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051", timeout: :infinity)
    {:ok, reply} = channel |> Stub.create_debug_project(req, @options_for_restricted_org)

    assert reply.metadata.name == "Debug Session for project zebra"

    request = Semaphore.Jobs.V1alpha.GetJobDebugSSHKeyRequest.new(job_id: reply.metadata.id)

    # this means it passed the permission checks, but failed because the job isn't running yet
    {:error, reply} = channel |> Stub.get_job_debug_ssh_key(request, @options_for_restricted_org)

    assert reply == %GRPC.RPCError{
             message: "Job's debug SSH is only available while the job is running",
             status: 9
           }
  end
end
