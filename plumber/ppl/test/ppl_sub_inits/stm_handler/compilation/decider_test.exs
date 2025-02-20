defmodule Ppl.PplSubInits.STMHandler.Compilation.Decider.Test do
  use ExUnit.Case, async: false

  alias Ppl.PplSubInits.STMHandler.Compilation.Decider

  @blacklisted__org UUID.uuid4()

  test "use compilation if definition is nil" do
    assert Decider.decide_on_compilation(nil, %{}) == {:ok, "compilation"}
  end

  test "use compilation if yaml contains change_in" do
    definition = %{
      "name" => "Pipeline 1",
      "blocks" => [
        %{
          "run" => %{
            "when" => "change_in('lib')"
          }
        }
      ]
    }

    assert Decider.decide_on_compilation(definition, %{}) == {:ok, "compilation"}
  end

  test "use compilation if yaml contains templates expressions" do
    definition = %{
      "name" => "Pipeline ${{parameters.Name}}",
      "blocks" => [
        %{
          "run" => %{
            "when" => true
          }
        }
      ]
    }

    assert Decider.decide_on_compilation(definition, %{}) == {:ok, "compilation"}
  end

  test "use compilation if yaml contains complex templates expression" do
    definition = %{
      "name" => "Pipeline ${{ parameters.Name | title }}",
      "blocks" => [
        %{
          "run" => %{
            "when" => "change_in('lib'})"
          }
        }
      ]
    }

    assert Decider.decide_on_compilation(definition, %{}) == {:ok, "compilation"}
  end

  test "use compilation if yaml contains parallelism expression" do
    definition = %{
      "name" => "Pipeline 1",
      "blocks" => [
        %{
          "run" => %{
            "when" => "change_in('lib'})"
          },
          "task" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "parallelism" => "%{{ parameters.Parallelism }}",
                "commands" => [
                  "echo 'Hello World'"
                ]
              }
            ]
          }
        }
      ]
    }

    assert Decider.decide_on_compilation(definition, %{}) == {:ok, "compilation"}
  end

  test "use compilation if yaml contains matrix values expression" do
    definition = %{
      "name" => "Pipeline 1",
      "blocks" => [
        %{
          "run" => %{
            "when" => "change_in('lib'})"
          },
          "task" => %{
            "jobs" => [
              %{
                "name" => "Job 1",
                "matrix" => [
                  %{
                    "env_var" => "ENV_VAR",
                    "values" => "%{{ parameters.EnvVars | splitList \",\"}}"
                  }
                ],
                "commands" => [
                  "echo 'Hello World'"
                ]
              }
            ]
          }
        }
      ]
    }

    assert Decider.decide_on_compilation(definition, %{}) == {:ok, "compilation"}
  end

  test "use compilation if yaml contains parallelism expression in after_pipeline block" do
    definition = %{
      "name" => "Pipeline 1",
      "blocks" => [
        %{
          "run" => %{
            "when" => "change_in('lib'})"
          }
        }
      ],
      "after_pipeline" => %{
        "task" => %{
          "jobs" => [
            %{
              "name" => "Job 1",
              "parallelism" => "%{{ parameters.Parallelism }}",
              "commands" => [
                "echo 'Hello World'"
              ]
            }
          ]
        }
      }
    }

    assert Decider.decide_on_compilation(definition, %{}) == {:ok, "compilation"}
  end

  test "use compilation if yaml contains matrix values expression in after_pipeline block" do
    definition = %{
      "name" => "Pipeline 1",
      "blocks" => [
        %{
          "run" => %{
            "when" => "change_in('lib'})"
          }
        }
      ],
      "after_pipeline" => %{
        "task" => %{
          "jobs" => [
            %{
              "name" => "Job 1",
              "matrix" => [
                %{
                  "env_var" => "ENV_VAR",
                  "values" => "%{{ parameters.EnvVars | splitList \",\"}}"
                }
              ],
              "commands" => [
                "echo 'Hello World'"
              ]
            }
          ]
        }
      }
    }

    assert Decider.decide_on_compilation(definition, %{}) == {:ok, "compilation"}
  end

  test "use compilation if yaml contains both templates expression and change_in" do
    definition = %{
      "name" => "Pipeline ${{parameters.Name}}",
      "blocks" => [
        %{
          "run" => %{
            "when" => "change_in('lib'})"
          }
        }
      ]
    }

    assert Decider.decide_on_compilation(definition, %{}) == {:ok, "compilation"}
  end

  test "use compilation if both organization and project pre-flight checks are defined" do
    definition = %{
      "name" => "Pipeline 1",
      "blocks" => [
        %{
          "run" => %{
            "when" => true
          }
        }
      ]
    }

    pre_flight_checks = %{
      "organization_pfc" => %{
        "commands" => [
          "./security_script.sh"
        ],
        "secrets" => [],
        "agent" => %{
          "machine_type" => "e1-standard-2",
          "os_image" => "ubuntu2004"
        }
      },
      "project_pfc" => %{
        "commands" => [
          "./security_script.sh"
        ],
        "secrets" => []
      }
    }

    assert Decider.decide_on_compilation(definition, pre_flight_checks) == {:ok, "compilation"}
  end

  test "use compilation if only organization pre-flight checks are defined" do
    definition = %{
      "name" => "Pipeline 1",
      "blocks" => [
        %{
          "run" => %{
            "when" => true
          }
        }
      ]
    }

    pre_flight_checks = %{
      "organization_pfc" => %{
        "commands" => [
          "./security_script.sh"
        ],
        "secrets" => [],
        "agent" => %{
          "machine_type" => "e1-standard-2",
          "os_image" => "ubuntu2004"
        }
      },
      "project_pfc" => nil
    }

    assert Decider.decide_on_compilation(definition, pre_flight_checks) == {:ok, "compilation"}
  end

  test "use compilation if only project pre-flight checks are defined" do
    definition = %{
      "name" => "Pipeline 1",
      "blocks" => [
        %{
          "run" => %{
            "when" => true
          }
        }
      ]
    }

    pre_flight_checks = %{
      "organization_pfc" => nil,
      "project_pfc" => %{
        "commands" => [
          "./security_script.sh"
        ],
        "secrets" => []
      }
    }

    assert Decider.decide_on_compilation(definition, pre_flight_checks) == {:ok, "compilation"}
  end

  test "don't use compilation if yamls has no change_ins or templates expressions " <>
         "and pre-flight checks are both nils" do
    definition = %{
      "name" => "Pipeline 1",
      "blocks" => [
        %{
          "run" => %{
            "when" => true
          }
        }
      ]
    }

    pre_flight_checks = %{
      "organization_pfc" => nil,
      "project_pfc" => nil
    }

    assert Decider.decide_on_compilation(definition, pre_flight_checks) == {:ok, "regular_init"}
  end

  test "don't use compilation if yamls has no change_ins or templates expressions " <>
         "and pre-flight checks are undefined" do
    definition = %{
      "name" => "Pipeline 1",
      "blocks" => [
        %{
          "run" => %{
            "when" => true
          }
        }
      ]
    }

    assert Decider.decide_on_compilation(definition, :undefined) == {:ok, "regular_init"}
  end

  test "match all variations of valid templates expressions" do
    valid_inputs = [
      "${{parameters.TEST_VAL_1}}",
      "${{  parameters.TEST_VAL_1}}",
      "${{  parameters.TEST_VAL_1  }}",
      "Hello ${{parameters.TEST_VAL_3}}",
      "${{parameters.TEST_VAL_3}} world",
      "Hello ${{parameters.TEST_VAL_3}} world",
      "Hello ${{parameters.TEST_VAL_1}} ${{parameters.TEST_VAL_2}}",
      "${{parameters.TEST_VAL_1 | trim | upper }}",
      "${{TEST_VAL_1}}",
      "${{parametersTEST_VAL_1}}",
      "${{parameters.}}",
      "%{{parameters.TEST_VAL_1}}",
      "%{{  parameters.TEST_VAL_1}}",
      "%{{  parameters.TEST_VAL_1  }}",
      "Hello %{{parameters.TEST_VAL_3}}",
      "%{{parameters.TEST_VAL_3}} world",
      "Hello %{{parameters.TEST_VAL_3}} world",
      "Hello %{{parameters.TEST_VAL_1}} %{{parameters.TEST_VAL_2}}",
      "%{{TEST_VAL_1}}",
      "%{{parametersTEST_VAL_1}}",
      "%{{parameters.}}",
      "%{{ parameters.TEST_VAL_1 | trim | upper }}",
      "${{ ${{parameters.TEST_VAL_1}} }}",
      "${{${{parameters.TEST_VAL_1}}}}",
      "${{%{{parameters.TEST_VAL_1}}}}",
      "%{{ %{{parameters.TEST_VAL_1}} }}",
      "%{{ ${{parameters.TEST_VAL_1}} }}",
      "%{{${{parameters.TEST_VAL_1}}}}",
      "%{{%{{parameters.TEST_VAL_1}}}}"
    ]

    invalid_inputs = [
      "{{parameters.TEST_VAL_1}}",
      "${parameters.TEST_VAL_1}}",
      "$parameters.TEST_VAL_1}}",
      "${{parameters.TEST_VAL_1}",
      "${{parameters.TEST_VAL_1",
      "{{parameters.TEST_VAL_2}}",
      "%{parameters.TEST_VAL_1}}",
      "%parameters.TEST_VAL_1}}",
      "%{{parameters.TEST_VAL_1}",
      "%{{parameters.TEST_VAL_1"
    ]

    Enum.map(valid_inputs, &assert(Decider.templates_expression("name", &1), "expression: #{&1}"))

    Enum.map(
      invalid_inputs,
      &refute(Decider.templates_expression("name", &1), "expression: #{&1}")
    )
  end

  test "use compilation if yaml contains commands_files" do
    definition = %{
      "name" => "Pipeline",
      "blocks" => [
        %{
          "task" => %{
            "jobs" => [
              %{
                "commands_file" => "file_with_commands.txt"
              }
            ]
          }
        }
      ]
    }

    assert Decider.decide_on_compilation(definition, %{}) == {:ok, "compilation"}
  end

  test "don't use compilation if templates expression is only used in commands and no other conditions are met" do
    definition = %{
      "name" => "Pipeline",
      "blocks" => [
        %{
          "task" => %{
            "jobs" => [
              %{
                "commands" => [
                  "echo 123",
                  "echo ${{ parameters.Name | title }}"
                ]
              }
            ]
          }
        }
      ]
    }

    assert Decider.decide_on_compilation(definition, %{}) == {:ok, "regular_init"}
  end
end
