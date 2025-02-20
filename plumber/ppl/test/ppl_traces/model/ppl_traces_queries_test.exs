defmodule Ppl.PplTraces.Model.PplTracesQueries.Test do
  use ExUnit.Case
  doctest Ppl.PplTraces.Model.PplTracesQueries

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries

  setup do
    Test.Helpers.truncate_db()

    request_args = Test.Helpers.schedule_request_factory(:local)
    state = create_ppls(request_args)
    {:ok, state}
  end

  defp create_ppls(request_args) do
    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    build = %{"jobs" => jobs_list}

    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    definition = %{"version" => "v1.0", "agent" => agent,
                      "blocks" => [%{"build" => build}]}

    {:ok, ppl_req} = PplRequestsQueries.insert_request(request_args)
    id = ppl_req.id
    {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)

    {:ok, ppl} = PplsQueries.insert(ppl_req)

    %{ppl_id: id, ppl: ppl, ppl_req: ppl_req,}
  end

  test "insert new pipeline trace for existing pipeline", ctx do
    assert {:ok, ppl_trace} = PplTracesQueries.insert(ctx.ppl)
    assert ppl_trace.ppl_id == ctx.ppl_id
    assert ppl_trace.created_at
            |> DateTime.to_naive()
            |> NaiveDateTime.compare(ctx.ppl.inserted_at) == :eq
  end

  test "insert new pipeline trace for non-existing pipeline fails" do
    pretend_ppl = %{ppl_id: UUID.uuid4, inserted_at: NaiveDateTime.utc_now()}
    assert {:error, _message} = PplTracesQueries.insert(pretend_ppl)
  end

  test "insert two pipeline traces for same pipeline fails", ctx do
    assert {:ok, ppl_trace} = PplTracesQueries.insert(ctx.ppl)
    assert ppl_trace.ppl_id == ctx.ppl_id

    assert ppl_trace.created_at
            |> DateTime.to_naive()
            |> NaiveDateTime.compare(ctx.ppl.inserted_at) == :eq

    assert {:error, ecto_error} = PplTracesQueries.insert(ctx.ppl)
    assert String.contains?(inspect(ecto_error), "one_ppl_trace_per_ppl")
  end

  test "set timestamps value works for all supported timestamps", ctx do
    assert {:ok, _ppl_trace} = PplTracesQueries.insert(ctx.ppl)

    test_setting_value_for(ctx.ppl_id, :pending_at)
    test_setting_value_for(ctx.ppl_id, :queuing_at)
    test_setting_value_for(ctx.ppl_id, :running_at)
    test_setting_value_for(ctx.ppl_id, :stopping_at)
    test_setting_value_for(ctx.ppl_id, :done_at)
  end

  defp test_setting_value_for(ppl_id, timestamp_name) do
    before_time =  DateTime.utc_now()
    assert {:ok, ppl_trace} = PplTracesQueries.set_timestamp(ppl_id, timestamp_name)
    after_time = DateTime.utc_now()

    changed_value = Map.get(ppl_trace, timestamp_name)
    assert DateTime.compare(before_time, changed_value) == :lt
    assert DateTime.compare(after_time, changed_value) == :gt
  end

  test "set value for unsupported timestamp fails", ctx do
    assert {:ok, _ppl_trace} = PplTracesQueries.insert(ctx.ppl)

    assert {:error, message} =
      PplTracesQueries.set_timestamp(ctx.ppl_id, :non_existent_timestamp)

    assert message == "Unsuported field in PipelineTrace model: non_existent_timestamp"
  end

end
