defmodule Ppl.PplRequests.Model.PplRequests.Test do
  use ExUnit.Case
  doctest Ppl.PplRequests.Model.PplRequests

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplRequests.Model.PplRequests

  setup do
    Test.Helpers.truncate_db()

    request = Test.Helpers.schedule_request_factory(:local)

    job_1 = %{"name" => "job1", "cmds" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "cmds" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    block1 = %{"name" => "block1", "jobs" => jobs_list}
    job_3 = %{"name" => "job3", "cmd_file" => "some_file.sh"}
    block2 = %{"name" => "block1", "jobs" => [job_3]}
    blocks = [block1, block2]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    definition = %{"version" => "v1.0", "agent" => agent, "blocks" => blocks}
    {:ok, %{request: request, definition: definition}}
  end

  describe "changeset_compilation/2" do
    test "without pre-flight checks is valid" do
      params = %{
        request_args: %{
          "artifact_store_id" => UUID.uuid4()
        }
      }

      changeset = PplRequests.changeset_compilation(%PplRequests{}, params)
      assert changeset.valid?
    end

    test "without organization commands is invalid" do
      org_params = %{
        "commands" => [],
        "secrets" => ["POSTGRES_PASSWORD", "SESSION_SECRET"]
      }

      prj_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => ["POSTGRES_PASSWORD", "SESSION_SECRET"],
        "agent" => %{
          "machine_type" => "e1-standard-2",
          "os_image" => "ubuntu1804"
        }
      }

      params = %{
        request_args: %{
          "artifact_store_id" => UUID.uuid4()
        },
        pre_flight_checks: %{
          "organization_pfc" => org_params,
          "project_pfc" => prj_params
        }
      }

      changeset = PplRequests.changeset_compilation(%PplRequests{}, params)
      refute changeset.valid?
    end

    test "without project's agent machine type is invalid" do
      org_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => ["POSTGRES_PASSWORD", "SESSION_SECRET"]
      }

      prj_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => ["POSTGRES_PASSWORD", "SESSION_SECRET"],
        "agent" => %{
          "os_image" => "ubuntu1804"
        }
      }

      params = %{
        request_args: %{
          "artifact_store_id" => UUID.uuid4()
        },
        pre_flight_checks: %{
          "organization_pfc" => org_params,
          "project_pfc" => prj_params
        }
      }

      changeset = PplRequests.changeset_compilation(%PplRequests{}, params)
      refute changeset.valid?
    end

    test "without project's agent OS image config is valid" do
      org_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => ["POSTGRES_PASSWORD", "SESSION_SECRET"]
      }

      prj_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => ["POSTGRES_PASSWORD", "SESSION_SECRET"],
        "agent" => %{
          "machine_type" => "e1-standard-2"
        }
      }

      params = %{
        request_args: %{
          "artifact_store_id" => UUID.uuid4()
        },
        pre_flight_checks: %{
          "organization_pfc" => org_params,
          "project_pfc" => prj_params
        }
      }

      changeset = PplRequests.changeset_compilation(%PplRequests{}, params)
      assert changeset.valid?
    end

    test "without project's agent config is valid" do
      org_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => ["POSTGRES_PASSWORD", "SESSION_SECRET"]
      }

      prj_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => ["POSTGRES_PASSWORD", "SESSION_SECRET"]
      }

      params = %{
        request_args: %{
          "artifact_store_id" => UUID.uuid4()
        },
        pre_flight_checks: %{
          "organization_pfc" => org_params,
          "project_pfc" => prj_params
        }
      }

      changeset = PplRequests.changeset_compilation(%PplRequests{}, params)
      assert changeset.valid?
    end

    test "with nil project's agent config is valid" do
      org_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => ["POSTGRES_PASSWORD", "SESSION_SECRET"]
      }

      prj_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => ["POSTGRES_PASSWORD", "SESSION_SECRET"],
        "agent" => nil
      }

      params = %{
        request_args: %{
          "artifact_store_id" => UUID.uuid4()
        },
        pre_flight_checks: %{
          "organization_pfc" => org_params,
          "project_pfc" => prj_params
        }
      }

      changeset = PplRequests.changeset_compilation(%PplRequests{}, params)
      assert changeset.valid?
    end

    test "without project commands is invalid" do
      org_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => [],
        "agent" => %{
          "machine_type" => "e1-standard-2",
          "os_image" => "ubuntu1804"
        }
      }

      prj_params = %{
        "commands" => [],
        "secrets" => ["POSTGRES_PASSWORD", "SESSION_SECRET"]
      }

      params = %{
        request_args: %{
          "artifact_store_id" => UUID.uuid4()
        },
        pre_flight_checks: %{
          "organization_pfc" => org_params,
          "project_pfc" => prj_params
        }
      }

      changeset = PplRequests.changeset_compilation(%PplRequests{}, params)
      refute changeset.valid?
    end

    test "without organization pre-flight checks is valid" do
      org_params = nil

      prj_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => []
      }

      params = %{
        request_args: %{
          "artifact_store_id" => UUID.uuid4()
        },
        pre_flight_checks: %{
          "organization_pfc" => org_params,
          "project_pfc" => prj_params
        }
      }

      changeset = PplRequests.changeset_compilation(%PplRequests{}, params)
      assert changeset.valid?
    end

    test "without project pre-flight checks is valid" do
      org_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => []
      }

      prj_params = nil

      params = %{
        request_args: %{
          "artifact_store_id" => UUID.uuid4()
        },
        pre_flight_checks: %{
          "organization_pfc" => org_params,
          "project_pfc" => prj_params
        }
      }

      changeset = PplRequests.changeset_compilation(%PplRequests{}, params)
      assert changeset.valid?
    end

    test "without both pre-flight checks (nils) is valid" do
      org_params = nil
      prj_params = nil

      params = %{
        request_args: %{
          "artifact_store_id" => UUID.uuid4()
        },
        pre_flight_checks: %{
          "organization_pfc" => org_params,
          "project_pfc" => prj_params
        }
      }

      changeset = PplRequests.changeset_compilation(%PplRequests{}, params)
      refute changeset.valid?
    end

    test "with empty maps as pre-flight checks is valid" do
      org_params = %{}
      prj_params = %{}

      params = %{
        request_args: %{
          "artifact_store_id" => UUID.uuid4()
        },
        pre_flight_checks: %{
          "organization_pfc" => org_params,
          "project_pfc" => prj_params
        }
      }

      changeset = PplRequests.changeset_compilation(%PplRequests{}, params)
      refute changeset.valid?
    end

    test "with organization pre-flight checks as empty map is invalid" do
      org_params = %{}

      prj_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => []
      }

      params = %{
        request_args: %{
          "artifact_store_id" => UUID.uuid4()
        },
        pre_flight_checks: %{
          "organization_pfc" => org_params,
          "project_pfc" => prj_params
        }
      }

      changeset = PplRequests.changeset_compilation(%PplRequests{}, params)
      refute changeset.valid?
    end

    test "with pre-flight checks is valid" do
      org_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => []
      }

      prj_params = %{
        "commands" => ["git checkout master", "mix compile"],
        "secrets" => [],
        "agent" => %{
          "machine_type" => "e1-standard-2",
          "os_image" => "ubuntu1804"
        }
      }

      params = %{
        request_args: %{
          "artifact_store_id" => UUID.uuid4()
        },
        pre_flight_checks: %{
          "organization_pfc" => org_params,
          "project_pfc" => prj_params
        }
      }

      changeset = PplRequests.changeset_compilation(%PplRequests{}, params)
      assert changeset.valid?
    end
  end

  describe "changeset_request/3" do
    test "request_token can be any non empty string" do
      assert changeset_request_valid?(%{
               request_args: %{"service" => "local"},
               prev_ppl_artefact_ids: [],
               request_token: "asdfgh2345678xcvb",
               ppl_artefact_id: UUID.uuid4(),
               hook_id: UUID.uuid4(),
               branch_id: UUID.uuid4(),
               id: UUID.uuid4(),
               top_level: false,
               initial_request: false,
               wf_id: UUID.uuid4()
             })
    end

    test "request_token cannot be empty string" do
      refute changeset_request_valid?(%{
               request_args: %{"service" => "local"},
               request_token: "",
               prev_ppl_artefact_ids: [],
               ppl_artefact_id: UUID.uuid4(),
               hook_id: UUID.uuid4(),
               branch_id: UUID.uuid4(),
               top_level: false,
               initial_request: false,
               id: UUID.uuid4(),
               wf_id: UUID.uuid4()
             })
    end

    test "request_token is required" do
      refute changeset_request_valid?(%{
               request_args: %{"service" => "local"},
               prev_ppl_artefact_ids: [],
               hook_id: UUID.uuid4(),
               branch_id: UUID.uuid4(),
               top_level: false,
               initial_request: false,
               id: UUID.uuid4(),
               ppl_artefact_id: UUID.uuid4(),
               wf_id: UUID.uuid4()
             })
    end

    test "wf_id is required when workflow does not originate from task" do
      assert %Ecto.Changeset{valid?: false, errors: [wf_id: {"can't be blank", _}]} =
               PplRequests.changeset_request(
                 %PplRequests{},
                 %{
                   request_args: %{"service" => "local"},
                   request_token: "asdfgh2345678xcvb",
                   hook_id: UUID.uuid4(),
                   branch_id: UUID.uuid4(),
                   prev_ppl_artefact_ids: [],
                   top_level: false,
                   initial_request: false,
                   id: UUID.uuid4(),
                   ppl_artefact_id: UUID.uuid4()
                 },
                 false
               )
    end

    test "wf_id, hook_id and branch_id is not required when workflow originates from task" do
      assert %Ecto.Changeset{valid?: true} =
               PplRequests.changeset_request(
                 %PplRequests{},
                 %{
                   request_args: %{
                     "service" => "local",
                     "scheduler_task_id" => "scheduler_task_id"
                   },
                   request_token: "asdfgh2345678xcvb",
                   prev_ppl_artefact_ids: [],
                   top_level: false,
                   initial_request: false,
                   id: UUID.uuid4(),
                   ppl_artefact_id: UUID.uuid4(),
                   wf_id: UUID.uuid4()
                 },
                 true
               )
    end
  end

  test "changeset_conception updates request_args with missing information" do
    assert %Ecto.Changeset{valid?: true} =
             PplRequests.changeset_conception(%PplRequests{}, %{
               request_args: %{
                 "hook_id" => "123",
                 "branch_id" => "456",
                 "owner" => "owner",
                 "repo_name" => "repo_name",
                 "branch_name" => "branch_name",
                 "commit_sha" => "commit_sha",
                 "repository_id" => "repository_id"
               }
             })

    assert %Ecto.Changeset{valid?: false, errors: [request_args: {"Missing field 'hook_id'", _}]} =
             PplRequests.changeset_conception(%PplRequests{}, %{
               request_args: %{
                 "branch_id" => "456",
                 "owner" => "owner",
                 "repo_name" => "repo_name",
                 "branch_name" => "branch_name",
                 "commit_sha" => "commit_sha",
                 "repository_id" => "repository_id"
               }
             })

    assert %Ecto.Changeset{
             valid?: false,
             errors: [request_args: {"Missing field 'branch_id'", _}]
           } =
             PplRequests.changeset_conception(%PplRequests{}, %{
               request_args: %{
                 "hook_id" => "123",
                 "owner" => "owner",
                 "repo_name" => "repo_name",
                 "branch_name" => "branch_name",
                 "commit_sha" => "commit_sha",
                 "repository_id" => "repository_id"
               }
             })

    assert %Ecto.Changeset{valid?: false, errors: [request_args: {"Missing field 'owner'", _}]} =
             PplRequests.changeset_conception(%PplRequests{}, %{
               request_args: %{
                 "hook_id" => "123",
                 "branch_id" => "456",
                 "repo_name" => "repo_name",
                 "branch_name" => "branch_name",
                 "commit_sha" => "commit_sha",
                 "repository_id" => "repository_id"
               }
             })

    assert %Ecto.Changeset{
             valid?: false,
             errors: [request_args: {"Missing field 'repo_name'", _}]
           } =
             PplRequests.changeset_conception(%PplRequests{}, %{
               request_args: %{
                 "hook_id" => "123",
                 "branch_id" => "456",
                 "owner" => "owner",
                 "branch_name" => "branch_name",
                 "commit_sha" => "commit_sha",
                 "repository_id" => "repository_id"
               }
             })

    assert %Ecto.Changeset{
             valid?: false,
             errors: [request_args: {"Missing field 'branch_name'", _}]
           } =
             PplRequests.changeset_conception(%PplRequests{}, %{
               request_args: %{
                 "hook_id" => "123",
                 "branch_id" => "456",
                 "owner" => "owner",
                 "repo_name" => "repo_name",
                 "commit_sha" => "commit_sha",
                 "repository_id" => "repository_id"
               }
             })

    assert %Ecto.Changeset{
             valid?: false,
             errors: [request_args: {"Missing field 'commit_sha'", _}]
           } =
             PplRequests.changeset_conception(%PplRequests{}, %{
               request_args: %{
                 "hook_id" => "123",
                 "branch_id" => "456",
                 "owner" => "owner",
                 "repo_name" => "repo_name",
                 "branch_name" => "branch_name",
                 "repository_id" => "repository_id"
               }
             })
  end

  test "changeset_conception requires repository_id in request_args in repository based services" do
    assert %Ecto.Changeset{
             valid?: false,
             errors: [request_args: {"Missing field 'repository_id'", _}]
           } =
             PplRequests.changeset_conception(%PplRequests{}, %{
               request_args: %{
                 "hook_id" => "123",
                 "branch_id" => "456",
                 "owner" => "owner",
                 "repo_name" => "repo_name",
                 "branch_name" => "branch_name",
                 "commit_sha" => "commit_sha",
                 "service" => "bitbucket"
               }
             })

    assert %Ecto.Changeset{
             valid?: false,
             errors: [request_args: {"Missing field 'repository_id'", _}]
           } =
             PplRequests.changeset_conception(%PplRequests{}, %{
               request_args: %{
                 "hook_id" => "123",
                 "branch_id" => "456",
                 "owner" => "owner",
                 "repo_name" => "repo_name",
                 "branch_name" => "branch_name",
                 "commit_sha" => "commit_sha",
                 "service" => "git_hub"
               }
             })

    assert %Ecto.Changeset{valid?: true} =
             PplRequests.changeset_conception(%PplRequests{}, %{
               request_args: %{
                 "hook_id" => "123",
                 "branch_id" => "456",
                 "owner" => "owner",
                 "repo_name" => "repo_name",
                 "branch_name" => "branch_name",
                 "commit_sha" => "commit_sha",
                 "service" => "local"
               }
             })
  end

  defp changeset_request_valid?(params, task_workflow? \\ false),
    do: PplRequests.changeset_request(%PplRequests{}, params, task_workflow?) |> Map.get(:valid?)

  test "valid pipline request is stored in DB and can be fetched by id", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    {:ok, definition} = Map.fetch(ctx, :definition)
    assert {:ok, ppl_req} = PplRequestsQueries.insert_request(request)
    assert {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)

    id = ppl_req.id
    assert {:ok, response} = PplRequestsQueries.get_by_id(id)
    assert ppl_req.request_args == response.request_args
    assert ppl_req.request_token == response.request_token
    assert ppl_req.definition == response.definition
    assert response.block_count == 2
  end

  test "pipline request without 'blocks' is invalid", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    {:ok, definition} = Map.fetch(ctx, :definition)
    definition = Map.delete(definition, "blocks")
    assert {:ok, ppl_req} = PplRequestsQueries.insert_request(request)

    assert {:error, _message} = PplRequestsQueries.insert_definition(ppl_req, definition)
  end

  test "pipline request with empty 'blocks' list is invalid", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    {:ok, definition} = Map.fetch(ctx, :definition)
    definition = %{definition | "blocks" => []}
    assert {:ok, ppl_req} = PplRequestsQueries.insert_request(request)

    assert {:error, _message} = PplRequestsQueries.insert_definition(ppl_req, definition)
  end
end
