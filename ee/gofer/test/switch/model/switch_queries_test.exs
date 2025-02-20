defmodule Gofer.Switch.Model.SwitchQueries.Test do
  use ExUnit.Case

  alias Gofer.Switch.Model.SwitchQueries

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table switches cascade;")

    request = %{
      "id" => UUID.uuid4(),
      "ppl_id" => UUID.uuid4(),
      "label" => "master",
      "prev_ppl_artefact_ids" => [UUID.uuid4()],
      "branch_name" => "master",
      "git_ref_type" => "branch"
    }

    {:ok, %{request: request}}
  end

  test "insert switch", ctx do
    {:ok, request} = Map.fetch(ctx, :request)

    assert {:ok, switch} = SwitchQueries.insert(request)
    assert switch.ppl_id == Map.get(request, "ppl_id")
    assert switch.ppl_result == nil
    assert switch.label == "master"
    assert switch.git_ref_type == "branch"
    assert {:ok, _} = UUID.info(switch.id)
    assert {:ok, _} = switch.prev_ppl_artefact_ids |> Enum.at(0) |> UUID.info()
  end

  test "can not insert switch without id", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    request = Map.delete(request, "id")

    assert {:error, _message} = SwitchQueries.insert(request)
  end

  test "can not insert switch without ppl_id", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    request = Map.delete(request, "ppl_id")

    assert {:error, _message} = SwitchQueries.insert(request)
  end

  test "can not insert switch without prev_ppl_artefact_ids", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    request = Map.delete(request, "prev_ppl_artefact_ids")

    assert {:error, _message} = SwitchQueries.insert(request)
  end

  test "can not insert switch without branch_name", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    request = Map.delete(request, "branch_name")

    assert {:error, _message} = SwitchQueries.insert(request)
  end

  test "can not insert 2 switches with the same ppl_id", ctx do
    {:ok, request} = Map.fetch(ctx, :request)

    assert {:ok, _switch1} = SwitchQueries.insert(request)

    request = request |> Map.put("id", UUID.uuid4())
    assert {:error, {:ppl_id_exists, _}} = SwitchQueries.insert(request)
  end

  test "get by id", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    assert {:ok, switch} = SwitchQueries.insert(request)
    id = switch.id

    assert {:ok, response} = SwitchQueries.get_by_id(id)
    assert response.id == id
  end
end
