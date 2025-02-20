defmodule Ppl.PplOrigins.Model.PplOriginsQueries.Test do
  use ExUnit.Case

  import Ecto.Query

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplOrigins.Model.PplOrigins
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias Ppl.EctoRepo, as: Repo

  setup do
    Test.Helpers.truncate_db()

    request_args =  Test.Helpers.schedule_request_factory(:local)

    {:ok, ppl_req} = PplRequestsQueries.insert_request(request_args)
    {:ok, ppl} = PplsQueries.insert(ppl_req)

    {:ok, %{ppl_id: ppl.ppl_id}}
  end

  test "insert passes when pipeline exists", ctx do
    initial_request = %{"something" => "whatever"}
    assert {:ok, ppl_or} = PplOriginsQueries.insert(ctx.ppl_id, initial_request)

    assert ppl_or == PplOrigins |> where(ppl_id: ^ctx.ppl_id) |> Repo.one()
  end

  test "insert fails when pipeline does not exist" do
    initial_request = %{"something" => "whatever"}
    ppl_id = UUID.uuid4()
    assert {:error, _e} = PplOriginsQueries.insert(ppl_id, initial_request)

    assert nil == PplOrigins |> where(ppl_id: ^ppl_id) |> Repo.one()
  end

  test "insert is idempotent in regeard to ppl_id", ctx do
    initial_request = %{"something" => "whatever"}
    assert {:ok, ppl_or} = PplOriginsQueries.insert(ctx.ppl_id, initial_request)

    assert {:ok, ppl_or_2} = PplOriginsQueries.insert(ctx.ppl_id, initial_request)

    assert ppl_or.inserted_at == ppl_or_2.inserted_at
  end

  test "save_definition passes when given valid params", ctx do
    initial_request = %{"something" => "whatever"}
    assert {:ok, ppl_or} = PplOriginsQueries.insert(ctx.ppl_id, initial_request)

    definition = "String with yaml definition"
    assert {:ok, ppl_or} = PplOriginsQueries.save_definition(ppl_or, definition)

    assert ppl_or == PplOrigins |> where(ppl_id: ^ctx.ppl_id) |> Repo.one()
  end
end
