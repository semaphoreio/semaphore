defmodule Ppl.DefinitionReviser.ParallelismValidator.Test do
  use ExUnit.Case, async: true
  alias Ppl.DefinitionReviser.ParallelismValidator

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  test "jobs with proper parallelisms pass validation" do
    pipeline = %{
      "blocks" => [
        %{
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "parallelism" => 4
              },
              %{"name" => "Job 2"}
            ]
          }
        },
        %{
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "parallelism" => 2
              }
            ]
          }
        }
      ]
    }

    assert ParallelismValidator.validate(pipeline) == {:ok, pipeline}
  end

  test "jobs with empty string of parallelism fail validation" do
    pipeline = %{
      "blocks" => [
        %{
          "name" => "Block 1",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "parallelism" => 4
              },
              %{"name" => "Job 2"}
            ]
          }
        },
        %{
          "name" => "Block 2",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "parallelism" => ""
              }
            ]
          }
        }
      ]
    }

    assert ParallelismValidator.validate(pipeline) ==
             {:error, {:malformed, "Parallelism value for job 'Job 1' in block 'Block 2' is not an integer."}}
  end

  test "jobs with null parallelism fail validation" do
    pipeline = %{
      "blocks" => [
        %{
          "name" => "Block 1",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "parallelism" => 4
              },
              %{"name" => "Job 2"}
            ]
          }
        },
        %{
          "name" => "Block 2",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "parallelism" => nil
              }
            ]
          }
        }
      ]
    }

    assert ParallelismValidator.validate(pipeline) ==
             {:error, {:malformed, "Parallelism value for job 'Job 1' in block 'Block 2' is not an integer."}}
  end

  test "jobs with parallelism as string fail validation" do
    pipeline = %{
      "blocks" => [
        %{
          "name" => "Block 1",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "parallelism" => 4
              },
              %{"name" => "Job 2"}
            ]
          }
        },
        %{
          "name" => "Block 2",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "parallelism" => "2"
              }
            ]
          }
        }
      ]
    }

    assert ParallelismValidator.validate(pipeline) ==
             {:error, {:malformed, "Parallelism value for job 'Job 1' in block 'Block 2' is not an integer."}}
  end

  test "jobs with parallelism as float fail validation" do
    pipeline = %{
      "blocks" => [
        %{
          "name" => "Block 1",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "parallelism" => 4
              },
              %{"name" => "Job 2"}
            ]
          }
        },
        %{
          "name" => "Block 2",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "parallelism" => 2.0
              }
            ]
          }
        }
      ]
    }

    assert ParallelismValidator.validate(pipeline) ==
             {:error, {:malformed, "Parallelism value for job 'Job 1' in block 'Block 2' is not an integer."}}
  end


  test "jobs with parallelism as string in an after_pipeline block fail validation" do
    pipeline = %{
      "blocks" => [
        %{
          "name" => "Block 1",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "parallelism" => 4
              },
              %{"name" => "Job 2"}
            ]
          }
        },
        %{
          "name" => "Block 2",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1"
              }
            ]
          }
        }
      ],
      "after_pipeline" => [%{
        "build" => %{
          "jobs" => [
            %{
              "name" => "Job 1",
              "parallelism" => "2"
            }
          ]
        }
      }]
    }

    assert ParallelismValidator.validate(pipeline) ==
             {:error, {:malformed, "Parallelism value for job 'Job 1' in block 'after_pipeline' is not an integer."}}
  end
end
