defmodule Ppl.Actions.ListRequestersImpl.Test do
  use ExUnit.Case

  import Ecto.Query

  alias Ppl.Actions.ListRequestersImpl
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.PplRequests.Model.{PplRequests, PplRequestsQueries}
  alias InternalApi.Plumber.ListRequestersRequest

  setup do
    Test.Helpers.truncate_db()
    {:ok, %{org_id: Ecto.UUID.generate(), now: DateTime.utc_now()}}
  end

  # each call creates a request from a distinct requester (distinct login)
  defp insert_requester(org_id, idx, opts \\ []) do
    triggered_by = Keyword.get(opts, :triggered_by, "hook")
    minutes_ago = Keyword.get(opts, :minutes_ago, 10)

    params =
      Test.Helpers.schedule_request_factory(
        %{"triggered_by" => triggered_by, "organization_id" => org_id},
        :github
      )

    {:ok, ppl_req} = PplRequestsQueries.insert_request(params)
    {:ok, ppl_req} = PplRequestsQueries.insert_source(ppl_req, %{"repo_host_username" => "user-#{idx}"})

    inserted_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(-minutes_ago * 60, :second)

    {1, _} =
      from(pr in PplRequests, where: pr.id == ^ppl_req.id)
      |> Repo.update_all(set: [inserted_at: inserted_at])

    ppl_req.id
  end

  defp request(org_id, now, page_size, page_token \\ "") do
    ListRequestersRequest.new(
      organization_id: org_id,
      requested_at_gt: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(now) - 3 * 3600),
      requested_at_lte: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(now) + 60),
      page_size: page_size,
      page_token: page_token
    )
  end

  defp collect_all(org_id, now, page_size) do
    Stream.unfold({:first, ""}, fn
      :done ->
        nil

      {_, token} ->
        {:ok, resp} = ListRequestersImpl.list_requesters(request(org_id, now, page_size, token))
        next = if resp.next_page_token == "", do: :done, else: {:next, resp.next_page_token}
        {resp.requesters, next}
    end)
    |> Enum.to_list()
  end

  test "pages through all requesters; last page has empty token", ctx do
    ids = for i <- 1..5, do: insert_requester(ctx.org_id, i, minutes_ago: 10 + i)

    pages = collect_all(ctx.org_id, ctx.now, 2)

    assert Enum.map(pages, &length/1) == [2, 2, 1]
    assert pages |> List.flatten() |> Enum.map(& &1.ppl_id) |> Enum.sort() == Enum.sort(ids)
  end

  test "exact multiple of page size: last full page has empty token", ctx do
    for i <- 1..4, do: insert_requester(ctx.org_id, i, minutes_ago: 10 + i)

    assert {:ok, first} = ListRequestersImpl.list_requesters(request(ctx.org_id, ctx.now, 2))
    assert length(first.requesters) == 2
    assert first.next_page_token != ""

    assert {:ok, second} =
             ListRequestersImpl.list_requesters(request(ctx.org_id, ctx.now, 2, first.next_page_token))

    assert length(second.requesters) == 2
    assert second.next_page_token == ""

    # page order is stable (oldest request first) and pages do not overlap
    all = first.requesters ++ second.requesters
    assert all |> Enum.map(& &1.ppl_id) |> Enum.uniq() |> length() == 4
    seconds = Enum.map(all, & &1.requested_at.seconds)
    assert seconds == Enum.sort(seconds)
  end

  test "no requesters => empty page and empty token", ctx do
    assert {:ok, resp} = ListRequestersImpl.list_requesters(request(ctx.org_id, ctx.now, 10))
    assert resp.requesters == []
    assert resp.next_page_token == ""
  end

  test "fewer than a page => no next token", ctx do
    insert_requester(ctx.org_id, 1)

    assert {:ok, resp} = ListRequestersImpl.list_requesters(request(ctx.org_id, ctx.now, 10))
    assert length(resp.requesters) == 1
    assert resp.next_page_token == ""
  end

  test "excludes other organizations, scheduler requests and requests outside the window", ctx do
    kept = insert_requester(ctx.org_id, 1)
    insert_requester(Ecto.UUID.generate(), 2)
    insert_requester(ctx.org_id, 3, triggered_by: "schedule")
    insert_requester(ctx.org_id, 4, minutes_ago: 5 * 60)

    assert {:ok, resp} = ListRequestersImpl.list_requesters(request(ctx.org_id, ctx.now, 10))
    assert Enum.map(resp.requesters, & &1.ppl_id) == [kept]
    assert resp.next_page_token == ""
  end

  test "same requester on the same day is listed once", ctx do
    # keep both requests on the same UTC day
    {a, b} = if ctx.now.hour == 0 and ctx.now.minute < 5, do: {30, 20}, else: {2, 1}
    insert_requester(ctx.org_id, 1, minutes_ago: a)
    insert_requester(ctx.org_id, 1, minutes_ago: b)

    assert {:ok, resp} = ListRequestersImpl.list_requesters(request(ctx.org_id, ctx.now, 10))
    assert length(resp.requesters) == 1
  end
end
