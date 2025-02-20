defmodule JobMatrix.ParallelismHandler.Test do
  use ExUnit.Case

  alias JobMatrix.ParallelismHandler

  test "block definition without parallelism is not changed" do
    job   = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    build = %{"jobs" => [job], "agent" => agent}
    definition = %{"name" => "Block 1", "build" => build}

    assert {:ok, ret_val} = ParallelismHandler.parallelize_jobs(definition)

    assert definition == ret_val
  end

  test "parallelism is changed into matrix and added to block definition" do
    job   = %{"name" => "job1", "commands" => ["echo foo", "echo bar"],
              "parallelism" => 3}
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    build = %{"jobs" => [job], "agent" => agent}
    definition = %{"name" => "Block 1", "build" => build}

    assert {:ok, %{"build" => new_build}} = ParallelismHandler.parallelize_jobs(definition)

    assert %{"name" => "job1",
             "commands" => ["echo foo", "echo bar"],
             "matrix" =>
              [%{"env_var" => "SEMAPHORE_JOB_INDEX", "values" => ["1", "2", "3"]}],
             "env_vars" => [%{"name" => "SEMAPHORE_JOB_COUNT", "value" => "3"}]
            }
             == new_build |> Map.get("jobs") |> Enum.at(0)
  end

  test "the SEMAPHORE_JOB_COUNT env var is appended to existing env vars in block definition" do
    job   = %{"name" => "job1", "commands" => ["echo foo", "echo bar"],
              "parallelism" => 3, "env_vars" => [%{"name" => "EXISTING", "value" => "test"}]}
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    build = %{"jobs" => [job], "agent" => agent}
    definition = %{"name" => "Block 1", "build" => build}

    assert {:ok, %{"build" => new_build}} = ParallelismHandler.parallelize_jobs(definition)

    assert %{"name" => "job1",
             "commands" => ["echo foo", "echo bar"],
             "matrix" =>
              [%{"env_var" => "SEMAPHORE_JOB_INDEX", "values" => ["1", "2", "3"]}],
             "env_vars" => [
               %{"name" => "EXISTING", "value" => "test"},
               %{"name" => "SEMAPHORE_JOB_COUNT", "value" => "3"}
             ]
            }
             == new_build |> Map.get("jobs") |> Enum.at(0)
  end
end
