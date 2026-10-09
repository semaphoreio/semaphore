defmodule Gofer.TargetTrigger.Model.TargetTriggerQueries.Test do
  use ExUnit.Case

  alias Gofer.TargetTrigger.Model.TargetTriggerQueries
  alias Gofer.SwitchTrigger.Model.SwitchTriggerQueries
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

    sw_tg = %{
      "switch_id" => switch.id,
      "triggered_by" => "user1",
      "triggered_at" => DateTime.utc_now(),
      "processed" => false,
      "target_names" => ["staging", "prod"],
      "request_token" => "asdf",
      "id" => UUID.uuid4()
    }

    assert {:ok, switch_triger} = SwitchTriggerQueries.insert(sw_tg)

    request = %{
      "switch_id" => switch.id,
      "target_name" => "staging",
      "switch_trigger_id" => switch_triger.id
    }

    {:ok, %{request: request, switch_id: switch.id, st_request: sw_tg}}
  end

  test "insert target_trigger", ctx do
    {:ok, request} = Map.fetch(ctx, :request)

    assert {:ok, target_trigger} = TargetTriggerQueries.insert(request)
    assert target_trigger.switch_id == Map.get(request, "switch_id")
    assert target_trigger.target_name == "staging"
    assert {:ok, _} = UUID.info(target_trigger.schedule_request_token)
  end

  test "insert target_trigger is idempotent operation", ctx do
    {:ok, request} = Map.fetch(ctx, :request)

    assert {:ok, target_trigger_1} = TargetTriggerQueries.insert(request)
    assert {:ok, target_trigger_2} = TargetTriggerQueries.insert(request)
    assert target_trigger_1.inserted_at == target_trigger_2.inserted_at
  end

  test "can not insert target_trigger without required params", ctx do
    {:ok, request} = Map.fetch(ctx, :request)

    ~w(switch_id target_name switch_trigger_id)
    |> Enum.map(fn param_name ->
      request = Map.delete(request, param_name)
      assert {:error, _message} = TargetTriggerQueries.insert(request)
    end)
  end

  test "get_last_n_triggers_for_target returns valid result", ctx do
    "12345"
    |> String.codepoints()
    |> Enum.map(fn ind -> insert_new_trigger(ctx.switch_id, ind) end)

    assert {:ok, result} =
             TargetTriggerQueries.get_last_n_triggers_for_target(ctx.switch_id, "staging", 3)

    assert trigger_events_correct(result, 3, ["5", "4", "3"])

    assert {:ok, result} =
             TargetTriggerQueries.get_last_n_triggers_for_target(ctx.switch_id, "staging", 10)

    assert trigger_events_correct(result, 10, ["5", "4", "3", "2", "1"])
  end

  defp insert_new_trigger(switch_id, ind) do
    sw_tg = %{
      "switch_id" => switch_id,
      "triggered_by" => ind,
      "triggered_at" => DateTime.utc_now(),
      "target_names" => ["staging", "prod"],
      "request_token" => "asdf-" <> ind,
      "id" => UUID.uuid4()
    }

    assert {:ok, switch_triger} = SwitchTriggerQueries.insert(sw_tg)

    request = %{
      "switch_id" => switch_id,
      "target_name" => "staging",
      "switch_trigger_id" => switch_triger.id
    }

    assert {:ok, _tt} = TargetTriggerQueries.insert(request)
  end

  defp trigger_events_correct(triggers, triggers_no, names) when is_list(triggers) do
    assert length(triggers) <= triggers_no

    triggers
    |> Enum.with_index()
    |> Enum.map(fn {trigger, ind} ->
      assert trigger.auto_triggered == false
      assert trigger.error_response == ""
      assert trigger.override == false
      assert trigger.processed == false
      assert trigger.processing_result == ""
      assert DateTime.compare(trigger.triggered_at, DateTime.utc_now()) == :lt
      assert trigger.scheduled_at == nil
      assert trigger.scheduled_pipeline_id == ""
      assert trigger.target_name == "staging"
      assert trigger.triggered_by == Enum.at(names, ind)
    end)

    true
  end

  defp trigger_events_correct(_, _, _), do: false

  test "get_last_n_triggers_for_target returns empty list when there are no triggers" do
    assert {:ok, []} ==
             TargetTriggerQueries.get_last_n_triggers_for_target(UUID.uuid4(), "something", 10)
  end

  test "list_triggers_for_target() returns valid page result", ctx do
    "12345"
    |> String.codepoints()
    |> Enum.map(fn ind -> insert_new_trigger(ctx.switch_id, ind) end)

    assert {:ok, result} =
             TargetTriggerQueries.list_triggers_for_target(ctx.switch_id, "staging", 2, 2)

    assert %Scrivener.Page{} = result
    assert result.page_number == 2
    assert result.page_size == 2
    assert result.total_entries == 5
    assert result.total_pages == 3
    assert trigger_events_correct(result.entries, 2, ["3", "2"])

    assert {:ok, result} =
             TargetTriggerQueries.list_triggers_for_target(ctx.switch_id, "staging", 2, 3)

    assert %Scrivener.Page{} = result
    assert result.page_number == 2
    assert result.page_size == 3
    assert result.total_entries == 5
    assert result.total_pages == 2
    assert trigger_events_correct(result.entries, 2, ["2", "1"])
  end

  test "get_older_unprocessed_triggers_count() returns valid result when older ST is not processed and it's TT is not in db",
       ctx do
    # Switch triggers for other switches should not count
    assert {:ok, switch} =
             SwitchQueries.insert(%{
               "id" => UUID.uuid4(),
               "ppl_id" => UUID.uuid4(),
               "prev_ppl_artefact_ids" => [],
               "branch_name" => "master"
             })

    sw_tg = %{
      "switch_id" => switch.id,
      "triggered_by" => "user1",
      "triggered_at" => DateTime.utc_now(),
      "processed" => false,
      "target_names" => ["staging", "prod"],
      "request_token" => "qwerty",
      "id" => UUID.uuid4()
    }

    assert {:ok, _doesnt_count} = SwitchTriggerQueries.insert(sw_tg)

    # first uprocessed trigger is inserted in setup block

    request =
      ctx.st_request |> Map.put("id", UUID.uuid4()) |> Map.put("request_token", UUID.uuid4())

    assert {:ok, _st_2} = SwitchTriggerQueries.insert(request)

    request =
      ctx.st_request
      |> Map.put("id", UUID.uuid4())
      |> Map.put("request_token", UUID.uuid4())
      |> Map.put("processed", true)

    assert {:ok, st_3} = SwitchTriggerQueries.insert(request)

    request = %{
      "switch_id" => ctx.switch_id,
      "target_name" => "staging",
      "switch_trigger_id" => st_3.id
    }

    assert {:ok, tt_3} = TargetTriggerQueries.insert(request)

    assert {:ok, 2} = tt_3 |> TargetTriggerQueries.get_older_unprocessed_triggers_count()
  end

  test "get_older_unprocessed_triggers_count() returns valid result when older ST is processed and it's TT is not processed",
       ctx do
    # Switch trigger and it's target triggers for other switches should not count
    assert {:ok, switch} =
             SwitchQueries.insert(%{
               "id" => UUID.uuid4(),
               "ppl_id" => UUID.uuid4(),
               "prev_ppl_artefact_ids" => [],
               "branch_name" => "master"
             })

    sw_tg = %{
      "switch_id" => switch.id,
      "triggered_by" => "user1",
      "triggered_at" => DateTime.utc_now(),
      "processed" => false,
      "target_names" => ["staging", "prod"],
      "request_token" => "qwerty",
      "id" => UUID.uuid4()
    }

    assert {:ok, doesnt_count} = SwitchTriggerQueries.insert(sw_tg)

    request = %{
      "switch_id" => switch.id,
      "target_name" => "staging",
      "switch_trigger_id" => doesnt_count.id
    }

    assert {:ok, _tt_doesnt_count} = TargetTriggerQueries.insert(request)

    # second Switch trigger and it's target trigger for sam switch (first is from setup block)
    request =
      ctx.st_request |> Map.put("id", UUID.uuid4()) |> Map.put("request_token", UUID.uuid4())

    assert {:ok, st_1} = SwitchTriggerQueries.insert(request)

    request = %{
      "switch_id" => ctx.switch_id,
      "target_name" => "staging",
      "switch_trigger_id" => st_1.id
    }

    assert {:ok, tt_1} = TargetTriggerQueries.insert(request)

    # third Switch trigger and it's target trigger for sam switch (first is from setup block)
    request =
      ctx.st_request |> Map.put("id", UUID.uuid4()) |> Map.put("request_token", UUID.uuid4())

    assert {:ok, st_2} = SwitchTriggerQueries.insert(request)

    request = %{
      "switch_id" => ctx.switch_id,
      "target_name" => "staging",
      "switch_trigger_id" => st_2.id
    }

    assert {:ok, tt_2} = TargetTriggerQueries.insert(request)

    # first unprocessed switch_trigger from setup block
    assert {:ok, 1} = tt_1 |> TargetTriggerQueries.get_older_unprocessed_triggers_count()

    # first unprocessed switch_trigger from setup block and processed st_1 added in this test
    assert {:ok, 2} = tt_2 |> TargetTriggerQueries.get_older_unprocessed_triggers_count()
  end

  test "get_unprocessed_triggers_count() returns all pending requests for target in switch",
       ctx do
    assert {:ok, 1} =
             TargetTriggerQueries.get_unprocessed_triggers_count(ctx.switch_id, "staging")

    assert {:ok, 1} = TargetTriggerQueries.get_unprocessed_triggers_count(ctx.switch_id, "prod")

    request =
      ctx.st_request
      |> Map.put("id", UUID.uuid4())
      |> Map.put("request_token", UUID.uuid4())
      |> Map.put("processed", true)

    assert {:ok, processed_st} = SwitchTriggerQueries.insert(request)

    assert {:ok, _tt} =
             TargetTriggerQueries.insert(%{
               "switch_id" => ctx.switch_id,
               "target_name" => "staging",
               "switch_trigger_id" => processed_st.id
             })

    assert {:ok, 2} =
             TargetTriggerQueries.get_unprocessed_triggers_count(ctx.switch_id, "staging")

    assert {:ok, 1} = TargetTriggerQueries.get_unprocessed_triggers_count(ctx.switch_id, "prod")
  end

  test "get by switch_trigger_id and target_name", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    assert {:ok, target_trigger} = TargetTriggerQueries.insert(request)
    id = target_trigger.switch_trigger_id
    name = target_trigger.target_name

    assert {:ok, response} = TargetTriggerQueries.get_by_id_and_name(id, name)
    assert response.switch_trigger_id == id
    assert response.target_name == name
  end
end
