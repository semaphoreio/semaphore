defmodule Ppl.Queues.Model.QueuesQueries.Test do
  use ExUnit.Case

  alias Ppl.Queues.Model.QueuesQueries

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  # Insert

  test "insert new queue with valid params" do
    params = %{name: "production", scope: "project", project_id: UUID.uuid4,
               organization_id: UUID.uuid4, user_generated: true}

    assert {:ok, queue} = QueuesQueries.insert_queue(params)
    assert {:ok, _} = UUID.info(queue.queue_id)
    assert params.name == queue.name
    assert params.scope == queue.scope
    assert params.project_id == queue.project_id
    assert params.organization_id == queue.organization_id
    assert params.user_generated == queue.user_generated
  end

  test "inserting new queue fails when required param is not given" do
    params = %{name: "production", scope: "project", project_id: UUID.uuid4,
               organization_id: UUID.uuid4, user_generated: true}

    ~w(name scope project_id organization_id)a
    |> Enum.map(fn field ->
      params =  Map.delete(params, field)
      assert {:error, _} = QueuesQueries.insert_queue(params)
    end)
  end

  test "try to insert two queues with same name for same project" do
    params = %{name: "production", scope: "project", project_id: UUID.uuid4,
               organization_id: UUID.uuid4, user_generated: true}

    assert {:ok, queue} = QueuesQueries.insert_queue(params)
    assert {:error, msg} = QueuesQueries.insert_queue(params)
    assert msg == {:queue_exists, {params.name, params.project_id, "project"}}
  end

  test "try to insert two org-scoped queues with same name from different projects for same organization" do
    params = %{name: "production", scope: "organization", project_id: UUID.uuid4,
               organization_id: UUID.uuid4, user_generated: true}

    assert {:ok, queue} = QueuesQueries.insert_queue(params)

    paramas = Map.put(params, :project_id, UUID.uuid4)
    assert {:error, msg} = QueuesQueries.insert_queue(params)
    assert msg == {:queue_exists, {params.name, params.organization_id, "organization"}}
  end

  test "two project-scoped queues with same name can be inserted for same organization" do
    params = %{name: "production", scope: "project", project_id: UUID.uuid4,
               organization_id: UUID.uuid4, user_generated: true}

    assert {:ok, queue_1} = QueuesQueries.insert_queue(params)

    params = Map.put(params, :project_id, UUID.uuid4)
    assert {:ok, queue_2} = QueuesQueries.insert_queue(params)

    assert queue_1.queue_id != queue_2.queue_id
  end

  # ListQueues

  defp scope(ind) when ind < 9, do: "project"
  defp scope(ind) when ind > 8, do: "organization"

  defp user_generated(ind) when ind < 5, do: false
  defp user_generated(ind) when ind > 4, do: true

  defp project(ind) when ind in [1, 2, 7, 8, 9, 12], do: "123"
  defp project(ind) when ind in [3, 4, 5, 6, 10, 11], do: "456"

  defp org(ind) when ind in [1, 4, 5, 8, 9, 10], do: "abc"
  defp org(ind) when ind in [2, 3, 6, 7, 11, 12], do: "def"

  defp create_queues() do
    1..12 |> Enum.map(fn ind ->
      params =
        %{name: "production-#{ind}", scope: scope(ind), project_id: project(ind),
          organization_id: org(ind), user_generated: user_generated(ind)}

      assert {:ok, queue} = QueuesQueries.insert_queue(params)
      queue
    end)
  end

  defp assert_same_as(queue, list, index, type) do
    not_included = ~w(user_generated __meta__ inserted_at updated_at)a

    assert queue |> Map.delete(:type)
      == list |> Enum.at(index) |> Map.from_struct() |> Map.drop(not_included)
    assert queue.type == type
  end

  test "list() - given 'implicit + 'project_id' params valid page is returned" do
    queues = create_queues()

    # invalid project_id -> no queues found
    params = %{type: "implicit", project_id: "000", org_id: :skip}
    assert {:ok, res = %{entries: []}} = QueuesQueries.list_queues(params, 2, 1)
    assert %{page_number: 1, page_size: 1, total_entries: 0, total_pages: 1} = res

    # valid project_id -> return expected result
    params = %{type: "implicit", project_id: "123", org_id: :skip}
    assert {:ok, res = %{entries: [queue]}} = QueuesQueries.list_queues(params, 2, 1)
    assert %{page_number: 2, page_size: 1, total_entries: 2, total_pages: 2} = res

    assert_same_as(queue, queues, 1, "implicit")
  end

  test "list() - given 'implicit + 'org_id' params nothing is found" do
    queues = create_queues()

    # no queues found since all implicit ones are project-scoped
    params = %{type: "implicit", project_id: :skip, org_id: "456"}
    assert {:ok, res = %{entries: []}} = QueuesQueries.list_queues(params, 2, 1)
    assert %{page_number: 1, page_size: 1, total_entries: 0, total_pages: 1} = res
  end

  test "list() - given 'user_generated' + 'project_id' params valid page is returned" do
    queues = create_queues()

    params = %{type: "user_generated", project_id: "123", org_id: :skip}
    assert {:ok, res = %{entries: [queue]}} = QueuesQueries.list_queues(params, 2, 1)
    assert %{page_number: 2, page_size: 1, total_entries: 2, total_pages: 2} = res

    assert_same_as(queue, queues, 7, "user_generated")
  end

  test "list() - given 'user_generated' + 'org_id' params valid page is returned" do
    queues = create_queues()

    params = %{type: "user_generated", project_id: :skip, org_id: "abc"}
    assert {:ok, res = %{entries: [queue]}} = QueuesQueries.list_queues(params, 2, 1)
    assert %{page_number: 2, page_size: 1, total_entries: 2, total_pages: 2} = res

    assert_same_as(queue, queues, 9, "user_generated")
  end

  test "list() - given 'user_generated' + both ids params valid page is returned" do
    queues = create_queues()

    params = %{type: "user_generated", project_id: "123", org_id: "abc"}
    assert {:ok, res = %{entries: [queue]}} = QueuesQueries.list_queues(params, 2, 1)
    assert %{page_number: 2, page_size: 1, total_entries: 4, total_pages: 4} = res

    assert_same_as(queue, queues, 7, "user_generated")

    params = %{type: "user_generated", project_id: "123", org_id: "abc"}
    assert {:ok, res = %{entries: [queue]}} = QueuesQueries.list_queues(params, 4, 1)
    assert %{page_number: 4, page_size: 1, total_entries: 4, total_pages: 4} = res

    assert_same_as(queue, queues, 9, "user_generated")
  end

  test "list() - given 'all' + 'project_id' params valid page is returned" do
    queues = create_queues()

    params = %{type: "all", project_id: "456", org_id: :skip}
    assert {:ok, res = %{entries: [queue]}} = QueuesQueries.list_queues(params, 2, 1)
    assert %{page_number: 2, page_size: 1, total_entries: 4, total_pages: 4} = res

    assert_same_as(queue, queues, 3, "implicit")

    params = %{type: "all", project_id: "456", org_id: :skip}
    assert {:ok, res = %{entries: [queue]}} = QueuesQueries.list_queues(params, 4, 1)
    assert %{page_number: 4, page_size: 1, total_entries: 4, total_pages: 4} = res

    assert_same_as(queue, queues, 5, "user_generated")
  end

  test "list() - given 'all' + both ids params valid page is returned" do
    queues = create_queues()

    params = %{type: "all", project_id: "456", org_id: "def"}
    assert {:ok, res = %{entries: [queue]}} = QueuesQueries.list_queues(params, 2, 1)
    assert %{page_number: 2, page_size: 1, total_entries: 6, total_pages: 6} = res

    assert_same_as(queue, queues, 3, "implicit")

    params = %{type: "all", project_id: "456", org_id: "def"}
    assert {:ok, res = %{entries: [queue]}} = QueuesQueries.list_queues(params, 4, 1)
    assert %{page_number: 4, page_size: 1, total_entries: 6, total_pages: 6} = res

    assert_same_as(queue, queues, 5, "user_generated")

    params = %{type: "all", project_id: "456", org_id: "def"}
    assert {:ok, res = %{entries: [queue]}} = QueuesQueries.list_queues(params, 6, 1)
    assert %{page_number: 6, page_size: 1, total_entries: 6, total_pages: 6} = res

    assert_same_as(queue, queues, 11, "user_generated")
  end

  # Get

  test "get existing queue by name and project_id" do
    params = %{name: "production", scope: "project", project_id: UUID.uuid4,
               organization_id: UUID.uuid4, user_generated: true}

    assert {:ok, queue_1} = QueuesQueries.insert_queue(params)

    get_params = params |> Map.take([:name, :project_id, :scope])
    assert {:ok, queue_1} == QueuesQueries.get_by_name_and_id(get_params)
  end

  test "get existing queue by name and organization_id" do
    params = %{name: "production", scope: "organization", project_id: UUID.uuid4,
               organization_id: UUID.uuid4, user_generated: true}

    assert {:ok, queue_1} = QueuesQueries.insert_queue(params)

    get_params = params |> Map.take([:name, :organization_id, :scope])
    assert {:ok, queue_1} == QueuesQueries.get_by_name_and_id(get_params)
  end

  test "get queue by name and project_id retuns proper error when queue is not found" do
    params = %{name: "production", scope: "project", project_id: UUID.uuid4}

    assert {:error, msg} = QueuesQueries.get_by_name_and_id(params)
    assert msg == "Queue #{params.name} for project #{params.project_id} not found."
  end

  test "get queue by name and organization_id retuns proper error when queue is not found" do
    params = %{name: "production", scope: "organization",
               organization_id: UUID.uuid4}

    assert {:error, msg} = QueuesQueries.get_by_name_and_id(params)
    assert msg == "Queue #{params.name} for organization #{params.organization_id} not found."
  end

  # Get or insert

  test "get_or_insert_queue() inserts new queue when queue with same params is not found" do
    params = %{name: "production", scope: "organization", project_id: UUID.uuid4,
               organization_id: UUID.uuid4, user_generated: true}

    assert {:ok, queue_1} = QueuesQueries.get_or_insert_queue(params)

    get_params = params |> Map.take([:name, :organization_id, :scope])
    assert {:ok, queue_1} == QueuesQueries.get_by_name_and_id(get_params)
  end

  test "get_or_insert_queue() returns existing queue if one exists with same params" do
    params = %{name: "production", scope: "organization", project_id: UUID.uuid4,
               organization_id: UUID.uuid4, user_generated: true}

    assert {:ok, queue_1} = QueuesQueries.insert_queue(params)

    assert {:ok, queue_1} == QueuesQueries.get_or_insert_queue(params)
  end
end
