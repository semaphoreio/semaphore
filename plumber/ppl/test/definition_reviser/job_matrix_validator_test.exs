defmodule Ppl.DefinitionReviser.JobMatrixValidator.Test do
  use ExUnit.Case, async: true
  alias Ppl.DefinitionReviser.JobMatrixValidator

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  test "jobs with proper matrix values pass validation" do
    pipeline = %{
      "blocks" => [
        %{
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "matrix" => [%{"env_var" => "FOO", "values" => ["BAR", "BAZ"]}]
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
                "matrix" => [%{"env_var" => "MOO", "values" => ["MAR", "MAZ"]}]
              }
            ]
          }
        }
      ]
    }

    assert JobMatrixValidator.validate(pipeline) == {:ok, pipeline}
  end

  test "jobs with empty array of matrix values fail validation" do
    pipeline = %{
      "blocks" => [
        %{
          "name" => "Block 1",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "matrix" => [%{"env_var" => "FOO", "values" => ["BAR", "BAZ"]}]
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
                "matrix" => [%{"env_var" => "MOO", "values" => []}]
              }
            ]
          }
        }
      ]
    }

    assert JobMatrixValidator.validate(pipeline) ==
             {:error, {:malformed, "Matrix values for env_var 'MOO' (block 'Block 2', job 'Job 1' must be a non-empty list of strings."}}
  end

  test "jobs with empty string of matrix values fail validation" do
    pipeline = %{
      "blocks" => [
        %{
          "name" => "Block 1",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "matrix" => [%{"env_var" => "FOO", "values" => ["BAR", "BAZ"]}]
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
                "matrix" => [%{"env_var" => "MOO", "values" => ""}]
              }
            ]
          }
        }
      ]
    }

    assert JobMatrixValidator.validate(pipeline) ==
             {:error, {:malformed, "Matrix values for env_var 'MOO' (block 'Block 2', job 'Job 1' must be a non-empty list of strings."}}
  end

  test "jobs with null matrix values fail validation" do
    pipeline = %{
      "blocks" => [
        %{
          "name" => "Block 1",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "matrix" => [%{"env_var" => "FOO", "values" => ["BAR", "BAZ"]}]
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
                "matrix" => [%{"env_var" => "MOO", "values" => nil}]
              }
            ]
          }
        }
      ]
    }

    assert JobMatrixValidator.validate(pipeline) ==
             {:error, {:malformed, "Matrix values for env_var 'MOO' (block 'Block 2', job 'Job 1' must be a non-empty list of strings."}}
  end

  test "jobs with matrix values as string fail validation" do
    pipeline = %{
      "blocks" => [
        %{
          "name" => "Block 1",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "matrix" => [%{"env_var" => "FOO", "values" => ["BAR", "BAZ"]}]
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
                "matrix" => [%{"env_var" => "MOO", "values" => "FOOBAR"}]
              }
            ]
          }
        }
      ]
    }

    assert JobMatrixValidator.validate(pipeline) ==
             {:error, {:malformed, "Matrix values for env_var 'MOO' (block 'Block 2', job 'Job 1' must be a non-empty list of strings."}}
  end

  test "jobs with matrix values as string in after_pipeline job fail validation" do
    pipeline = %{
      "blocks" => [
        %{
          "name" => "Block 1",
          "build" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "matrix" => [%{"env_var" => "FOO", "values" => ["BAR", "BAZ"]}]
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
              "matrix" => [%{"env_var" => "MOO", "values" => "FOOBAR"}]
            }
          ]
        }
      }]
    }

    assert JobMatrixValidator.validate(pipeline) ==
             {:error, {:malformed, "Matrix values for env_var 'MOO' (block 'after_pipeline', job 'Job 1' must be a non-empty list of strings."}}
  end
end
