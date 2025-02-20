defmodule Ppl.E2E.AutoCancel.Test do
  use Ppl.IntegrationCase

  alias Ppl.Actions
  alias InternalApi.Plumber.Pipeline.{Result, ResultReason}

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{}}
  end

  @tag :integration
  test "auto_cancel/queued terminates older pipelines that are not running" do
    loopers = Test.Helpers.start_all_loopers()

    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "28_auto_cancel", "file_name" => "ac_queued.yml",
        "label" => "master", "project_id" => "123"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "running", 4_000)

    ppl_ids =
      Enum.map(1..5, fn _ ->
        {:ok, %{ppl_id: ppl_id}} =
          %{"repo_name" => "28_auto_cancel", "file_name" => "ac_queued.yml",
            "label" => "master", "project_id" => "123"}
          |> Test.Helpers.schedule_request_factory(:local)
          |> Actions.schedule()

        ppl_id
      end)

    # pipeline that was running finishes normaly
    assert {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    assert ppl.result == "passed"

    # all later pipelines that were not runing are canceled by last ppl, and it finishes normaly
    ppl_ids |> Enum.reverse() |> Enum.with_index()  |> Enum.map(fn {ppl_id, index} ->
      if index > 0 do
        assert {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 1_000)
        assert ppl.result == "canceled"
        assert ppl.result_reason == "strategy"
      else
        assert {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "running", 1_000)
        assert {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
        assert ppl.result == "passed"
      end
    end)

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "auto_cancel/running terminates older pipelines that are either running or queing/pending" do
    loopers = Test.Helpers.start_all_loopers()

    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "28_auto_cancel", "file_name" => "ac_running.yml",
        "label" => "master", "project_id" => "123"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "running", 3_000)

    ppl_ids =
      Enum.map(1..5, fn _ ->
        {:ok, %{ppl_id: ppl_id}} =
          %{"repo_name" => "28_auto_cancel", "file_name" => "ac_running.yml",
            "label" => "master", "project_id" => "123"}
          |> Test.Helpers.schedule_request_factory(:local)
          |> Actions.schedule()

        ppl_id
      end)

    # pipeline that was running is stopped
    assert {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "stopping", 1_000)
    assert {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    assert ppl.result == "stopped"

    # all later pipelines are stopped or canceled except the last one
    ppl_ids |> Enum.reverse() |> Enum.with_index()  |> Enum.map(fn {ppl_id, index} ->
      if index > 0 do
        assert {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 1_000)
        assert    ppl.result == "canceled"
               or ppl.result =="stopped"
        assert ppl.result_reason == "strategy"
      else
        assert {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "running", 1_000)
        assert {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
        assert ppl.result == "passed"
      end
    end)

    Test.Helpers.stop_all_loopers(loopers)
  end
end
