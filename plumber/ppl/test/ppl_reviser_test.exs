defmodule Ppl.PplsReviser.Test do
  use ExUnit.Case

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Queues.Model.QueuesQueries
  alias Ppl.{PplsReviser, Actions}

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  test "when there is no queue def in yml spec, implicit queue is set" do
    {:ok, ppl} =
      %{"label" => "master", "project_id" => "123", "organization_id" => "456"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl.ppl_id)


    assert {:ok, ppl} = PplsReviser.update_ppl(ppl_req, %{}, %{})
    assert {:ok, _} = UUID.info(ppl.queue_id)

    assert {:ok, queue} = QueuesQueries.get_by_id(ppl.queue_id)
    assert queue.name == "master-.semaphore/semaphore.yml"
    assert queue.scope == "project"
    assert queue.user_generated == false
    assert queue.project_id == "123"
    assert queue.organization_id == "456"
  end

  test "if implicit queue already exists new one is not created" do
    {:ok, ppl} =
      %{"label" => "master", "project_id" => "123", "organization_id" => "456"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl.ppl_id)


    assert {:ok, ppl} = PplsReviser.update_ppl(ppl_req, %{}, %{})
    assert {:ok, _} = UUID.info(ppl.queue_id)

    {:ok, ppl_2} =
      %{"label" => "master", "project_id" => "123", "organization_id" => "456"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req_2} = PplRequestsQueries.get_by_id(ppl_2.ppl_id)

    assert {:ok, ppl_2} = PplsReviser.update_ppl(ppl_req_2, %{}, %{})
    assert ppl.queue_id == ppl_2.queue_id
  end

  test "just queue name in yml spec -> project scoped user queue is set" do
    {:ok, ppl} =
      %{"label" => "master", "project_id" => "123", "organization_id" => "456"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl.ppl_id)

    definition = %{"queue" => %{"name" => "production"}}
    assert {:ok, ppl} = PplsReviser.update_ppl(ppl_req, definition, %{})
    assert {:ok, _} = UUID.info(ppl.queue_id)

    assert {:ok, queue} = QueuesQueries.get_by_id(ppl.queue_id)
    assert queue.name == "production"
    assert queue.scope == "project"
    assert queue.user_generated == true
    assert queue.project_id == "123"
    assert queue.organization_id == "456"
  end

  test "organization scoped queue from yml spec is properly created in DB" do
    {:ok, ppl} =
      %{"label" => "master", "project_id" => "123", "organization_id" => "456"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl.ppl_id)

    definition = %{"queue" => %{"name" => "production", "scope" => "organization"}}
    assert {:ok, ppl} = PplsReviser.update_ppl(ppl_req, definition, %{})
    assert {:ok, _} = UUID.info(ppl.queue_id)

    assert {:ok, queue} = QueuesQueries.get_by_id(ppl.queue_id)
    assert queue.name == "production"
    assert queue.scope == "organization"
    assert queue.user_generated == true
    assert queue.project_id == "123"
    assert queue.organization_id == "456"
  end

  test "if user generated project queue already exists new one is not created" do
    {:ok, ppl} =
      %{"label" => "master", "project_id" => "123", "organization_id" => "456"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl.ppl_id)

    definition = %{"queue" => %{"name" => "production"}}
    assert {:ok, ppl} = PplsReviser.update_ppl(ppl_req, definition, %{})
    assert {:ok, _} = UUID.info(ppl.queue_id)

    {:ok, ppl_2} =
      %{"label" => "master", "project_id" => "123", "organization_id" => "456"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req_2} = PplRequestsQueries.get_by_id(ppl_2.ppl_id)

    definition = %{"queue" => %{"name" => "production"}}
    assert {:ok, ppl_2} = PplsReviser.update_ppl(ppl_req_2, definition, %{})

    assert ppl.queue_id == ppl_2.queue_id
  end

  test "if user generated organization queue already exists new one is not created" do
    {:ok, ppl} =
      %{"label" => "master", "project_id" => "123", "organization_id" => "456"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl.ppl_id)

    definition = %{"queue" => %{"name" => "production", "scope" => "organization"}}
    assert {:ok, ppl} = PplsReviser.update_ppl(ppl_req, definition, %{})
    assert {:ok, _} = UUID.info(ppl.queue_id)

    {:ok, ppl_2} =
      %{"label" => "master", "project_id" => "123", "organization_id" => "456"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req_2} = PplRequestsQueries.get_by_id(ppl_2.ppl_id)

    definition = %{"queue" => %{"name" => "production", "scope" => "organization"}}
    assert {:ok, ppl_2} = PplsReviser.update_ppl(ppl_req_2, definition, %{})

    assert ppl.queue_id == ppl_2.queue_id
  end

  test "when multiple queue defintions are provided, first one which condition is met is used" do
    {:ok, ppl} =
      %{"label" => "master", "branch_name" => "master", "project_id" => "123",
        "organization_id" => "456"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl.ppl_id)

    cond_1 = %{"when" => "branch = 'dev'", "name" => "dev-queue", "scope" => "organization"}
    cond_2 = %{"when" => "branch = 'master'", "name" => "production", "scope" => "organization"}
    cond_3 = %{"when" => true, "name" => "all-in", "scope" => "project"}
    definition = %{"queue" => [cond_1, cond_2, cond_3]}
    source_args = %{"git_ref_type" => "branch"}

    assert {:ok, ppl} = PplsReviser.update_ppl(ppl_req, definition, source_args)
    assert {:ok, _} = UUID.info(ppl.queue_id)

    assert {:ok, queue} = QueuesQueries.get_by_id(ppl.queue_id)
    assert queue.name == "production"
    assert queue.scope == "organization"
    assert queue.user_generated == true
    assert queue.project_id == "123"
    assert queue.organization_id == "456"
  end

  test "when multiple queue defintions are provided but non of the conditons is met, implicit queue is used" do
    {:ok, ppl} =
      %{"label" => "master", "branch_name" => "master", "project_id" => "123",
        "organization_id" => "456"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl.ppl_id)

    cond_1 = %{"when" => "branch = 'dev'", "name" => "dev-queue", "scope" => "organization"}
    cond_2 = %{"when" => "branch != 'master'", "name" => "production", "scope" => "organization"}
    cond_3 = %{"when" => false, "name" => "all-in", "scope" => "project"}
    definition = %{"queue" => [cond_1, cond_2, cond_3]}
    source_args = %{"git_ref_type" => "branch"}

    assert {:ok, ppl} = PplsReviser.update_ppl(ppl_req, definition, source_args)
    assert {:ok, _} = UUID.info(ppl.queue_id)

    assert {:ok, queue} = QueuesQueries.get_by_id(ppl.queue_id)
    assert queue.name == "master-.semaphore/semaphore.yml"
    assert queue.scope == "project"
    assert queue.user_generated == false
    assert queue.project_id == "123"
    assert queue.organization_id == "456"
  end

  test "if only processing type is set in queue def, implicit queue is used" do
    {:ok, ppl} =
      %{"label" => "master", "branch_name" => "master", "project_id" => "123",
        "organization_id" => "456"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl.ppl_id)

    definition = %{"queue" => %{"processing" => "parallel"}}
    assert {:ok, ppl} = PplsReviser.update_ppl(ppl_req, definition, %{})
    assert {:ok, _} = UUID.info(ppl.queue_id)

    assert ppl.parallel_run == true

    assert {:ok, queue} = QueuesQueries.get_by_id(ppl.queue_id)
    assert queue.name == "master-.semaphore/semaphore.yml"
    assert queue.scope == "project"
    assert queue.user_generated == false
    assert queue.project_id == "123"
    assert queue.organization_id == "456"
  end
end
