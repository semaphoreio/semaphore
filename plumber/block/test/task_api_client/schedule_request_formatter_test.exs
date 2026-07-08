defmodule Block.TaskApiClient.ScheduleRequestFormatter.Test do
  use ExUnit.Case, async: false

  import Mock

  alias Block.TaskApiClient.ScheduleRequestFormatter
  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Tasks.Model.Tasks
  alias Block.EctoRepo, as: Repo

  @partition_key "job_copy_partition"
  @unresolvable_metric "Block.job_copy_partition.original_task_unresolvable"

  setup do
    assert {:ok, _} =
      Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    job_1 = %{"name" => "job1", "commands" => ["echo foo"]}
    job_2 = %{"name" => "job2", "commands" => ["echo bar"]}
    job_3 = %{"name" => "job3", "commands" => ["echo baz"]}
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    task_def = %{"jobs" => [job_1, job_2, job_3], "agent" => agent}

    {:ok, orig_blk_req} = insert_block_request(%{"service" => "local"}, task_def)

    zebra_task_id = UUID.uuid4()
    assert {:ok, _task} = insert_task(orig_blk_req.id, zebra_task_id)

    {:ok, %{task_def: task_def, orig_block_id: orig_blk_req.id, zebra_task_id: zebra_task_id}}
  end

  test "partition with resolvable anchor stamps original_task_id and per-job markers by index", ctx do
    orig_job_id = UUID.uuid4()

    ppl_args = %{@partition_key =>
      %{"original_block_id" => ctx.orig_block_id, "jobs" => %{"0" => orig_job_id}}}

    assert {:ok, req} =
      ScheduleRequestFormatter.to_proto_request(ctx.task_def, additional_params(ppl_args))

    assert req.original_task_id == ctx.zebra_task_id
    assert [j0, j1, j2] = req.jobs
    assert j0.original_job_id == orig_job_id
    assert j1.original_job_id == ""
    assert j2.original_job_id == ""
  end

  test "markers are matched by string-keyed index, not list position", ctx do
    {b_orig_id, c_orig_id} = {UUID.uuid4(), UUID.uuid4()}

    ppl_args = %{@partition_key =>
      %{"original_block_id" => ctx.orig_block_id,
        "jobs" => %{"2" => c_orig_id, "1" => b_orig_id}}}

    assert {:ok, req} =
      ScheduleRequestFormatter.to_proto_request(ctx.task_def, additional_params(ppl_args))

    assert req.original_task_id == ctx.zebra_task_id
    assert [j0, j1, j2] = req.jobs
    assert j0.original_job_id == ""
    assert j1.original_job_id == b_orig_id
    assert j2.original_job_id == c_orig_id
  end

  test "no partition key: request has no original_task_id and no original_job_id set", ctx do
    assert {:ok, req} =
      ScheduleRequestFormatter.to_proto_request(ctx.task_def, additional_params(%{}))

    assert req.original_task_id == ""
    assert Enum.all?(req.jobs, fn job -> job.original_job_id == "" end)
    assert Enum.all?(req.jobs, fn job -> original_job_id_env(job) == nil end)
  end

  test "rerun_jobs markers inject SEMAPHORE_ORIGINAL_JOB_ID env into re-run jobs only", ctx do
    {a_orig_id, b_orig_id, c_orig_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}

    ppl_args = %{@partition_key =>
      %{"original_block_id" => ctx.orig_block_id,
        "jobs" => %{"0" => a_orig_id},
        "rerun_jobs" => %{"1" => b_orig_id, "2" => c_orig_id}}}

    assert {:ok, req} =
      ScheduleRequestFormatter.to_proto_request(ctx.task_def, additional_params(ppl_args))

    assert [j0, j1, j2] = req.jobs

    assert j0.original_job_id == a_orig_id
    assert original_job_id_env(j0) == nil

    assert j1.original_job_id == ""
    assert original_job_id_env(j1) == b_orig_id

    assert j2.original_job_id == ""
    assert original_job_id_env(j2) == c_orig_id
  end

  test "env injection appends to already-defined job env_vars without dropping them", ctx do
    b_orig_id = UUID.uuid4()

    job_with_env = %{"name" => "job2", "commands" => ["echo bar"],
                     "env_vars" => [%{"name" => "FOO", "value" => "bar"}]}

    task_def = ctx.task_def |> Map.put("jobs", [
      %{"name" => "job1", "commands" => ["echo foo"]},
      job_with_env,
      %{"name" => "job3", "commands" => ["echo baz"]}
    ])

    ppl_args = %{@partition_key =>
      %{"original_block_id" => ctx.orig_block_id,
        "jobs" => %{"0" => UUID.uuid4()},
        "rerun_jobs" => %{"1" => b_orig_id}}}

    assert {:ok, req} =
      ScheduleRequestFormatter.to_proto_request(task_def, additional_params(ppl_args))

    assert [_j0, j1, _j2] = req.jobs
    assert Enum.any?(j1.env_vars, fn ev -> ev.name == "FOO" and ev.value == "bar" end)
    assert original_job_id_env(j1) == b_orig_id
  end

  test "partition without rerun_jobs key (older format) injects no env", ctx do
    ppl_args = %{@partition_key =>
      %{"original_block_id" => ctx.orig_block_id, "jobs" => %{"0" => UUID.uuid4()}}}

    assert {:ok, req} =
      ScheduleRequestFormatter.to_proto_request(ctx.task_def, additional_params(ppl_args))

    assert Enum.all?(req.jobs, fn job -> original_job_id_env(job) == nil end)
  end

  defp original_job_id_env(job) do
    job.env_vars
    |> Enum.find(fn ev -> ev.name == "SEMAPHORE_ORIGINAL_JOB_ID" end)
    |> case do
      nil -> nil
      ev -> ev.value
    end
  end

  test "degrade: original block with no Tasks row drops all markers and the anchor + metric", ctx do
    orig_job_id = UUID.uuid4()

    ppl_args = %{@partition_key =>
      %{"original_block_id" => UUID.uuid4(), "jobs" => %{"0" => orig_job_id}}}

    with_mock Watchman, [:passthrough], increment: fn _ -> :ok end do
      assert {:ok, req} =
        ScheduleRequestFormatter.to_proto_request(ctx.task_def, additional_params(ppl_args))

      assert req.original_task_id == ""
      assert Enum.all?(req.jobs, fn job -> job.original_job_id == "" end)
      assert_called Watchman.increment(@unresolvable_metric)
    end
  end

  test "degrade: original block whose Tasks row has nil task_id drops all markers and the anchor + metric", ctx do
    orig_job_id = UUID.uuid4()

    {:ok, never_scheduled_blk_req} = insert_block_request(%{"service" => "local"}, ctx.task_def)
    assert {:ok, _task} = insert_task(never_scheduled_blk_req.id, nil)

    ppl_args = %{@partition_key =>
      %{"original_block_id" => never_scheduled_blk_req.id, "jobs" => %{"0" => orig_job_id}}}

    with_mock Watchman, [:passthrough], increment: fn _ -> :ok end do
      assert {:ok, req} =
        ScheduleRequestFormatter.to_proto_request(ctx.task_def, additional_params(ppl_args))

      assert req.original_task_id == ""
      assert Enum.all?(req.jobs, fn job -> job.original_job_id == "" end)
      assert_called Watchman.increment(@unresolvable_metric)
    end
  end

  test "end-to-end: partition persisted in request_args survives DB reload and reaches the built request", ctx do
    {a_orig_id, c_orig_id} = {UUID.uuid4(), UUID.uuid4()}

    partition = %{"original_block_id" => ctx.orig_block_id,
                  "jobs" => %{"0" => a_orig_id, "2" => c_orig_id}}

    request_args = %{"service" => "local", @partition_key => partition}

    {:ok, blk_req} = insert_block_request(request_args, ctx.task_def)
    {:ok, _blk_req} = BlockRequestsQueries.insert_build(blk_req, %{build: ctx.task_def})

    {:ok, blk_req} = BlockRequestsQueries.get_by_id(blk_req.id)

    ppl_args = blk_req.request_args |> Map.merge(blk_req.source_args || %{})
    params = additional_params(ppl_args)

    assert {:ok, req} = ScheduleRequestFormatter.to_proto_request(blk_req.build, params)

    assert req.original_task_id == ctx.zebra_task_id
    assert [j0, j1, j2] = req.jobs
    assert j0.original_job_id == a_orig_id
    assert j1.original_job_id == ""
    assert j2.original_job_id == c_orig_id
  end

  test "end-to-end inverse: request_args without a partition yields no original ids", ctx do
    {:ok, blk_req} = insert_block_request(%{"service" => "local"}, ctx.task_def)
    {:ok, _blk_req} = BlockRequestsQueries.insert_build(blk_req, %{build: ctx.task_def})

    {:ok, blk_req} = BlockRequestsQueries.get_by_id(blk_req.id)

    ppl_args = blk_req.request_args |> Map.merge(blk_req.source_args || %{})
    params = additional_params(ppl_args)

    assert {:ok, req} = ScheduleRequestFormatter.to_proto_request(blk_req.build, params)

    assert req.original_task_id == ""
    assert Enum.all?(req.jobs, fn job -> job.original_job_id == "" end)
  end

  defp additional_params(ppl_args) do
    %{"wf_id" => UUID.uuid4(), "ppl_id" => UUID.uuid4(),
      "request_token" => UUID.uuid4(), "project_id" => UUID.uuid4(),
      "org_id" => UUID.uuid4(), "hook_id" => UUID.uuid4(),
      "deployment_target_id" => "", "repository_id" => "",
      "ppl_args" => ppl_args}
  end

  defp insert_block_request(request_args, task_def) do
    request = %{ppl_id: UUID.uuid4(), pple_block_index: 0, request_args: request_args,
                source_args: %{"git_ref_type" => "branch"}, version: "v1.0",
                definition: %{"build" => task_def}, hook_id: UUID.uuid4()}

    BlockRequestsQueries.insert_request(request)
  end

  defp insert_task(block_id, task_id) do
    params = %{block_id: block_id, state: "done", in_scheduling: false, task_id: task_id}

    %Tasks{} |> Tasks.changeset(params) |> Repo.insert()
  end
end
