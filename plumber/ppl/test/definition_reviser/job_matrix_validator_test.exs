defmodule Ppl.DefinitionReviser.JobMatrixValidator.Test do
  use ExUnit.Case, async: true
  alias Ppl.DefinitionReviser.JobMatrixValidator

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  describe "validate job matrix values" do
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
               {:error,
                {:malformed,
                 "Matrix values for env_var 'MOO' (block 'Block 2', job 'Job 1' must be a non-empty list of strings."}}
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
               {:error,
                {:malformed,
                 "Matrix values for env_var 'MOO' (block 'Block 2', job 'Job 1' must be a non-empty list of strings."}}
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
               {:error,
                {:malformed,
                 "Matrix values for env_var 'MOO' (block 'Block 2', job 'Job 1' must be a non-empty list of strings."}}
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
               {:error,
                {:malformed,
                 "Matrix values for env_var 'MOO' (block 'Block 2', job 'Job 1' must be a non-empty list of strings."}}
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
        "after_pipeline" => [
          %{
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
               {:error,
                {:malformed,
                 "Matrix values for env_var 'MOO' (block 'after_pipeline', job 'Job 1' must be a non-empty list of strings."}}
    end
  end

  describe "validate job matrix environment variables duplicates" do
    test "jobs with duplicate env_var names in matrix fail validation" do
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{
                  "name" => "Job 1",
                  "matrix" => [
                    %{"env_var" => "FOO", "values" => ["BAR", "BAZ"]},
                    %{"env_var" => "FOO", "values" => ["QUX", "QUUX"]}
                  ]
                }
              ]
            }
          }
        ]
      }

      assert JobMatrixValidator.validate(pipeline) ==
               {:error,
                {:malformed,
                 "Duplicate environment variable(s): 'FOO' in job matrix (block 'Block 1', job 'Job 1')."}}
    end

    test "jobs with duplicate env_var names in after_pipeline matrix fail validation" do
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{"name" => "Job 1"}
              ]
            }
          }
        ],
        "after_pipeline" => [
          %{
            "build" => %{
              "jobs" => [
                %{
                  "name" => "Job 1",
                  "matrix" => [
                    %{"env_var" => "MOO", "values" => ["VAL1", "VAL2"]},
                    %{"env_var" => "MOO", "values" => ["VAL3", "VAL4"]}
                  ]
                }
              ]
            }
          }
        ]
      }

      assert JobMatrixValidator.validate(pipeline) ==
               {:error,
                {:malformed,
                 "Duplicate environment variable(s): 'MOO' in job matrix (block 'after_pipeline', job 'Job 1')."}}
    end

    test "jobs with multiple unique env_var names in matrix pass validation" do
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{
                  "name" => "Job 1",
                  "matrix" => [
                    %{"env_var" => "FOO", "values" => ["BAR", "BAZ"]},
                    %{"env_var" => "MOO", "values" => ["MAR", "MAZ"]}
                  ]
                }
              ]
            }
          }
        ]
      }

      assert JobMatrixValidator.validate(pipeline) == {:ok, pipeline}
    end

    test "jobs with proper matrix values in different blocks pass validation" do
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
  end

  describe "validate job matrix size limit" do
    test "job with matrix size exceeding limit fails validation" do
      # Create a matrix with values that will exceed the @max_size (100)
      # We'll create a matrix with 101 values (101 > 100)
      values = Enum.map(1..101, &"value_#{&1}")

      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{
                  "name" => "Job 1",
                  "matrix" => [%{"env_var" => "FOO", "values" => values}]
                }
              ]
            }
          }
        ]
      }

      assert JobMatrixValidator.validate(pipeline) ==
               {:error,
                {:malformed,
                 "Matrix product size exceeds maximum allowed size (100) in job matrix (block 'Block 1', job 'Job 1'). " <>
                   "The matrix product size is calculated as the product of the number of values for each environment variable."}}
    end

    test "job with matrix product size exceeding limit fails validation" do
      # Create a matrix with multiple env vars whose product exceeds the @max_size (100)
      # We'll use 11 x 10 = 110 > 100
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{
                  "name" => "Job 1",
                  "matrix" => [
                    %{"env_var" => "FOO", "values" => Enum.map(1..11, &"foo_#{&1}")},
                    %{"env_var" => "BAR", "values" => Enum.map(1..10, &"bar_#{&1}")}
                  ]
                }
              ]
            }
          }
        ]
      }

      assert JobMatrixValidator.validate(pipeline) ==
               {:error,
                {:malformed,
                 "Matrix product size exceeds maximum allowed size (100) in job matrix (block 'Block 1', job 'Job 1'). " <>
                   "The matrix product size is calculated as the product of the number of values for each environment variable."}}
    end

    test "total matrix size across multiple jobs in a block exceeding limit fails validation" do
      # Create multiple jobs in a block where the total matrix size exceeds the limit
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{
                  "name" => "Job 1",
                  "matrix" => [%{"env_var" => "FOO", "values" => Enum.map(1..60, &"foo_#{&1}")}]
                },
                %{
                  "name" => "Job 2",
                  "matrix" => [%{"env_var" => "BAR", "values" => Enum.map(1..50, &"bar_#{&1}")}]
                }
              ]
            }
          }
        ]
      }

      assert JobMatrixValidator.validate(pipeline) ==
               {:error,
                {:malformed,
                 "Total matrix size exceeds maximum allowed size (100) in block 'Block 1'. " <>
                   "The matrix product size is calculated as the product of the number of values for each environment variable."}}
    end

    test "jobs with matrix size within limit pass validation" do
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{
                  "name" => "Job 1",
                  "matrix" => [
                    %{"env_var" => "FOO", "values" => Enum.map(1..5, &"foo_#{&1}")},
                    %{"env_var" => "BAR", "values" => Enum.map(1..10, &"bar_#{&1}")}
                  ]
                },
                %{
                  "name" => "Job 2",
                  "matrix" => [%{"env_var" => "BAZ", "values" => Enum.map(1..8, &"baz_#{&1}")}]
                }
              ]
            }
          }
        ]
      }

      # Total size: (5*10) + 8 = 58, which is less than 100
      assert JobMatrixValidator.validate(pipeline) == {:ok, pipeline}
    end

    test "jobs with matrix size at the limit pass validation" do
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{
                  "name" => "Job 1",
                  "matrix" => [%{"env_var" => "FOO", "values" => Enum.map(1..50, &"foo_#{&1}")}]
                },
                %{
                  "name" => "Job 2",
                  "matrix" => [%{"env_var" => "BAR", "values" => Enum.map(1..50, &"bar_#{&1}")}]
                }
              ]
            }
          }
        ]
      }

      # Total size: 50 + 50 = 100, which is exactly at the limit
      assert JobMatrixValidator.validate(pipeline) == {:ok, pipeline}
    end

    test "after_pipeline jobs with matrix size exceeding limit fails validation" do
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{
                  "name" => "Job 1",
                  "matrix" => [%{"env_var" => "FOO", "values" => Enum.map(1..10, &"foo_#{&1}")}]
                }
              ]
            }
          }
        ],
        "after_pipeline" => [
          %{
            "build" => %{
              "jobs" => [
                %{
                  "name" => "After Job 1",
                  "matrix" => [%{"env_var" => "BAR", "values" => Enum.map(1..101, &"bar_#{&1}")}]
                }
              ]
            }
          }
        ]
      }

      assert JobMatrixValidator.validate(pipeline) ==
               {:error,
                {:malformed,
                 "Matrix product size exceeds maximum allowed size (100) in job matrix (block 'after_pipeline', job 'After Job 1'). " <>
                   "The matrix product size is calculated as the product of the number of values for each environment variable."}}
    end

    test "total matrix size across multiple jobs in after_pipeline exceeding limit fails validation" do
      pipeline = %{
        "blocks" => [
          %{
            "name" => "Block 1",
            "build" => %{
              "jobs" => [
                %{
                  "name" => "Job 1",
                  "matrix" => [%{"env_var" => "FOO", "values" => Enum.map(1..10, &"foo_#{&1}")}]
                }
              ]
            }
          }
        ],
        "after_pipeline" => [
          %{
            "build" => %{
              "jobs" => [
                %{
                  "name" => "After Job 1",
                  "matrix" => [%{"env_var" => "BAR", "values" => Enum.map(1..60, &"bar_#{&1}")}]
                },
                %{
                  "name" => "After Job 2",
                  "matrix" => [%{"env_var" => "BAZ", "values" => Enum.map(1..50, &"baz_#{&1}")}]
                }
              ]
            }
          }
        ]
      }

      assert JobMatrixValidator.validate(pipeline) ==
               {:error,
                {:malformed,
                 "Total matrix size exceeds maximum allowed size (100) in block 'after_pipeline'. " <>
                   "The matrix product size is calculated as the product of the number of values for each environment variable."}}
    end
  end
end
