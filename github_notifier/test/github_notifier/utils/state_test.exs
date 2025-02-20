defmodule GithubNotifier.Utils.State.Test do
  use ExUnit.Case

  alias GithubNotifier.Utils.State
  alias InternalApi.Plumber.{Block, Pipeline}
  alias InternalApi.Velocity.Summary

  test "when block passed => return success" do
    block =
      Block.new(
        state: :DONE,
        result: :PASSED
      )

    assert State.extract(block) == {"success", "The build passed on Semaphore 2.0."}
  end

  test "when block failed => return failed" do
    block =
      Block.new(
        state: :DONE,
        result: :FAILED
      )

    assert State.extract(block) == {"failure", "The build failed on Semaphore 2.0."}
  end

  test "when block is running => return pending" do
    block = Block.new(state: :RUNNING)

    assert State.extract(block) == {"pending", "The build is pending on Semaphore 2.0."}
  end

  test "when pipeline passed and no tests => return success and default build passed message" do
    pipeline =
      Pipeline.new(
        state: :DONE,
        result: :PASSED
      )

    pipeline_summary = Summary.new()

    assert State.extract_with_summary(pipeline, pipeline_summary) ==
             {"success", "The build passed on Semaphore 2.0."}
  end

  test "when pipeline passed and there are non-zero passed tests => return success and number of passed tests" do
    pipeline =
      Pipeline.new(
        state: :DONE,
        result: :PASSED
      )

    pipeline_summary =
      Summary.new(
        total: 100,
        passed: 100
      )

    assert State.extract_with_summary(pipeline, pipeline_summary) ==
             {"success", "100 tests passed."}
  end

  test "when pipeline failed and no tests => return failure and default build passed message" do
    pipeline =
      Pipeline.new(
        state: :DONE,
        result: :FAILED
      )

    pipeline_summary = Summary.new()

    assert State.extract_with_summary(pipeline, pipeline_summary) ==
             {"failure", "The build failed on Semaphore 2.0."}
  end

  test "when pipeline failed and there are non-zero failed tests => return failure and number of failed tests" do
    pipeline =
      Pipeline.new(
        state: :DONE,
        result: :FAILED
      )

    pipeline_summary =
      Summary.new(
        total: 100,
        passed: 50,
        failed: 30,
        error: 20
      )

    assert State.extract_with_summary(pipeline, pipeline_summary) ==
             {"failure", "50 tests failed."}
  end

  test "when pipeline failed and there are zero failed tests and non-zero passed tests => return failure and default build failed message" do
    pipeline =
      Pipeline.new(
        state: :DONE,
        result: :FAILED
      )

    pipeline_summary =
      Summary.new(
        total: 100,
        passed: 100,
        failed: 0,
        error: 0
      )

    assert State.extract_with_summary(pipeline, pipeline_summary) ==
             {"failure", "The build failed on Semaphore 2.0."}
  end
end
