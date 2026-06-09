defmodule Ppl.PplSubInits.STMHandler.Compilation.Definition.Test do
  use ExUnit.Case, async: false
  import Mock

  alias Ppl.PplSubInits.STMHandler.Compilation.Definition
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias InternalApi.PreFlightChecksHub, as: PfcApi
  alias Ppl.Actions

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  describe "when in test environment" do
    test "and secrets are defined in pipeline request then it is included" do
      ppl_req = %{request_args: %{"request_secrets" => [%{"name" => "secret123"}]}}

      settings = %{
        "plan_machine_type" => "e2-standard-4",
        "plan_os_image" => "ubuntu2204"
      }

      assert {:ok, definition} = Definition.form_definition(ppl_req, nil, settings, :test)

      assert definition ==
               %{
                 "agent" => %{
                   "machine" => %{
                     "type" => "e2-standard-4",
                     "os_image" => "ubuntu2204"
                   }
                 },
                 "jobs" => [
                   %{
                     "name" => "Only used in tests",
                     "commands" => ["echo Test"],
                     "secrets" => [%{"name" => "secret123"}]
                   }
                 ]
               }
    end

    test "and pre_flight checks are undefined then simple definition is used" do
      pre_flight_checks = :undefined

      settings = %{
        "plan_machine_type" => "e2-standard-4",
        "plan_os_image" => "ubuntu2204",
        "custom_machine_type" => "f1-standard-2",
        "custom_os_image" => "ubuntu2004"
      }

      assert {:ok, definition} =
               Definition.form_definition(%{}, pre_flight_checks, settings, :test)

      assert definition ==
               %{
                 "agent" => %{
                   "machine" => %{
                     "type" => "f1-standard-2",
                     "os_image" => "ubuntu2004"
                   }
                 },
                 "jobs" => [
                   %{
                     "name" => "Only used in tests",
                     "commands" => ["echo Test"],
                     "secrets" => []
                   }
                 ]
               }
    end

    test "and pre-flight checks are nil then simple definition is used" do
      pre_flight_checks = nil

      settings = %{
        "plan_machine_type" => "e2-standard-4",
        "plan_os_image" => "ubuntu2204"
      }

      assert {:ok, definition} =
               Definition.form_definition(%{}, pre_flight_checks, settings, :test)

      assert definition ==
               %{
                 "agent" => %{
                   "machine" => %{
                     "type" => "e2-standard-4",
                     "os_image" => "ubuntu2204"
                   }
                 },
                 "jobs" => [
                   %{
                     "name" => "Only used in tests",
                     "commands" => ["echo Test"],
                     "secrets" => []
                   }
                 ]
               }
    end

    test "and pre-flight checks are empty map then simple definition is used" do
      pre_flight_checks = %{}

      settings = %{
        "plan_machine_type" => "e2-standard-4",
        "plan_os_image" => "ubuntu2204",
        "custom_machine_type" => "f1-standard-2",
        "custom_os_image" => "ubuntu2004"
      }

      assert {:ok, definition} =
               Definition.form_definition(%{}, pre_flight_checks, settings, :test)

      assert definition ==
               %{
                 "agent" => %{
                   "machine" => %{
                     "type" => "f1-standard-2",
                     "os_image" => "ubuntu2004"
                   }
                 },
                 "jobs" => [
                   %{
                     "name" => "Only used in tests",
                     "commands" => ["echo Test"],
                     "secrets" => []
                   }
                 ]
               }
    end

    test "and pre-flight checks are defined but both empty" <>
           "then agent definition and organization command set are used" do
      pre_flight_checks = %{
        "organization_pfc" => nil,
        "project_pfc" => nil
      }

      settings = %{
        "custom_machine_type" => "f1-standard-2",
        "custom_os_image" => "ubuntu2004"
      }

      assert {:ok, definition} =
               Definition.form_definition(%{}, pre_flight_checks, settings, :test)

      assert definition ==
               %{
                 "agent" => %{
                   "machine" => %{
                     "type" => "f1-standard-2",
                     "os_image" => "ubuntu2004"
                   }
                 },
                 "jobs" => [
                   %{
                     "name" => "Only used in tests",
                     "commands" => ["echo Test"],
                     "secrets" => []
                   }
                 ]
               }
    end

    test "and only organization pre-flight checks are defined " <>
           "then agent definition and organization command set are used" do
      pre_flight_checks = %{
        "organization_pfc" => organization_pfc(),
        "project_pfc" => nil
      }

      settings = %{
        "custom_machine_type" => "f1-standard-2",
        "custom_os_image" => "ubuntu2204"
      }

      assert {:ok, definition} =
               Definition.form_definition(%{}, pre_flight_checks, settings, :test)

      assert definition ==
               %{
                 "agent" => %{
                   "machine" => %{
                     "type" => "f1-standard-2",
                     "os_image" => "ubuntu2204"
                   }
                 },
                 "jobs" => [
                   %{
                     "name" => "Only used in tests",
                     "commands" => [
                       "echo Test",
                       "./org_security_script.sh"
                     ],
                     "secrets" => [%{"name" => "ORG_SECRET"}]
                   }
                 ]
               }
    end

    test "and only project pre-flight checks are defined " <> "then project command set is used" do
      pre_flight_checks = %{
        "organization_pfc" => nil,
        "project_pfc" => project_pfc()
      }

      settings = %{
        "custom_machine_type" => "f1-standard-2",
        "custom_os_image" => "ubuntu2004"
      }

      assert {:ok, definition} =
               Definition.form_definition(%{}, pre_flight_checks, settings, :test)

      assert definition ==
               %{
                 "agent" => %{
                   "machine" => %{
                     "type" => "e1-standard-4",
                     "os_image" => "ubuntu1804"
                   }
                 },
                 "jobs" => [
                   %{
                     "name" => "Only used in tests",
                     "commands" => [
                       "echo Test",
                       "./prj_security_script.sh"
                     ],
                     "secrets" => [%{"name" => "PRJ_SECRET"}]
                   }
                 ]
               }
    end

    test "and project pre-flight checks are defined without agent definition then project command set is used" do
      pre_flight_checks = %{
        "organization_pfc" => nil,
        "project_pfc" => project_pfc() |> Map.delete("agent")
      }

      settings = %{
        "custom_machine_type" => "f1-standard-2",
        "custom_os_image" => "ubuntu2004"
      }

      assert {:ok, definition} =
               Definition.form_definition(%{}, pre_flight_checks, settings, :test)

      assert definition ==
               %{
                 "agent" => %{
                   "machine" => %{
                     "type" => "f1-standard-2",
                     "os_image" => "ubuntu2004"
                   }
                 },
                 "jobs" => [
                   %{
                     "name" => "Only used in tests",
                     "commands" => [
                       "echo Test",
                       "./prj_security_script.sh"
                     ],
                     "secrets" => [%{"name" => "PRJ_SECRET"}]
                   }
                 ]
               }
    end

    test "and project pre-flight checks are defined with nil agent definition then project command set is used" do
      pre_flight_checks = %{
        "organization_pfc" => nil,
        "project_pfc" => project_pfc() |> Map.put("agent", nil)
      }

      settings = %{
        "plan_machine_type" => "e2-standard-4",
        "plan_os_image" => "ubuntu2204"
      }

      assert {:ok, definition} =
               Definition.form_definition(%{}, pre_flight_checks, settings, :test)

      assert definition ==
               %{
                 "agent" => %{
                   "machine" => %{
                     "type" => "e2-standard-4",
                     "os_image" => "ubuntu2204"
                   }
                 },
                 "jobs" => [
                   %{
                     "name" => "Only used in tests",
                     "commands" => [
                       "echo Test",
                       "./prj_security_script.sh"
                     ],
                     "secrets" => [%{"name" => "PRJ_SECRET"}]
                   }
                 ]
               }
    end

    test "and both organization and project pre-flight checks are defined " <>
           "then agent definition and both command sets are used" do
      pre_flight_checks = %{
        "organization_pfc" => organization_pfc(),
        "project_pfc" => project_pfc()
      }

      settings = %{
        "plan_machine_type" => "e2-standard-4",
        "plan_os_image" => "ubuntu2204",
        "custom_machine_type" => "f1-standard-2",
        "custom_os_image" => "ubuntu2004"
      }

      assert {:ok, definition} =
               Definition.form_definition(%{}, pre_flight_checks, settings, :test)

      assert definition ==
               %{
                 "agent" => %{
                   "machine" => %{
                     "type" => "e1-standard-4",
                     "os_image" => "ubuntu1804"
                   }
                 },
                 "jobs" => [
                   %{
                     "name" => "Only used in tests",
                     "commands" => [
                       "echo Test",
                       "./org_security_script.sh",
                       "./prj_security_script.sh"
                     ],
                     "secrets" => [
                       %{"name" => "ORG_SECRET"},
                       %{"name" => "PRJ_SECRET"}
                     ]
                   }
                 ]
               }
    end

    test "and secrets are defined in ppl request and pre-flight checks " <>
           "then all secrets are included" do
      pre_flight_checks = %{
        "organization_pfc" => organization_pfc(),
        "project_pfc" => project_pfc()
      }

      settings = %{
        "plan_machine_type" => "e2-standard-4",
        "plan_os_image" => "ubuntu2204",
        "custom_machine_type" => "f1-standard-2",
        "custom_os_image" => "ubuntu2004"
      }

      ppl_req = %{request_args: %{"request_secrets" => [%{"name" => "secret123"}]}}

      assert {:ok, definition} =
               Definition.form_definition(ppl_req, pre_flight_checks, settings, :test)

      assert definition ==
               %{
                 "agent" => %{
                   "machine" => %{
                     "type" => "e1-standard-4",
                     "os_image" => "ubuntu1804"
                   }
                 },
                 "jobs" => [
                   %{
                     "name" => "Only used in tests",
                     "commands" => [
                       "echo Test",
                       "./org_security_script.sh",
                       "./prj_security_script.sh"
                     ],
                     "secrets" => [
                       %{"name" => "secret123"},
                       %{"name" => "ORG_SECRET"},
                       %{"name" => "PRJ_SECRET"}
                     ]
                   }
                 ]
               }
    end

    test "and custom_os_image is missing in the settings and PFCs are UNDEFINED configured" do
      pre_flight_checks = :undefined

      settings = %{
        "custom_machine_type" => "s1-myagent"
      }

      assert {:ok, definition} =
               Definition.form_definition(%{}, pre_flight_checks, settings, :test)

      assert definition ==
               %{
                 "agent" => %{
                   "machine" => %{
                     "type" => "s1-myagent",
                     "os_image" => ""
                   }
                 },
                 "jobs" => [
                   %{
                     "name" => "Only used in tests",
                     "commands" => [
                       "echo Test"
                     ],
                     "secrets" => []
                   }
                 ]
               }
    end

    test "and custom_os_image is missing in the settings and org PFCs is configured" do
      pre_flight_checks = %{
        "organization_pfc" => organization_pfc(),
        "project_pfc" => nil
      }

      settings = %{
        "custom_machine_type" => "s1-myagent"
      }

      assert {:ok, definition} =
               Definition.form_definition(%{}, pre_flight_checks, settings, :test)

      assert definition ==
               %{
                 "agent" => %{
                   "machine" => %{
                     "type" => "s1-myagent",
                     "os_image" => ""
                   }
                 },
                 "jobs" => [
                   %{
                     "name" => "Only used in tests",
                     "commands" => [
                       "echo Test",
                       "./org_security_script.sh"
                     ],
                     "secrets" => [%{"name" => "ORG_SECRET"}]
                   }
                 ]
               }
    end

    test "and custom_os_image is missing in the settings and project PFC are configured" do
      pre_flight_checks = %{
        "organization_pfc" => nil,
        "project_pfc" => project_pfc() |> Map.put("agent", nil)
      }

      settings = %{
        "custom_machine_type" => "s1-myagent"
      }

      assert {:ok, definition} =
               Definition.form_definition(%{}, pre_flight_checks, settings, :test)

      assert definition ==
               %{
                 "agent" => %{
                   "machine" => %{
                     "type" => "s1-myagent",
                     "os_image" => ""
                   }
                 },
                 "jobs" => [
                   %{
                     "name" => "Only used in tests",
                     "commands" => [
                       "echo Test",
                       "./prj_security_script.sh"
                     ],
                     "secrets" => [%{"name" => "PRJ_SECRET"}]
                   }
                 ]
               }
    end
  end

  describe "default_commands/2" do
    test "without pre-flight checks it uses a blobless + sparse checkout of the pipeline dir" do
      req_args = %{"working_dir" => ".semaphore", "file_name" => "semaphore.yml"}

      commands = Definition.default_commands(req_args, _optimize_checkout? = true)

      assert "export GIT_LFS_SKIP_SMUDGE=1" in commands
      assert ~s[export SEMAPHORE_GIT_PARTIAL_CLONE_FILTER="blob:none"] in commands
      assert ~s[export SEMAPHORE_GIT_SPARSE_CHECKOUT_PATHS=".semaphore"] in commands
      assert "checkout" in commands

      # the optimization exports must come before checkout
      filter_idx = Enum.find_index(commands, &(&1 =~ "SEMAPHORE_GIT_PARTIAL_CLONE_FILTER"))
      sparse_idx = Enum.find_index(commands, &(&1 =~ "SEMAPHORE_GIT_SPARSE_CHECKOUT_PATHS"))
      checkout_idx = Enum.find_index(commands, &(&1 == "checkout"))
      assert filter_idx < checkout_idx
      assert sparse_idx < checkout_idx

      assert List.last(commands) ==
               "spc compile --input $INPUT_FILE --output $OUTPUT_FILE --logs $LOGS_FILE"
    end

    test "with pre-flight checks it keeps the standard full checkout" do
      req_args = %{"working_dir" => ".semaphore", "file_name" => "semaphore.yml"}

      commands = Definition.default_commands(req_args, _optimize_checkout? = false)

      assert "export GIT_LFS_SKIP_SMUDGE=1" in commands
      assert "checkout" in commands
      refute Enum.any?(commands, &(&1 =~ "SEMAPHORE_GIT_PARTIAL_CLONE_FILTER"))
      refute Enum.any?(commands, &(&1 =~ "SEMAPHORE_GIT_SPARSE_CHECKOUT_PATHS"))
    end

    test "falls back to the repository root when the working dir is empty" do
      req_args = %{"working_dir" => "  ", "file_name" => "semaphore.yml"}

      commands = Definition.default_commands(req_args, _optimize_checkout? = true)

      assert ~s[export SEMAPHORE_GIT_SPARSE_CHECKOUT_PATHS="."] in commands
    end

    test "uses a nested working dir as the sparse path" do
      req_args = %{"working_dir" => ".semaphore/prod", "file_name" => "deploy.yml"}

      commands = Definition.default_commands(req_args, _optimize_checkout? = true)

      assert ~s[export SEMAPHORE_GIT_SPARSE_CHECKOUT_PATHS=".semaphore/prod"] in commands
    end
  end

  describe "optimize_checkout?/2" do
    test "true when no pre-flight checks and the feature is enabled" do
      with_mock Ppl.Features, sparse_checkout_init_job_enabled?: fn _ -> true end do
        assert Definition.optimize_checkout?("org-1", []) == true
      end
    end

    test "false when the feature is disabled, even without pre-flight checks" do
      with_mock Ppl.Features, sparse_checkout_init_job_enabled?: fn _ -> false end do
        assert Definition.optimize_checkout?("org-1", []) == false
      end
    end

    test "false when pre-flight checks are present, even if the feature is enabled" do
      with_mock Ppl.Features, sparse_checkout_init_job_enabled?: fn _ -> true end do
        assert Definition.optimize_checkout?("org-1", ["./security_check.sh"]) == false
      end
    end
  end

  @tag :integration
  test "when in prod environment => return compilation definition with proper env vars set" do
    System.put_env("INTERNAL_API_URL_PFC", "localhost:50053")
    System.put_env("INTERNAL_API_URL_USER", "localhost:50053")
    System.put_env("INTERNAL_API_URL_FEATURE", "localhost:50053")
    System.put_env("INTERNAL_API_URL_ORGANIZATION", "localhost:50053")

    not_trimmed_file_name = "semaphore.yml  "

    {:ok, %{ppl_id: ppl_id}} =
      %{
        "repo_name" => "2_basic",
        "working_dir" => ".semaphore",
        "file_name" => not_trimmed_file_name
      }
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()

    assert {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)

    Test.Helpers.stop_all_loopers(loopers)

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id)

    settings = %{
      "plan_machine_type" => "e2-standard-4",
      "plan_os_image" => "ubuntu2204",
      "custom_machine_type" => "f1-standard-2",
      "custom_os_image" => "ubuntu2004"
    }

    assert {:ok, definition} = Definition.form_definition(ppl_req, :undefined, settings, :prod)
    assert list = Map.get(definition, "jobs") |> Enum.at(0) |> Map.get("env_vars")
    assert is_list(list)
    assert Enum.count(list) == 21

    yml_path_ev = Enum.find(list, fn map -> map["name"] == "SEMAPHORE_YAML_FILE_PATH" end)
    assert yml_path_ev["value"] == ".semaphore/semaphore.yml"

    # With no pre-flight checks, the init job uses the optimized blobless +
    # sparse checkout of the pipeline directory.
    commands = Map.get(definition, "jobs") |> Enum.at(0) |> Map.get("commands")
    assert ~s[export SEMAPHORE_GIT_PARTIAL_CLONE_FILTER="blob:none"] in commands
    assert ~s[export SEMAPHORE_GIT_SPARSE_CHECKOUT_PATHS=".semaphore"] in commands
    assert "checkout" in commands

    on_exit(fn ->
      GRPC.Server.stop(PFCServiceMock)
    end)
  end

  defp organization_pfc() do
    %{
      "commands" => ["./org_security_script.sh"],
      "secrets" => ["ORG_SECRET"]
    }
  end

  defp project_pfc() do
    %{
      "commands" => ["./prj_security_script.sh"],
      "secrets" => ["PRJ_SECRET"],
      "agent" => %{
        "machine_type" => "e1-standard-4",
        "os_image" => "ubuntu1804"
      }
    }
  end
end
