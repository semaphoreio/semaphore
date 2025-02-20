defmodule JobMatrix.Handler.Test do
  use ExUnit.Case
  doctest JobMatrix.Handler

  alias JobMatrix.Handler

  test "send valid block to handle_block" do
    env_var1 = %{"env_var" => "ELIXIR", "values" => ["1.3"]}
    env_var2 = %{"env_var" => "ERLANG", "values" => ["18", "19"]}
    env_var3 = %{"env_var" => "PYTHON", "values" => ["2.7", "3.4"]}
    job_env_var = %{"name" => "E1", "value" => "test"}
    initial_job1 = %{"commands" => ["echo job1"], "matrix" => [env_var1, env_var2],
                      "name" => "matrix job 1", "env_vars" => [job_env_var]}
    initial_job2 = %{"commands" => ["echo job2"], "matrix" => [env_var2, env_var3], "name" => "matrix job 2"}
    initial_job3 = %{"commands" => ["echo job3"], "matrix" => [env_var1, env_var2]}
    initial_job4 = %{"commands" => ["echo job4"], "name" => "not matrix job"}
    initial_job5 = %{"commands" => ["echo job5"], "name" => "Parallelism job",
                     "parallelism" => 3}
    build = %{"jobs" => [initial_job1, initial_job2, initial_job3, initial_job4, initial_job5]}
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    block = %{"build" => build, "name" => "build matrix", "agent" => agent, "version" => "v1.0"}

    assert {:ok, result} = Handler.handle_block(block)

    jobs = get_in(result, ["build", "jobs"])
    assert 1 * 2 + 2 * 2 + 1 * 2 + 1 + 3 == length(jobs)

    {jobs1, jobs_rest} = Enum.split(jobs, 2)
    {jobs2, jobs_rest} = Enum.split(jobs_rest, 4)
    {jobs3, jobs_rest} = Enum.split(jobs_rest, 2)
    {jobs4, jobs5}     = Enum.split(jobs_rest, 1)

    expected_names_jobs1 = ["matrix job 1 - ELIXIR=1.3, ERLANG=18",
                            "matrix job 1 - ELIXIR=1.3, ERLANG=19"]
    expected_names_jobs2 = ["matrix job 2 - ERLANG=18, PYTHON=2.7",
                            "matrix job 2 - ERLANG=18, PYTHON=3.4",
                            "matrix job 2 - ERLANG=19, PYTHON=2.7",
                            "matrix job 2 - ERLANG=19, PYTHON=3.4"]
    expected_names_jobs3 = [" - ELIXIR=1.3, ERLANG=18",
                            " - ELIXIR=1.3, ERLANG=19"]
    expected_names_jobs4 = ["not matrix job"]
    expected_names_jobs5 = ["Parallelism job - 1/3",
                            "Parallelism job - 2/3",
                            "Parallelism job - 3/3"]

    check_jobs_names(jobs1, expected_names_jobs1)
    check_jobs_names(jobs2, expected_names_jobs2)
    check_jobs_names(jobs3, expected_names_jobs3)
    check_jobs_names(jobs4, expected_names_jobs4)
    check_jobs_names(jobs5, expected_names_jobs5)

    expected_env_vars_jobs1 =
      [[%{"name" => "E1", "value" => "test"}, %{name: "ELIXIR", value: "1.3"},
        %{name: "ERLANG", value: "18"}],
       [%{"name" => "E1", "value" => "test"}, %{name: "ELIXIR", value: "1.3"},
        %{name: "ERLANG", value: "19"}]]

    expected_env_vars_jobs2 = [[%{name: "ERLANG", value: "18"}, %{name: "PYTHON", value: "2.7"}],
                               [%{name: "ERLANG", value: "18"}, %{name: "PYTHON", value: "3.4"}],
                               [%{name: "ERLANG", value: "19"}, %{name: "PYTHON", value: "2.7"}],
                               [%{name: "ERLANG", value: "19"}, %{name: "PYTHON", value: "3.4"}]]

    expected_env_vars_jobs3 = [[%{name: "ELIXIR", value: "1.3"}, %{name: "ERLANG", value: "18"}],
                               [%{name: "ELIXIR", value: "1.3"}, %{name: "ERLANG", value: "19"}]]

    expected_env_vars_jobs5 = [[%{"name" => "SEMAPHORE_JOB_COUNT", "value" => "3"},
                                %{name: "SEMAPHORE_JOB_INDEX", value: "1"}],
                               [%{"name" => "SEMAPHORE_JOB_COUNT", "value" => "3"},
                                %{name: "SEMAPHORE_JOB_INDEX", value: "2"}],
                               [%{"name" => "SEMAPHORE_JOB_COUNT", "value" => "3"},
                                %{name: "SEMAPHORE_JOB_INDEX", value: "3"}]]

    check_jobs_env_vars(jobs1, expected_env_vars_jobs1)
    check_jobs_env_vars(jobs2, expected_env_vars_jobs2)
    check_jobs_env_vars(jobs3, expected_env_vars_jobs3)
    check_jobs_env_vars(jobs5, expected_env_vars_jobs5)
  end

  defp check_jobs_names(jobs, expected_names) do
    jobs
    |> Enum.zip(expected_names)
    |> Enum.each(fn({job, expected_name}) -> check_job_name(job, expected_name) end)
  end

  defp check_job_name(job, expected_name) do
    name = Map.get(job, "name")
    assert name == expected_name
  end

  defp check_jobs_env_vars(jobs, all_expected_env_vars) do
    jobs
    |> Enum.zip(all_expected_env_vars)
    |> Enum.each(fn({job, expected_env_vars}) -> check_env_vars(job, expected_env_vars) end)
  end

  defp check_env_vars(job, expected_env_vars) do
    env_vars = Map.get(job, "env_vars")
    assert env_vars == expected_env_vars
  end

  test "send block with a Job that doesn't contain 'matrix' field, should pass because its not mandatory" do
    job = %{"commands" => ["echo just a job"], "name" => "regular job"}
    build = %{"jobs" => [job]}
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    block = %{"build" => build, "name" => "regular build", "agent" => agent, "version" => "v1.0"}

    assert {:ok, result} = Handler.handle_block(block)

    jobs = get_in(result, ["build", "jobs"])
    assert [job] = jobs
    assert job["commands"] == ["echo just a job"]
  end

  test "send block of wrong type to handle_block, should fail" do
    block = "this should be a map"
    assert {:error, {:malformed, msg}} = Handler.handle_block(block)
    assert msg == "'block' must be of type Map."
  end

  test "send block without 'build' to handle_block, should fail" do
    block = %{}
    assert {:error, {:malformed, msg}} = Handler.handle_block(block)
    assert msg == ~S(Missing "build" field.)
  end

  test "send block with 'build' of wrong type to handle_block, should fail" do
    block = %{"build" => []}
    assert {:error, {:malformed, msg}} = Handler.handle_block(block)
    assert msg == "[] is not a Map."
  end

  test "send block with 'jobs' of wrong type to handle_block, should fail" do
    build = %{"jobs" => "jobs"}
    block = %{"build" => build}
    assert {:error, {:malformed, msg}} = Handler.handle_block(block)
    assert msg == "'jobs' must be of type List."
  end

  test "send block with 0 jobs, should pass" do
    build = %{"jobs" => []}
    block = %{"build" => build}
    assert {:ok, %{"build" => %{"jobs" => []}}} = Handler.handle_block(block)
  end

  test "send job with matrix of wrong type, should fail" do
    job = %{"commands" => ["echo job"], "matrix" => "matrix"}
    build = %{"jobs" => [job]}
    block = %{"build" => build}
    assert {:error, {:malformed, msg}} = Handler.handle_block(block)
    assert msg == "'matrix' must be non-empty List."
  end

  test "send job with an empty matrix, should fail" do
    job = %{"commands" => ["echo job"], "matrix" => []}
    build = %{"jobs" => [job]}
    block = %{"build" => build}
    assert {:error, {:malformed, msg}} = Handler.handle_block(block)
    assert msg == "'matrix' must be non-empty List."
  end

  test "send job with an axis of invalid type, should fail" do
    axis = "invalid axis type"
    job = %{"commands" => ["echo job"], "matrix" => [axis]}
    build = %{"jobs" => [job]}
    block = %{"build" => build}
    assert {:error, {:malformed, msg}} = Handler.handle_block(block)
    assert msg == "Job matrix: #{inspect axis} missing required field(s)."
  end

  test "send job with an empty axis, should fail" do
    axis = %{}
    job = %{"commands" => ["echo job"], "matrix" => [axis]}
    build = %{"jobs" => [job]}
    block = %{"build" => build}
    assert {:error, {:malformed, msg}} = Handler.handle_block(block)
    assert msg == "Job matrix: #{inspect axis} missing required field(s)."
  end

  test "send job with two axes with same name, should fail" do
    axis = %{"env_var" => "ERLANG", "values" => ["18", "19"]}
    axis1 = %{"env_var" => "ELIXIR", "values" => ["1.5", "1.4"]}
    axis2 = %{"env_var" => "PYTHON", "values" => ["2.7", "3.4"]}
    job = %{"commands" => ["echo job"], "matrix" => [axis1, axis, axis2, axis]}
    build = %{"jobs" => [job]}
    block = %{"build" => build}
    assert {:error, {:malformed, msg}} = Handler.handle_block(block)
    assert msg == "Duplicate name: 'ERLANG' in Matrix."
  end

  test "send job with axis that has a name of invalid type, should fail" do
    axis = %{"env_var" => 5}
    job = %{"commands" => ["echo job"], "matrix" => [axis]}
    build = %{"jobs" => [job]}
    block = %{"build" => build}
    assert {:error, {:malformed, msg}} = Handler.handle_block(block)
    assert msg == "Job matrix: #{inspect axis} missing required field(s)."
  end

  test "send job with axis that has a values of invalid type, should fail" do
    axis = %{"env_var" => "name", "values" => 5}
    job = %{"commands" => ["echo job"], "matrix" => [axis]}
    build = %{"jobs" => [job]}
    block = %{"build" => build}
    assert {:error, {:malformed, msg}} = Handler.handle_block(block)
    assert msg == "Job matrix: #{inspect axis} missing required field(s)."
  end

  test "send job with axis that has 0 values, should fail" do
    axis = %{"env_var" => "name", "values" => []}
    job = %{"commands" => ["echo job"], "matrix" => [axis]}
    build = %{"jobs" => [job]}
    block = %{"build" => build}
    assert {:error, {:malformed, msg}} = Handler.handle_block(block)
    assert msg == "List 'values' in job matrix must not be empty."
  end

end
