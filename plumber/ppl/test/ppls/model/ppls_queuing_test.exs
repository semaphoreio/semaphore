defmodule Ppl.Ppls.Model.PplsQueuingTest do
  use ExUnit.Case, serialize: true
  doctest Ppl.Ppls.Model.PplsQueries

  alias Ppl.PplRequests.Model.PplRequests
  alias Ppl.Ppls.Model.{Ppls, PplsQueuing, PplsQueries}
  alias Ppl.EctoRepo, as: Repo
  alias LogTee, as: LT

  setup do
    Test.Helpers.truncate_db()

    :ok
  end

  test "get oldest row in queuing state" do
    insert_pipeline(%{queue_id: "123", state: "queuing", commit_sha: "1"})
    insert_pipeline(%{queue_id: "123", state: "queuing", commit_sha: "2"})

    [ppl] = execute_query(&PplsQueuing.queuing_enter_scheduling_select_query/0)
    assert(ppl.commit_sha == "1")
  end

  test "do not select younger if older is in scheduling" do
    insert_pipeline(%{queue_id: "123", state: "queuing", commit_sha: "1", in_scheduling: true})
    insert_pipeline(%{queue_id: "123", state: "queuing", commit_sha: "2"})

    assert([] = execute_query(&PplsQueuing.queuing_enter_scheduling_select_query/0))
  end

  test "select if terminate_request is set" do
    insert_pipeline(%{queue_id: "123", state: "running", commit_sha: "1"})
    insert_pipeline(%{queue_id: "123", state: "queuing", commit_sha: "2"})
    insert_pipeline(%{queue_id: "123", state: "queuing", commit_sha: "3",
                      terminate_request: "stop"})

    [ppl] = execute_query(&PplsQueuing.queuing_enter_scheduling_select_query/0)
    assert(ppl.commit_sha == "3")
  end

  test "Update in_scheduling" do
    insert_pipeline(%{queue_id: "123", state: "queuing", commit_sha: "1", in_scheduling: false})
      |> LT.debug("insert")

    after_insert = NaiveDateTime.utc_now()
    |> LT.debug("after_insert")

    {:ok, [{ppl_old, ppl}]} = PplsQueuing.queuing_enter_scheduling()
    |> LT.debug("ppl enter-scheduling")

    assert(ppl.in_scheduling == true)
    assert(NaiveDateTime.compare(ppl_old.inserted_at, ppl.inserted_at) == :eq)
    assert(NaiveDateTime.compare(ppl_old.inserted_at, after_insert) == :lt)
    assert(NaiveDateTime.compare(ppl_old.updated_at, after_insert) == :lt)
    assert(NaiveDateTime.compare(ppl.updated_at, after_insert) == :gt)
  end

  test "Nothing to update" do
    assert(
      {:ok, []} == PplsQueuing.queuing_enter_scheduling()
    )
  end

  defp insert_pipeline(data) do
    {:ok, pplr} = %PplRequests{id: UUID.uuid4()} |> Repo.insert()
    Ppls
    |> struct(data |> Map.merge(%{ppl_id: pplr.id}))
    |> Repo.insert()
  end

  defp execute_query(f) do
    {:ok, %{columns: columns, rows: rows}} = f.() |> Repo.query()

    Enum.map(rows, &Ppl.EctoRepo.load(Ppls, {columns, &1}))
  end
end
