defmodule Router.Trobleshoot.Job.Test do
  use ExUnit.Case

  alias Support.Stubs.{Job, Pipeline, Workflow}

  setup do
    Support.Stubs.reset()
    Support.Stubs.grant_all_permissions()

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    user_id = user.id

    build_req_id = UUID.uuid4()
    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Pipeline.create_initial(workflow)

    block =
      Pipeline.add_block(pipeline, %{
        name: "Block #1",
        dependencies: [],
        job_names: ["First job"],
        build_req_id: build_req_id
      })

    job = Job.create(pipeline.id, build_req_id, project_id: project.id)

    %{
      user: user,
      user_id: user_id,
      job: job.api_model,
      ppl: pipeline.api_model,
      wf: workflow.api_model,
      block: block.api_model
    }
  end

  describe "GET /troubleshoot/job/:job_id" do
    test "unauthorized user", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.view")
        )
      end)

      assert {401, _} = troubleshoot_job(ctx.job.id, ctx.user_id, false)
    end

    test "project ID mismatch", ctx do
      org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
      project = Support.Stubs.Project.create(org, ctx.user)
      hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
      build_req_id = UUID.uuid4()

      workflow = Workflow.create(hook, ctx.user_id, organization_id: org.id)
      pipeline = Pipeline.create_initial(workflow)

      Pipeline.add_block(pipeline, %{
        name: "Block #1",
        dependencies: [],
        job_names: ["First job"],
        build_req_id: build_req_id
      })

      job = Job.create(pipeline.id, build_req_id, project_id: project.id)

      assert {404, _} = troubleshoot_job(job.id, ctx.user_id, false)
    end

    test "returns 200 and troubleshoot data for existing job", ctx do
      assert {200, response} = troubleshoot_job(ctx.job.id, ctx.user_id)

      assert response == %{
               "block" => %{
                 "block_id" => ctx.block.block_id,
                 "build_req_id" => ctx.block.build_req_id,
                 "error_description" => "",
                 "name" => "Block #1",
                 "result" => "",
                 "result_reason" => "",
                 "state" => "running"
               },
               "job" => %{
                 "agent_name" => "",
                 "build_req_id" => ctx.job.build_req_id,
                 "created_at" => to_datetime(ctx.job.timeline.created_at),
                 "enqueued_at" => to_datetime(ctx.job.timeline.enqueued_at),
                 "failure_reason" => "",
                 "finished_at" => to_datetime(ctx.job.timeline.finished_at),
                 "id" => ctx.job.id,
                 "is_debug_job" => false,
                 "is_self_hosted" => false,
                 "machine_type" => "e1-standard-2",
                 "name" => "Unit tests",
                 "os_image" => "ubuntu1804",
                 "priority" => 50,
                 "started_at" => to_datetime(ctx.job.timeline.started_at),
                 "state" => "finished"
               },
               "pipeline" => %{
                 "created_at" => to_datetime(ctx.ppl.created_at),
                 "done_at" => to_datetime(ctx.ppl.done_at),
                 "error_description" => "",
                 "name" => "Build & Test",
                 "partial_rerun_of" => "",
                 "partially_rerun_by" => "",
                 "pending_at" => to_datetime(ctx.ppl.pending_at),
                 "ppl_id" => ctx.ppl.ppl_id,
                 "promotion_of" => "",
                 "queue_id" => ctx.ppl.queue.queue_id,
                 "queue_name" => "prod",
                 "queue_scope" => "project",
                 "queue_type" => 0,
                 "queuing_at" => to_datetime(ctx.ppl.queuing_at),
                 "result" => "",
                 "result_reason" => "",
                 "running_at" => to_datetime(ctx.ppl.running_at),
                 "state" => "queuing",
                 "stopping_at" => to_datetime(ctx.ppl.stopping_at),
                 "switch_id" => "",
                 "terminate_request" => "",
                 "terminated_by" => "",
                 "working_directory" => "",
                 "yaml_file_name" => ""
               },
               "project" => %{
                 "id" => ctx.job.project_id,
                 "organization_id" => ctx.job.organization_id
               },
               "workflow" => %{
                 "branch_id" => ctx.wf.branch_id,
                 "branch_name" => "master",
                 "commit_sha" => ctx.wf.commit_sha,
                 "created_at" => to_datetime(ctx.wf.created_at),
                 "hook_id" => ctx.wf.hook_id,
                 "initial_ppl_id" => ctx.wf.initial_ppl_id,
                 "project_id" => ctx.wf.project_id,
                 "repository_id" => "",
                 "requester_id" => ctx.wf.requester_id,
                 "rerun_of" => "",
                 "triggered_by" => "hook",
                 "wf_id" => ctx.wf.wf_id
               }
             }
    end

    test "returns 404 for job that does not exist", ctx do
      non_existing_job_id = UUID.uuid4()
      assert {404, _} = troubleshoot_job(non_existing_job_id, ctx.user_id, false)
    end
  end

  defp troubleshoot_job(job_id, user_id, decode? \\ true) do
    url = "localhost:4004/troubleshoot/job/" <> job_id
    {:ok, %{:body => body, :status_code => status_code}} = HTTPoison.get(url, headers(user_id))

    body =
      case decode? do
        true -> Poison.decode!(body)
        false -> body
      end

    {status_code, body}
  end

  defp headers(user_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", Support.Stubs.Organization.default_org_id()}
    ]

  def to_datetime(%{nanos: 0, seconds: 0}), do: ""

  def to_datetime(%{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    DateTime.to_string(ts_date_time)
  end
end
