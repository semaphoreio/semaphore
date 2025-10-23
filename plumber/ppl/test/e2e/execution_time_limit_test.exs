defmodule Ppl.E2E.ExecutionTimeLimit.Test do
  use Ppl.IntegrationCase

  alias Ppl.Actions

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{}}
  end

  @tag :integration
  test "pipeline with valid limits on all levels passes" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "23_initializing_test",
        "file_name" => "/exec_time_limit/valid_example.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 3_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "passed"
  end

  @tag :integration
  test "when job limit is longer than limit of its block => pipeline is malformed" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "23_initializing_test",
        "file_name" => "/exec_time_limit/job_longer_than_block.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 3_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "failed"
    assert ppl.result_reason == "malformed"
    assert ppl.error_description ==
      "Error: \"Job on path '#/blocks/0/task/jobs/0' has an execution_time_limit"
      <> " of 20 minutes which is longer than 10 minutes that is the execution_time_limit"
      <> " of a block to which this job belongs. This would cause that job to"
      <> " stop when block level time limit is reached.\""
  end

  @tag :integration
  test "when block limit is longer than deafult job limit => pipeline is malformed" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "23_initializing_test",
        "file_name" => "/exec_time_limit/block_limit_over_default_job.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 3_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "failed"
    assert ppl.result_reason == "malformed"
    assert ppl.error_description ==
      "Error: \"The execution_time_limit of a block on path '#/blocks/0' is set"
      <> " to 40 hours which is longer than default job level execution_time_limit"
      <> " of 24 hours. This would cause the block to stop as soon as first job"
      <> " reaches that default time limit for jobs.\""
  end

  @tag :integration
  test "when pipeline limit is longer than default job limit => pipeline is malformed" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "23_initializing_test",
        "file_name" => "/exec_time_limit/ppl_limit_over_default_job.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 3_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "failed"
    assert ppl.result_reason == "malformed"
    assert ppl.error_description ==
      "Error: \"The pipeline level execution_time_limit is set to 42 hours which"
      <> " is longer than default job level execution_time_limit of 24 hours."
      <> " This would cause the pipeline to stop as soon as first job reaches"
      <> " that default time limit for jobs.\""
  end

  @tag :integration
  test "when block limit is longer than pipeline limit => pipeline is malformed" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "23_initializing_test",
        "file_name" => "/exec_time_limit/block_longer_than_ppl.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 3_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "failed"
    assert ppl.result_reason == "malformed"
    assert ppl.error_description ==
      "Error: \"Block on path '#/blocks/0' has an execution_time_limit of 2 hours"
      <> " and 40 minutes which is longer than execution_time_limit of a whole pipeline"
      <> " which is 2 hours. This would cause that block to stop when pipeline level"
      <> " time limit is reached.\""
  end

  @tag :integration
  test "when job limit is longer than pipeline limit => pipeline is malformed" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "23_initializing_test",
        "file_name" => "/exec_time_limit/job_longer_than_ppl.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 3_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "failed"
    assert ppl.result_reason == "malformed"
    assert ppl.error_description ==
      "Error: \"Job on path '#/blocks/0/task/jobs/0' has an execution_time_limit"
      <>" of 36 hours which is longer than execution_time_limit of a whole pipeline"
      <> " which is 1 hour. This would cause that job to stop when pipeline level"
      <>" time limit is reached.\""
  end
end
