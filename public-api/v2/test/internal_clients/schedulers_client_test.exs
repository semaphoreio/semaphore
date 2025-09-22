defmodule InternalClients.SchedulersClientTest do
  use ExUnit.Case, async: false
  alias InternalClients.Schedulers, as: Client

  setup do
    Support.Stubs.reset()
  end

  describe "list/1" do
    test "fails without organization_id" do
      assert {:error, {:user, "missing :organization_id"}} = Client.list(%{})
    end

    test "lists existing tasks" do
      for i <- 1..6 do
        Support.Stubs.Scheduler.create(UUID.uuid4(), UUID.uuid4(), name: "Scheduler #{i}")
      end

      assert {:ok, response} = Client.list(%{organization_id: "org-1"})

      assert length(response.entries) == 6
      assert response.total_entries == 6
      assert response.total_pages == 1
      assert response.page_number == 1
      assert response.page_size == 100
    end

    test "paginates results" do
      for i <- 1..26 do
        Support.Stubs.Scheduler.create(UUID.uuid4(), UUID.uuid4(), name: "Scheduler #{i}")
      end

      assert {:ok, response} = Client.list(%{organization_id: "org-1", page: 2, size: 5})

      assert length(response.entries) == 5
      assert response.total_entries == 26
      assert response.total_pages == 6
      assert response.page_number == 2
      assert response.page_size == 5
    end

    test "returns error when gRPC client returns expected error status" do
      GrpcMock.stub(SchedulerMock, :list, fn _, _stream ->
        %InternalApi.PeriodicScheduler.ListResponse{
          status: %InternalApi.Status{
            code: Google.Rpc.Code.value(:INVALID_ARGUMENT),
            message: "Some issue"
          }
        }
      end)

      assert {:error, {:user, "Some issue"}} = Client.list(%{organization_id: "org-1"})
    end

    test "returns error when gRPC client returns unexpected error status" do
      GrpcMock.stub(SchedulerMock, :list, fn _, _stream ->
        %InternalApi.PeriodicScheduler.ListResponse{
          status: %InternalApi.Status{
            code: Google.Rpc.Code.value(:RESOURCE_EXHAUSTED),
            message: "Some issue"
          }
        }
      end)

      assert {:error, {:internal, "Unexpected error occurred"}} =
               Client.list(%{organization_id: "org-1"})
    end
  end

  describe "list_keyset/1" do
    test "fails without organization_id" do
      assert {:error, {:user, "missing :organization_id"}} = Client.list_keyset(%{})
    end

    test "lists existing tasks" do
      for i <- 1..6 do
        Support.Stubs.Scheduler.create(UUID.uuid4(), UUID.uuid4(), name: "Scheduler #{i}")
      end

      assert {:ok, response} = Client.list_keyset(%{organization_id: "org-1"})

      assert length(response.entries) == 6
      assert response.next_page_token == ""
      assert response.prev_page_token == ""
    end

    test "paginates results" do
      schedulers =
        for i <- 1..26 do
          Support.Stubs.Scheduler.create(UUID.uuid4(), UUID.uuid4(),
            name: "Scheduler #{i |> Integer.to_string() |> String.pad_leading(2, "0")}"
          )
        end

      page_token = schedulers |> Enum.at(7) |> Map.get(:id)

      assert {:ok, response} =
               Client.list_keyset(%{
                 organization_id: "org-1",
                 page_token: page_token,
                 page_size: 5
               })

      assert length(response.entries) == 5
      assert response.next_page_token == schedulers |> Enum.at(12) |> Map.get(:id)
      assert response.prev_page_token == schedulers |> Enum.at(6) |> Map.get(:id)
    end

    test "returns error when gRPC client returns expected error status" do
      GrpcMock.stub(SchedulerMock, :list_keyset, fn _, _stream ->
        %InternalApi.PeriodicScheduler.ListKeysetResponse{
          status: %InternalApi.Status{
            code: Google.Rpc.Code.value(:INVALID_ARGUMENT),
            message: "Some issue"
          }
        }
      end)

      assert {:error, {:user, "Some issue"}} = Client.list_keyset(%{organization_id: "org-1"})
    end

    test "returns error when gRPC client returns unexpected error status" do
      GrpcMock.stub(SchedulerMock, :list_keyset, fn _, _stream ->
        %InternalApi.PeriodicScheduler.ListKeysetResponse{
          status: %InternalApi.Status{
            code: Google.Rpc.Code.value(:RESOURCE_EXHAUSTED),
            message: "Some issue"
          }
        }
      end)

      assert {:error, {:internal, "Unexpected error occurred"}} =
               Client.list_keyset(%{organization_id: "org-1"})
    end
  end

  describe "describe/1" do
    test "fails without task_id" do
      assert {:error, {:user, "missing :task_id"}} = Client.describe(%{})
    end

    test "describes existing task" do
      scheduler = Support.Stubs.Scheduler.create(UUID.uuid4(), UUID.uuid4(), name: "Scheduler")

      assert {:ok, response} = Client.describe(%{task_id: scheduler.id})

      assert response.metadata.id == scheduler.id
      assert response.spec.name == "Scheduler"
    end

    test "returns :not_found error" do
      assert {:error, {:not_found, ""}} = Client.describe(%{task_id: UUID.uuid4()})
    end

    test "returns error when gRPC client returns expected error status" do
      GrpcMock.stub(SchedulerMock, :describe, fn _, _stream ->
        %InternalApi.PeriodicScheduler.DescribeResponse{
          status: %InternalApi.Status{
            code: Google.Rpc.Code.value(:INVALID_ARGUMENT),
            message: "Some issue"
          }
        }
      end)

      assert {:error, {:user, "Some issue"}} = Client.describe(%{task_id: UUID.uuid4()})
    end

    test "returns error when gRPC client returns unexpected error status" do
      GrpcMock.stub(SchedulerMock, :describe, fn _, _stream ->
        %InternalApi.PeriodicScheduler.DescribeResponse{
          status: %InternalApi.Status{
            code: Google.Rpc.Code.value(:RESOURCE_EXHAUSTED),
            message: "Some issue"
          }
        }
      end)

      assert {:error, {:internal, "Unexpected error occurred"}} =
               Client.describe(%{task_id: UUID.uuid4()})
    end
  end

  describe "persist/1" do
    test "fails without name" do
      assert {:error, {:user, "missing :name"}} = Client.persist(%{})
    end

    test "fails without pipeline_file" do
      assert {:error, {:user, "missing :pipeline_file"}} =
               Client.persist(%{
                 name: "Scheduler",
                 reference: %{type: "branch", name: "master"}
               })
    end

    test "fails without requester_id" do
      assert {:error, {:user, "missing :requester_id"}} =
               Client.persist(%{
                 name: "Scheduler",
                 branch: "master",
                 pipeline_file: "pipeline.yml"
               })
    end

    test "persists new task" do
      assert {:ok, response} =
               Client.persist(%{
                 organization_id: "org-1",
                 requester_id: "user-1",
                 name: "Scheduler",
                 branch: "master",
                 pipeline_file: "pipeline.yml"
               })

      assert response.spec.name == "Scheduler"
      assert response.spec.reference == %{"name" => "", "type" => "branch"}
      assert response.spec.pipeline_file == "pipeline.yml"
      assert response.metadata.updated_by.id == "user-1"
    end

    test "persists new task with parameters" do
      assert {:ok, response} =
               Client.persist(%{
                 organization_id: "org-1",
                 requester_id: "user-1",
                 name: "Scheduler",
                 branch: "master",
                 pipeline_file: "pipeline.yml",
                 parameters: [
                   %{
                     name: "param1",
                     description: "param1 description",
                     required: true,
                     default_value: "default value",
                     options: ["option1", "option2"]
                   }
                 ]
               })

      assert response.spec.name == "Scheduler"
      assert response.spec.reference == %{"name" => "", "type" => "branch"}
      assert response.spec.pipeline_file == "pipeline.yml"
      assert parameter = List.first(response.spec.parameters)

      assert parameter.name == "param1"
      assert parameter.description == "param1 description"
      assert parameter.required == true
      assert parameter.default_value == "default value"
      assert parameter.options == ["option1", "option2"]
    end

    test "returns error when gRPC client returns expected error status" do
      GrpcMock.stub(SchedulerMock, :persist, fn _, _stream ->
        %InternalApi.PeriodicScheduler.PersistResponse{
          status: %InternalApi.Status{
            code: Google.Rpc.Code.value(:INVALID_ARGUMENT),
            message: "Some issue"
          }
        }
      end)

      assert {:error, {:user, "Some issue"}} =
               Client.persist(%{
                 organization_id: "org-1",
                 requester_id: "user-1",
                 name: "Scheduler",
                 branch: "master",
                 pipeline_file: "pipeline.yml"
               })
    end

    test "returns error when gRPC client returns unexpected error status" do
      GrpcMock.stub(SchedulerMock, :persist, fn _, _stream ->
        %InternalApi.PeriodicScheduler.PersistResponse{
          status: %InternalApi.Status{
            code: Google.Rpc.Code.value(:RESOURCE_EXHAUSTED),
            message: "Some issue"
          }
        }
      end)

      assert {:error, {:internal, "Unexpected error occurred"}} =
               Client.persist(%{
                 organization_id: "org-1",
                 requester_id: "user-1",
                 name: "Scheduler",
                 branch: "master",
                 pipeline_file: "pipeline.yml"
               })
    end
  end

  describe "delete/1" do
    test "fails without task_id" do
      assert {:error, {:user, "missing :task_id"}} = Client.delete(%{})
    end

    test "fails without requester_id" do
      assert {:error, {:user, "missing :requester_id"}} = Client.delete(%{task_id: UUID.uuid4()})
    end

    test "deletes existing task" do
      scheduler = Support.Stubs.Scheduler.create(UUID.uuid4(), UUID.uuid4(), name: "Scheduler")

      assert {:ok, _response} = Client.delete(%{task_id: scheduler.id, requester_id: "user-1"})
      assert Support.Stubs.DB.find(:schedulers, scheduler.id) == nil
    end

    test "returns :not_found error" do
      assert {:error, {:not_found, ""}} =
               Client.delete(%{task_id: UUID.uuid4(), requester_id: "user-1"})
    end

    test "returns error when gRPC client returns expected error status" do
      GrpcMock.stub(SchedulerMock, :delete, fn _, _stream ->
        %InternalApi.PeriodicScheduler.DeleteResponse{
          status: %InternalApi.Status{
            code: Google.Rpc.Code.value(:INVALID_ARGUMENT),
            message: "Some issue"
          }
        }
      end)

      assert {:error, {:user, "Some issue"}} =
               Client.delete(%{task_id: UUID.uuid4(), requester_id: "user-1"})
    end

    test "returns error when gRPC client returns unexpected error status" do
      GrpcMock.stub(SchedulerMock, :delete, fn _, _stream ->
        %InternalApi.PeriodicScheduler.DeleteResponse{
          status: %InternalApi.Status{
            code: Google.Rpc.Code.value(:RESOURCE_EXHAUSTED),
            message: "Some issue"
          }
        }
      end)

      assert {:error, {:internal, "Unexpected error occurred"}} =
               Client.delete(%{task_id: UUID.uuid4(), requester_id: "user-1"})
    end
  end

  describe "run_now/1" do
    test "fails without task_id" do
      assert {:error, {:user, "missing :task_id"}} = Client.run_now(%{})
    end

    test "fails without requester_id" do
      assert {:error, {:user, "missing :requester_id"}} = Client.run_now(%{task_id: UUID.uuid4()})
    end

    test "runs existing task" do
      scheduler = Support.Stubs.Scheduler.create(UUID.uuid4(), UUID.uuid4(), name: "Scheduler")

      assert {:ok, response} = Client.run_now(%{task_id: scheduler.id, requester_id: "user-1"})
      assert {:ok, _} = UUID.info(response.metadata.workflow_id)
      assert response.metadata.status == "PASSED"
      assert response.spec.reference == %{"name" => "master", "type" => "branch"}
      assert response.spec.pipeline_file == scheduler.pipeline_file
      assert response.metadata.triggered_by.id == "user-1"
    end

    test "runs existing task with parameters" do
      scheduler = Support.Stubs.Scheduler.create(UUID.uuid4(), UUID.uuid4(), name: "Scheduler")

      assert {:ok, response} =
               Client.run_now(%{
                 task_id: scheduler.id,
                 requester_id: "user-1",
                 reference: %{"name" => "develop", "type" => "branch"},
                 pipeline_file: "semaphore.yml",
                 parameters: [
                   %{
                     name: "param1",
                     value: "value1"
                   }
                 ]
               })

      assert {:ok, _} = UUID.info(response.metadata.workflow_id)
      assert response.metadata.status == "PASSED"
      assert response.spec.reference == %{"name" => "develop", "type" => "branch"}
      assert response.spec.pipeline_file == "semaphore.yml"
      assert response.metadata.triggered_by.id == "user-1"

      assert [parameter_value] = response.spec.parameters
      assert parameter_value.name == "param1"
      assert parameter_value.value == "value1"
    end

    test "runs existing task with new reference structure for branch" do
      scheduler = Support.Stubs.Scheduler.create(UUID.uuid4(), UUID.uuid4(), name: "Scheduler")

      assert {:ok, response} =
               Client.run_now(%{
                 task_id: scheduler.id,
                 requester_id: "user-1",
                 reference: %{"type" => "branch", "name" => "feature-branch"},
                 pipeline_file: "semaphore.yml"
               })

      assert {:ok, _} = UUID.info(response.metadata.workflow_id)
      assert response.metadata.status == "PASSED"
      assert response.spec.reference == %{"name" => "feature-branch", "type" => "branch"}
      assert response.spec.pipeline_file == "semaphore.yml"
      assert response.metadata.triggered_by.id == "user-1"
    end

    test "runs existing task with new reference structure for tag" do
      scheduler = Support.Stubs.Scheduler.create(UUID.uuid4(), UUID.uuid4(), name: "Scheduler")

      assert {:ok, response} =
               Client.run_now(%{
                 task_id: scheduler.id,
                 requester_id: "user-1",
                 reference: %{"type" => "tag", "name" => "v1.0.0"},
                 pipeline_file: "semaphore.yml"
               })

      assert {:ok, _} = UUID.info(response.metadata.workflow_id)
      assert response.metadata.status == "PASSED"
      assert response.spec.reference == %{"name" => "v1.0.0", "type" => "tag"}
      assert response.spec.pipeline_file == "semaphore.yml"
      assert response.metadata.triggered_by.id == "user-1"
    end
  end
end
