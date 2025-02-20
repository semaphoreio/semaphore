defmodule Ppl.DefinitionReviser.JobsGodfather.Test do
  use Ppl.IntegrationCase

  alias Ppl.DefinitionReviser.JobsGodfather
  alias Ppl.Actions
  alias InternalApi.Plumber.Pipeline.{Result, ResultReason}

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  test "jobs and boosters with all unique names pass validation" do
    pipeline = %{"blocks" =>
      [%{"build" => %{"jobs" => [%{"name" => "Job 1"}, %{"name" => "Job 2"}]}},
       %{"build" => %{"jobs" => [%{"name" => "Job 1"},]}},
       %{"build" => %{"boosters" => [%{"name" => "Booster 3"},]}}]
    }
    assert(
      JobsGodfather.name_jobs(pipeline) == {:ok, pipeline}
    )
  end

  @tag :integration
  test "jobs with duplicate names fail validation" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "21_jobs_with_duplicate_names"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

      loopers = Test.Helpers.start_all_loopers()

      assert {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 4_000)
      assert ppl.result == "failed"
      assert ppl.result_reason == "malformed"
      assert String.contains?(ppl.error_description, ":duplicate_names")

      Test.Helpers.stop_all_loopers(loopers)
  end

  test "boosters with duplicate names fail validation" do
    pipeline = %{"blocks" =>
      [%{"build" => %{"boosters" => [%{"name" => "Booster 1"}, %{"name" => "Booster 1"}]}},
       %{"build" => %{"boosters" => [%{"name" => "Booster 1"}]}}]
    }
    expected = {:error, {:malformed, {:duplicate_names, [["Booster 1", "Booster 1"]]}}}
    assert JobsGodfather.name_jobs(pipeline) == expected
  end

  test "jobs and boosters with duplicate names fail validation" do
    pipeline = %{"blocks" =>
      [%{"build" => %{"jobs" => [%{"name" => "Foo"}, %{"name" => "Bar"}],
                     "boosters" => [%{"name" => "Foo"},]}}]
     }
     expected = {:error, {:malformed, {:duplicate_names, [["Foo", "Foo"]]}}}
     assert JobsGodfather.name_jobs(pipeline) == expected
   end

  test "blank job names are filled" do
    pipeline = %{"blocks" =>
      [%{"build" => %{"jobs" => [%{"name" => "Job 1"}, %{"name" => nil}]}},
       %{"build" => %{"jobs" => [%{},]}}]
    }
    pipeline_expected = %{"blocks" =>
      [%{"build" => %{"jobs" => [%{"name" => "Job 1"}, %{"name" => "Nameless 1"}]}},
       %{"build" => %{"jobs" => [%{"name" => "Nameless 1"},]}}]
     }
    assert(
      JobsGodfather.name_jobs(pipeline) == {:ok, pipeline_expected}
    )
  end

  test "blank booster names are filled" do
    pipeline = %{"blocks" =>
      [%{"build" => %{"boosters" => [%{"name" => "Booster 1"}, %{"name" => nil}]}},
       %{"build" => %{"boosters" => [%{}]}}]
    }
    pipeline_expected = %{"blocks" =>
      [%{"build" => %{"boosters" => [%{"name" => "Booster 1"}, %{"name" => "Nameless 1"}]}},
       %{"build" => %{"boosters" => [%{"name" => "Nameless 1"},]}}]
     }
    assert(
      JobsGodfather.name_jobs(pipeline) == {:ok, pipeline_expected}
    )
  end

  test "jobs and boosters already named 'Nameless x'" do
    pipeline = %{"blocks" =>
      [%{"build" => %{"jobs" => [%{"name" => "Nameless 1"}, %{"name" => nil}, %{"name" => "Nameless 2"}],
                     "boosters" => [%{"name" => nil},]}}]
     }
    pipeline_expected = %{"blocks" =>
      [%{"build" => %{"jobs" => [%{"name" => "Nameless 1"}, %{"name" => "Nameless 3"}, %{"name" => "Nameless 2"}],
                     "boosters" => [%{"name" => "Nameless 4"},]}}]
     }
    assert(
      JobsGodfather.name_jobs(pipeline) == {:ok, pipeline_expected}
    )
  end

  test "booster already named 'Nameless x'" do
    pipeline = %{"blocks" =>
      [%{"build" => %{"boosters" => [%{"name" => "Nameless 1"}, %{"name" => "Job 2"}]}},
       %{"build" => %{"boosters" => [%{"name" => nil},]}}]
    }
    pipeline_expected = %{"blocks" =>
      [%{"build" => %{"boosters" => [%{"name" => "Nameless 1"}, %{"name" => "Job 2"}]}},
       %{"build" => %{"boosters" => [%{"name" => "Nameless 1"},]}}]
     }
    assert(
      JobsGodfather.name_jobs(pipeline) == {:ok, pipeline_expected}
    )
  end

  test "jobs and boosters together" do
    pipeline = %{"blocks" =>
      [%{"build" => %{"boosters" => [%{"name" => "Nameless 1"}, %{"name" => "Booster 2"}]}},
       %{"build" => %{"boosters" => [%{"name" => nil},]}},
       %{"build" => %{"jobs" => [%{"name" => nil},]}}]
    }
    pipeline_expected = %{"blocks" =>
      [%{"build" => %{"boosters" => [%{"name" => "Nameless 1"}, %{"name" => "Booster 2"}]}},
       %{"build" => %{"boosters" => [%{"name" => "Nameless 1"},]}},
       %{"build" => %{"jobs" => [%{"name" => "Nameless 1"},]}}]
     }
    assert(
      JobsGodfather.name_jobs(pipeline) == {:ok, pipeline_expected}
    )
  end
end
