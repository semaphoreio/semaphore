defmodule Gofer.Target.Model.TargetQueries.Test do
  use ExUnit.Case

  alias Gofer.Target.Model.TargetQueries
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
      "name" => "staging",
      "pipeline_path" => "./stg.yml",
      "auto_promote_when" => "true"
    }

    {:ok, %{request: request, switch: switch}}
  end

  test "insert target", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    {:ok, switch} = Map.fetch(ctx, :switch)

    assert {:ok, target} = TargetQueries.insert(request, switch)
    assert target.switch_id == switch.id
    assert target.name == "staging"
    assert target.pipeline_path == "./stg.yml"
    assert target.auto_promote_when == "true"
  end

  test "can not insert target without required params", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    {:ok, switch} = Map.fetch(ctx, :switch)

    ~w(name pipeline_path)
    |> Enum.map(fn param_name ->
      request = Map.delete(request, param_name)
      assert {:error, _message} = TargetQueries.insert(request, switch)
    end)
  end

  test "can not insert target when switch param has no id field", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    switch = %{something: "with no id field"}

    assert {:error, _message} = TargetQueries.insert(request, switch)
  end

  test "can not insert target when switch param is not a map", ctx do
    {:ok, request} = Map.fetch(ctx, :request)

    assert {:error, _message} = TargetQueries.insert(request, :not_a_map)
  end

  test "can not insert 2 targets with the same name for same switch", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    {:ok, switch} = Map.fetch(ctx, :switch)

    assert {:ok, _target1} = TargetQueries.insert(request, switch)
    assert {:error, {:target_exists, _}} = TargetQueries.insert(request, switch)
  end

  test "get_targets_description_for_switch returns valid result", ctx do
    {:ok, switch} = Map.fetch(ctx, :switch)

    assert {:ok, _t1} =
             %{"name" => "staging", "pipeline_path" => "./stg.yml"}
             |> TargetQueries.insert(switch)

    assert {:ok, _t2} =
             %{"name" => "prod1", "pipeline_path" => "./prod1.yml"}
             |> TargetQueries.insert(switch)

    additional_params = %{
      "parameter_env_vars" => %{"Test" => %{"name" => "Test", "options" => ["a", "b"]}},
      "auto_trigger_on" => [%{"result" => "passed", "branch" => ["mast.", "xyz"]}]
    }

    assert {:ok, _t3} =
             %{"name" => "prod2", "pipeline_path" => "./prod2.yml"}
             |> Map.merge(additional_params)
             |> TargetQueries.insert(switch)

    assert {:ok, result} = TargetQueries.get_targets_description_for_switch(switch.id)
    assert is_list(result)
    assert_targets_description_valid(result)
  end

  defp assert_targets_description_valid(targets) do
    targets
    |> Enum.map(fn target ->
      assert target.name in ["staging", "prod1", "prod2"]
      assert target.pipeline_path in ["./stg.yml", "./prod1.yml", "./prod2.yml"]

      if target.name == "prod2" do
        assert target.parameter_env_vars ==
                 %{"Test" => %{"name" => "Test", "options" => ["a", "b"]}}

        assert target.auto_trigger_on ==
                 [%{"result" => "passed", "branch" => ["mast.", "xyz"]}]
      else
        assert target.parameter_env_vars == %{}
        assert target.auto_trigger_on == []
      end
    end)
  end

  test "get_targets_description_for_switch returns empty list when there are no targets" do
    assert {:ok, []} == TargetQueries.get_targets_description_for_switch(UUID.uuid4())
  end

  test "get by switch_id and name", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    {:ok, switch} = Map.fetch(ctx, :switch)
    assert {:ok, target} = TargetQueries.insert(request, switch)
    id = target.switch_id
    name = target.name

    assert {:ok, response} = TargetQueries.get_by_id_and_name(id, name)
    assert response.switch_id == id
    assert response.name == name
    assert response.pipeline_path == Map.get(request, "pipeline_path")
  end
end
