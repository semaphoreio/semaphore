defmodule Gofer.SwitchTrigger.Model.SwitchTriggerQueries.Test do
  use ExUnit.Case

  alias Gofer.SwitchTrigger.Model.SwitchTriggerQueries
  alias Gofer.SwitchTrigger.Model.SwitchTrigger
  alias Gofer.Switch.Model.SwitchQueries

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table switches cascade;")

    assert {:ok, switch} =
             SwitchQueries.insert(%{
               "id" => UUID.uuid4(),
               "ppl_id" => UUID.uuid4(),
               "prev_ppl_artefact_ids" => [],
               "branch_name" => "master"
             })

    request = %{
      "switch_id" => switch.id,
      "triggered_by" => "user1",
      "triggered_at" => DateTime.utc_now(),
      "target_names" => ["stg", "prod"],
      "request_token" => "asdf",
      "id" => UUID.uuid4()
    }

    {:ok, %{request: request}}
  end

  test "insert switch_trigger", ctx do
    {:ok, request} = Map.fetch(ctx, :request)

    assert {:ok, switch_triger} = SwitchTriggerQueries.insert(request)
    assert switch_triger.switch_id == Map.get(request, "switch_id")
    assert switch_triger.triggered_by == Map.get(request, "triggered_by")
    assert switch_triger.triggered_at == Map.get(request, "triggered_at")
    assert switch_triger.target_names == Map.get(request, "target_names")
    assert switch_triger.request_token == Map.get(request, "request_token")
    assert switch_triger.processed == false
    assert switch_triger.override == false
  end

  test "can not insert switch_trigger without required params", ctx do
    {:ok, request} = Map.fetch(ctx, :request)

    ~w(id switch_id triggered_by triggered_at target_names request_token)
    |> Enum.map(fn param_name ->
      request = Map.delete(request, param_name)
      assert {:error, _message} = SwitchTriggerQueries.insert(request)
    end)
  end

  test "can not insert 2 switch_triggers with the same id", ctx do
    {:ok, request} = Map.fetch(ctx, :request)

    assert {:ok, _switch_trigger1} = SwitchTriggerQueries.insert(request)
    assert {:error, {:switch_trigger_id_exists, _}} = SwitchTriggerQueries.insert(request)
  end

  test "can not insert 2 switch_triggers with the same request_token", ctx do
    {:ok, request} = Map.fetch(ctx, :request)

    assert {:ok, _switch_trigger1} = SwitchTriggerQueries.insert(request)

    request = request |> Map.update!("id", fn _ -> UUID.uuid4() end)
    assert {:error, {:request_token_exists, _}} = SwitchTriggerQueries.insert(request)
  end

  test "get by request_token", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    assert {:ok, switch_trigger} = SwitchTriggerQueries.insert(request)
    request_token = switch_trigger.request_token

    assert {:ok, response} = SwitchTriggerQueries.get_by_request_token(request_token)
    assert response.request_token == request_token
  end

  test "mark_as_processed for existing switch_trigger succedes", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    assert {:ok, switch_trigger} = SwitchTriggerQueries.insert(request)
    assert switch_trigger.processed == false

    assert {:ok, response = %SwitchTrigger{}} =
             SwitchTriggerQueries.mark_as_processed(switch_trigger)

    assert response.processed == true
    assert switch_trigger.id == response.id
  end

  test "mark_as_processed failes for non-existing switch_trigger", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    switch_trigger = struct(SwitchTrigger, to_atom_keys(request))

    assert {:error, _} = SwitchTriggerQueries.mark_as_processed(switch_trigger)
  end

  test "mark_as_processed for processed switch_trigger succedes", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    assert {:ok, switch_trigger} = SwitchTriggerQueries.insert(request)
    assert switch_trigger.processed == false

    assert {:ok, response = %SwitchTrigger{}} =
             SwitchTriggerQueries.mark_as_processed(switch_trigger)

    assert response.processed == true
    assert switch_trigger.id == response.id

    assert {:ok, response = %SwitchTrigger{}} =
             SwitchTriggerQueries.mark_as_processed(switch_trigger)

    assert response.processed == true
    assert switch_trigger.id == response.id
  end

  defp to_atom_keys(map) do
    map
    |> Enum.reduce(%{}, fn {key, val}, acc ->
      Map.put(acc, String.to_atom(key), val)
    end)
  end
end
