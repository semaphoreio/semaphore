defmodule Front.Models.SchedulerTest do
  use ExUnit.Case

  import Mock

  alias Front.Models.Scheduler, as: Subject
  alias Front.Clients
  alias Google.Protobuf.Timestamp

  alias InternalApi.PeriodicScheduler.{
    DescribeResponse,
    HistoryResponse,
    LatestTriggersResponse,
    ListResponse,
    PauseResponse,
    Periodic,
    PeriodicService.Stub,
    PersistResponse,
    RunNowResponse,
    Trigger,
    UnpauseResponse
  }

  @user_id "ee2e6241-uuuu-4b67-a417-f31f2fa0f105"
  @org_id "ee2e6241-oooo-4b67-a417-f31f2fa0f105"
  @scheduler_id "ee2e6241-ssss-4b67-a417-f31f2fa0f105"
  @project_id "ee2e6241-pppp-4b67-a417-f31f2fa0f105"

  @context_data %{
    organization_id: @org_id,
    requester_id: @user_id,
    project_name: "project-name",
    project_id: @project_id,
    id: @scheduler_id
  }

  @form_data %{
    name: "sch-name",
    recurring: true,
    at: "addme",
    reference_type: "branch",
    reference_name: "master",
    pipeline_file: "addme",
    project_name: "test-project",
    parameters: [
      %{
        name: "param1",
        description: "",
        options: ["value1", "value2"],
        required: true,
        default_value: "value1"
      }
    ]
  }

  describe ".map_expression" do
    test "complete missing starts" do
      assert Front.Models.Scheduler.map_expression("*") == {:ok, "* * * * *"}
    end
  end

  describe ".list" do
    test "when list request fails, it returns an error" do
      response =
        ListResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:INTERNAL),
              message: "Internal error message"
            )
        )

      with_mock Stub, list: fn _c, _r, _o -> {:ok, response} end do
        assert Subject.list(@project_id) == {:error, :grpc_req_failed}
      end
    end

    test "list action returns schedulers and triggers data when gRPC response is valid" do
      response_scheduler =
        ListResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:OK),
              message: ""
            ),
          periodics: [
            scheduler_desc(1),
            scheduler_desc(2),
            scheduler_desc(3),
            scheduler_desc(4)
          ]
        )

      response_triggers =
        LatestTriggersResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:OK),
              message: ""
            ),
          triggers: [
            trigger_desc(1),
            trigger_desc(2),
            trigger_desc(4)
          ]
        )

      with_mock Stub,
        list: fn _c, _r, _o -> {:ok, response_scheduler} end,
        latest_triggers: fn _c, _r, _o -> {:ok, response_triggers} end do
        assert {:ok, list} = Subject.list(@project_id)
        assert list.entries == expected_desc_list()
      end
    end

    test "list action returns schedulers with JustRun related fields" do
      response_scheduler =
        ListResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:OK),
              message: ""
            ),
          periodics: [
            scheduler_desc(1,
              recurring: false,
              at: "",
              reference: "",
              pipeline_file: "",
              parameters: [
                %{
                  name: "param1",
                  options: ["value1", "value2"],
                  required: true,
                  default_value: "value1"
                }
              ]
            )
          ]
        )

      response_triggers =
        LatestTriggersResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:OK),
              message: ""
            ),
          triggers: [
            trigger_desc(1)
          ]
        )

      workflow_response =
        InternalApi.PlumberWF.DescribeManyResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:OK),
              message: ""
            ),
          workflows: []
        )

      with_mocks([
        {Stub, [],
         [
           list: fn _c, _r, _o -> {:ok, response_scheduler} end,
           latest_triggers: fn _c, _r, _o -> {:ok, response_triggers} end
         ]},
        {Clients.Workflow, [],
         [
           describe_many: fn _r -> {:ok, workflow_response} end
         ]}
      ]) do
        assert {:ok, list} = Subject.list(@project_id)

        assert list.entries == [
                 scheduler_model(1,
                   recurring: false,
                   at: "",
                   reference: "",
                   reference_type: "branch",
                   reference_name: "",
                   pipeline_file: "",
                   parameters: [
                     %{
                       name: "param1",
                       required: true,
                       description: "",
                       options: ["value1", "value2"],
                       default_value: "value1"
                     }
                   ],
                   triggerer_avatar_url: "/projects/assets/images/profile-bot.svg",
                   triggerer_name: "scheduler"
                 )
               ]
      end
    end
  end

  defp expected_desc_list do
    params = [
      triggerer_avatar_url: "/projects/assets/images/profile-bot.svg",
      triggerer_name: "scheduler"
    ]

    [
      scheduler_model(1, params),
      scheduler_model(2, params),
      scheduler_model(3, Keyword.put(params, :include_trigger, false)),
      scheduler_model(4, params)
    ]
  end

  defp scheduler_model(ind, params \\ []) do
    params = Keyword.put_new(params, :include_trigger, true)

    default_params = [
      activity_toggled_at: "",
      activity_toggled_by: ptb(ind),
      at: "* * * * *",
      recurring: true,
      blocked: suspended(ind),
      reference: "refs/heads/master",
      reference_type: "branch",
      reference_name: "master",
      created_at: "",
      id: "id-#{ind}",
      inactive: paused(ind),
      latest_scheduled_at: "",
      latest_status: status(ind),
      latest_workflow_id: wf_id(ind),
      manually_triggered_by: requester(ind),
      name: "Scheduler #{ind}",
      project_id: @project_id,
      description: "Scheduler #{ind} description",
      next: "not-added-yet",
      pipeline_file: "tests.yaml",
      updated_at: "",
      updated_by: "user_1",
      latest_triggered_at: "",
      parameters: [],
      latest_trigger:
        if(params[:include_trigger],
          do: %Front.Models.Scheduler.Trigger{
            triggerer_avatar_url: params[:triggerer_avatar_url],
            triggerer_name: params[:triggerer_name],
            triggerer: nil,
            workflow: nil,
            parameter_values: %{},
            triggered_by: requester(ind),
            triggered_at: 0,
            scheduled_at: 0,
            status: status(ind),
            workflow_id: wf_id(ind),
            pipeline_file: "tests.yaml",
            reference: "refs/heads/master",
            reference_type: "branch",
            reference_name: "master"
          }
        )
    ]

    struct(Front.Models.Scheduler, default_params |> Keyword.merge(params) |> Map.new())
  end

  defp trigger_desc(ind) do
    Trigger.new(
      triggered_at: Timestamp.new(seconds: 0),
      project_id: "Test",
      reference: "refs/heads/master",
      pipeline_file: "tests.yaml",
      scheduling_status: status(ind),
      periodic_id: "id-#{ind}",
      scheduled_workflow_id: wf_id(ind),
      scheduled_at: Timestamp.new(seconds: 0),
      error_description: "",
      run_now_requester_id: requester(ind)
    )
  end

  defp status(4), do: "failed"
  defp status(3), do: ""
  defp status(_ind), do: "passed"

  defp wf_id(ind) when ind in [3, 4], do: ""
  defp wf_id(ind), do: "wf_#{ind}"

  defp requester(1), do: "user_3"
  defp requester(_ind), do: ""

  defp scheduler_desc(ind, params \\ []) do
    default_params = [
      id: "id-#{ind}",
      name: "Scheduler #{ind}",
      description: "Scheduler #{ind} description",
      project_id: @project_id,
      at: "* * * * *",
      recurring: true,
      pipeline_file: "tests.yaml",
      requester_id: "user_1",
      suspended: suspended(ind),
      paused: paused(ind),
      pause_toggled_by: ptb(ind),
      pause_toggled_at: Timestamp.new(seconds: 0) |> Map.take([:seconds, :nanos]),
      reference: "refs/heads/master",
      updated_at: Timestamp.new(seconds: 0) |> Map.take([:seconds, :nanos]),
      inserted_at: Timestamp.new(seconds: 0) |> Map.take([:seconds, :nanos]),
      parameters: []
    ]

    default_params |> Keyword.merge(params) |> Map.new() |> Util.Proto.deep_new!(Periodic)
  end

  defp suspended(3), do: true
  defp suspended(_ind), do: false

  defp paused(2), do: true
  defp paused(_ind), do: false

  defp ptb(2), do: "user_2"
  defp ptb(_ind), do: ""

  describe ".find" do
    test "find action returns scheduler and latest trigger data when gRPC response is valid" do
      response =
        DescribeResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:OK),
              message: ""
            ),
          periodic: scheduler_desc(1),
          triggers: [trigger_desc(1)]
        )

      with_mock Stub, describe: fn _c, _r, _o -> {:ok, response} end do
        assert {:ok, scheduler} = Subject.find(@scheduler_id)
        assert scheduler_model(1) == scheduler
      end
    end

    test "find action returns JustRun scheduler and latest trigger data when gRPC response is valid" do
      response =
        DescribeResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:OK),
              message: ""
            ),
          periodic:
            scheduler_desc(1,
              recurring: false,
              at: "",
              reference: "refs/heads/master",
              pipeline_file: "",
              parameters: [
                %{
                  name: "param1",
                  options: ["value1", "value2"],
                  required: true,
                  default_value: "value1"
                }
              ]
            ),
          triggers: [trigger_desc(1)]
        )

      with_mock Stub, describe: fn _c, _r, _o -> {:ok, response} end do
        assert {:ok, scheduler} = Subject.find(@scheduler_id)

        assert scheduler ==
                 scheduler_model(1,
                   recurring: false,
                   at: "",
                   reference: "refs/heads/master",
                   reference_type: "branch",
                   reference_name: "master",
                   pipeline_file: "",
                   parameters: [
                     %{
                       name: "param1",
                       required: true,
                       description: "",
                       options: ["value1", "value2"],
                       default_value: "value1"
                     }
                   ]
                 )
      end
    end

    test "when find request fails, it returns an error" do
      response =
        DescribeResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:INTERNAL),
              message: "Internal error message"
            )
        )

      with_mock Stub, describe: fn _c, _r, _o -> {:ok, response} end do
        assert Subject.find(@scheduler_id) == {:error, :grpc_req_failed}
      end
    end
  end

  describe ".latest_trigger" do
    test "returns latest trigger data when gRPC response is valid" do
      response =
        LatestTriggersResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:OK),
              message: ""
            ),
          triggers: [trigger_desc(1)]
        )

      with_mock Stub, latest_triggers: fn _c, _r, _o -> {:ok, response} end do
        assert %Subject.Trigger{workflow_id: "wf_1"} = Subject.latest_trigger(@scheduler_id)
      end
    end

    test "when find request fails, it returns nil" do
      response =
        LatestTriggersResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:INTERNAL),
              message: "Internal error message"
            )
        )

      with_mock Stub, latest_triggers: fn _c, _r, _o -> {:ok, response} end do
        assert Subject.latest_trigger(@scheduler_id) == nil
      end
    end
  end

  describe ".history" do
    test "history action returns list of triggers data when gRPC response is valid" do
      response =
        HistoryResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:OK),
              message: ""
            ),
          triggers: [trigger_desc(1)]
        )

      with_mock Stub, history: fn _c, _r, _o -> {:ok, response} end do
        assert {:ok, %Subject.HistoryPage{triggers: triggers}} = Subject.history(@scheduler_id)
        assert trigger = List.first(triggers)
        assert %Front.Models.Scheduler.Trigger{} = trigger
      end
    end

    test "when history request fails, it returns an error" do
      response =
        HistoryResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:INTERNAL),
              message: "Internal error message"
            )
        )

      with_mock Stub, history: fn _c, _r, _o -> {:ok, response} end do
        assert Subject.history(@scheduler_id) == {:error, :grpc_req_failed}
      end
    end
  end

  describe ".pause" do
    test "pause returns :ok when when gRPC response is valid" do
      response =
        PauseResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:OK),
              message: "Success"
            )
        )

      with_mock Stub, pause: fn _c, _r, _o -> {:ok, response} end do
        assert Subject.pause(@scheduler_id, @user_id) == {:ok, "Success"}
      end
    end

    test "when pause request fails, it returns an error" do
      response =
        PauseResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:INTERNAL),
              message: "Internal error message"
            )
        )

      with_mock Stub, pause: fn _c, _r, _o -> {:ok, response} end do
        assert Subject.pause(@scheduler_id, @user_id) == {:error, :grpc_req_failed}
      end
    end
  end

  describe ".unpause" do
    test "unpause returns :ok when when gRPC response is valid" do
      response =
        UnpauseResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:OK),
              message: "Success"
            )
        )

      with_mock Stub, unpause: fn _c, _r, _o -> {:ok, response} end do
        assert Subject.unpause(@scheduler_id, @user_id) == {:ok, "Success"}
      end
    end

    test "when unpause request fails, it returns an error" do
      response =
        UnpauseResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:INTERNAL),
              message: "Internal error message"
            )
        )

      with_mock Stub, unpause: fn _c, _r, _o -> {:ok, response} end do
        assert Subject.unpause(@scheduler_id, @user_id) == {:error, :grpc_req_failed}
      end
    end
  end

  describe ".run_now" do
    test "run_now returns scheduler and new trigger data when when gRPC response is valid" do
      response =
        RunNowResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:OK),
              message: ""
            ),
          periodic: scheduler_desc(1),
          triggers: [trigger_desc(1)]
        )

      with_mock Stub, run_now: fn _c, _r, _o -> {:ok, response} end do
        assert {:ok, scheduler} = Subject.run_now(@scheduler_id, @user_id)
        assert scheduler_model(1) == scheduler
      end
    end

    test "when run_now request fails, it returns an error" do
      response =
        RunNowResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:INTERNAL),
              message: "Internal error message"
            )
        )

      with_mock Stub, run_now: fn _c, _r, _o -> {:ok, response} end do
        assert Subject.run_now(@scheduler_id, @user_id) == {:error, :grpc_req_failed}
      end
    end

    test "retruns RESOURCE_EXHAUSTED error in special way so controller can process it correctly" do
      response =
        RunNowResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:RESOURCE_EXHAUSTED),
              message: "Too many pipelines in the queue."
            )
        )

      with_mock Stub, run_now: fn _c, _r, _o -> {:ok, response} end do
        assert {:error, {:resource_exhausted, message}} = Subject.run_now(@scheduler_id, @user_id)
        assert message == "Too many pipelines in the queue."
      end
    end
  end

  describe ".update" do
    @tag :skip
    # For some unkown reason this fails when the whole test suite is run
    test "when request succeeds, it returns an uuid" do
      {:ok, scheduler_id} = Subject.persist(@form_data, @context_data)

      assert byte_size(scheduler_id) == 36
    end

    test "when update request fails, it returns an error" do
      response =
        PersistResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:INTERNAL),
              message: "Internal error message"
            )
        )

      with_mock Stub, persist: fn _, _, _ -> {:ok, response} end do
        assert Subject.persist(@form_data, @context_data) ==
                 {:error, %{errors: %{other: "Internal error message"}}}
      end
    end

    test "when the periodic scheduler precondition fails on the server, it returns an error in expected form" do
      response =
        PersistResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:FAILED_PRECONDITION),
              message: "Unparsable message"
            )
        )

      with_mock Stub, persist: fn _, _, _ -> {:ok, response} end do
        assert Subject.persist(@form_data, @context_data) ==
                 {:error,
                  %{
                    errors: %{
                      other: "Unparsable message"
                    }
                  }}
      end

      response =
        PersistResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:FAILED_PRECONDITION),
              message:
                "At least one regular workflow run on targeted branch is needed before periodic can be created."
            )
        )

      with_mock Stub, persist: fn _, _, _ -> {:ok, response} end do
        assert Subject.persist(@form_data, @context_data) ==
                 {:error,
                  %{
                    errors: %{
                      other:
                        "At least one regular workflow run on targeted branch is needed before periodic can be created."
                    }
                  }}
      end

      response =
        PersistResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:INVALID_ARGUMENT),
              message:
                "Invalid cron expression in 'at' field: {:error, \"Can't parse x as interval minute.\"}"
            )
        )

      with_mock Stub, persist: fn _, _, _ -> {:ok, response} end do
        assert Subject.persist(@form_data, @context_data) ==
                 {:error,
                  %{
                    errors: %{
                      at:
                        "Invalid cron expression: {:error, \"Can't parse x as interval minute.\"}"
                    }
                  }}
      end

      response =
        PersistResponse.new(
          status:
            InternalApi.Status.new(
              code: Google.Rpc.Code.value(:INVALID_ARGUMENT),
              message:
                "Periodic with name 'new_cache_server_test' already exists for project 'new_cache_test'."
            )
        )

      with_mock Stub, persist: fn _, _, _ -> {:ok, response} end do
        assert Subject.persist(@form_data, @context_data) ==
                 {:error,
                  %{
                    errors: %{
                      name:
                        "Scheduler 'new_cache_server_test' already exists for project 'new_cache_test'."
                    }
                  }}
      end
    end

    test "when the connection can't be made, it returns an error" do
      with_mock GRPC.Stub, connect: fn _ -> {:error, "failed"} end do
        assert Subject.persist(@form_data, @context_data) ==
                 {:error, :grpc_req_failed}
      end
    end
  end

  describe "HistoryPage" do
    alias Front.Models.Scheduler
    alias Subject.HistoryPage
    alias Subject.Trigger

    alias Front.Decorators.Workflow

    setup do
      Support.Stubs.init()
      Support.Stubs.build_shared_factories()
      project = Support.Stubs.DB.first(:projects)
      workflow = Support.Stubs.DB.first(:workflows)
      user = Support.Stubs.User.default()

      periodic = Support.Stubs.Scheduler.create(project, user)
      Support.Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user)
      Support.Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user)
      Support.Stubs.Scheduler.create_trigger(periodic, workflow.api_model, user)

      {:ok,
       %{
         project: project,
         workflow: workflow,
         user: user,
         periodic: periodic
       }}
    end

    test "construct/1 constructs page struct", ctx do
      assert {:ok, page = %HistoryPage{}} = Scheduler.history(ctx.periodic.id)
      refute page.cursor_before
      refute page.cursor_after

      assert Enum.all?(page.triggers, &match?(%Trigger{}, &1))
      assert Enum.all?(page.triggers, &UUID.info!(&1.workflow_id))
      assert Enum.all?(page.triggers, &(&1.reference_name == "master"))
      assert Enum.all?(page.triggers, &(&1.reference_type == "branch"))
      assert Enum.all?(page.triggers, &(&1.pipeline_file == ".semaphore/semaphore.yml"))
      assert Enum.all?(page.triggers, &is_nil(&1.triggerer))
      assert Enum.all?(page.triggers, &is_nil(&1.workflow))
    end

    test "preload/1 preloads pipeline info", ctx do
      assert {:ok, page = %HistoryPage{}} = Scheduler.history(ctx.periodic.id)
      assert page = %HistoryPage{} = HistoryPage.preload(page)

      assert Enum.count(page.triggers) == 3
      assert Enum.all?(page.triggers, &match?(%Trigger{}, &1))
      assert Enum.all?(page.triggers, &match?(%Workflow{}, &1.workflow))
    end

    test "preload/1 preloads triggerer info", ctx do
      assert {:ok, page = %HistoryPage{}} = Scheduler.history(ctx.periodic.id)
      assert page = %HistoryPage{} = HistoryPage.preload(page)
      avatar_url = "https://avatars3.githubusercontent.com/u/0?v=4"

      assert Enum.count(page.triggers) == 3
      assert Enum.all?(page.triggers, &match?(%Trigger{}, &1))
      assert Enum.all?(page.triggers, &(&1.triggerer_name == "Jane"))
      assert Enum.all?(page.triggers, &(&1.triggerer_avatar_url == avatar_url))
    end
  end

  describe "reference building" do
    test "persist/3 builds Git reference from reference_type and reference_name for branches" do
      form_data = %{
        name: "test-scheduler",
        recurring: true,
        reference_type: "branch",
        reference_name: "develop",
        pipeline_file: ".semaphore/semaphore.yml"
      }

      context_data = %{
        organization_id: @org_id,
        requester_id: @user_id,
        project_name: "test-project",
        project_id: @project_id
      }

      with_mock Stub, [:passthrough],
        persist: fn _channel, request, _options ->
          # Verify that the request contains the properly built Git reference
          assert request.reference == "refs/heads/develop"
          assert request.name == "test-scheduler"
          assert request.pipeline_file == ".semaphore/semaphore.yml"

          {:ok,
           %PersistResponse{
             status: %InternalApi.Status{code: 0},
             periodic: %Periodic{id: "new-scheduler-id"}
           }}
        end do
        assert {:ok, "new-scheduler-id"} = Subject.persist(form_data, context_data)
      end
    end

    test "persist/3 builds Git reference from reference_type and reference_name for tags" do
      form_data = %{
        name: "test-scheduler",
        recurring: true,
        reference_type: "tag",
        reference_name: "v1.0.0",
        pipeline_file: ".semaphore/semaphore.yml"
      }

      context_data = %{
        organization_id: @org_id,
        requester_id: @user_id,
        project_name: "test-project",
        project_id: @project_id
      }

      with_mock Stub, [:passthrough],
        persist: fn _channel, request, _options ->
          # Verify that the request contains the properly built Git reference
          assert request.reference == "refs/tags/v1.0.0"
          assert request.name == "test-scheduler"

          {:ok,
           %PersistResponse{
             status: %InternalApi.Status{code: 0},
             periodic: %Periodic{id: "new-scheduler-id"}
           }}
        end do
        assert {:ok, "new-scheduler-id"} = Subject.persist(form_data, context_data)
      end
    end

    test "persist/3 defaults to branch when reference_type is missing" do
      form_data = %{
        name: "test-scheduler",
        recurring: true,
        reference_name: "main",
        pipeline_file: ".semaphore/semaphore.yml"
      }

      context_data = %{
        organization_id: @org_id,
        requester_id: @user_id,
        project_name: "test-project",
        project_id: @project_id
      }

      with_mock Stub, [:passthrough],
        persist: fn _channel, request, _options ->
          # Should default to branch reference format
          assert request.reference == "refs/heads/main"

          {:ok,
           %PersistResponse{
             status: %InternalApi.Status{code: 0},
             periodic: %Periodic{id: "new-scheduler-id"}
           }}
        end do
        assert {:ok, "new-scheduler-id"} = Subject.persist(form_data, context_data)
      end
    end

    test "run_now/4 builds Git reference from reference_type and reference_name" do
      just_run_params = %{
        reference_type: "tag",
        reference_name: "v2.1.0",
        pipeline_file: ".semaphore/custom.yml"
      }

      with_mock Stub, [:passthrough],
        run_now: fn _channel, request, _options ->
          # Verify that run_now builds the reference and removes the separate fields
          assert request.reference == "refs/tags/v2.1.0"
          assert request.pipeline_file == ".semaphore/custom.yml"
          assert request.id == @scheduler_id
          assert request.requester == @user_id

          # Should not include the separate reference fields
          refute Map.has_key?(request, :reference_type)
          refute Map.has_key?(request, :reference_name)

          {:ok,
           %RunNowResponse{
             status: %InternalApi.Status{code: 0},
             periodic: %Periodic{
               id: @scheduler_id,
               name: "test-scheduler",
               description: "",
               project_id: @project_id,
               recurring: true,
               reference: "refs/tags/v2.1.0",
               pipeline_file: ".semaphore/custom.yml",
               at: "",
               parameters: [],
               requester_id: @user_id,
               updated_at: %Timestamp{seconds: 1_640_995_200},
               inserted_at: %Timestamp{seconds: 1_640_995_200},
               pause_toggled_at: nil,
               pause_toggled_by: "",
               paused: false,
               suspended: false
             },
             triggers: []
           }}
        end do
        assert {:ok, _scheduler} = Subject.run_now(@scheduler_id, @user_id, just_run_params)
      end
    end
  end
end
