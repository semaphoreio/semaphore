defmodule Audit.EventTest do
  use Support.DataCase

  alias InternalApi.Audit.Event.{Resource, Operation, Medium}

  test "creating events" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    operation_id = Ecto.UUID.generate()
    resource_id = Ecto.UUID.generate()
    resource_name = "my-secret"

    {:ok, event} =
      Audit.Event.create(%{
        resource: Resource.value(:Secret),
        operation: Operation.value(:Added),
        resource_id: resource_id,
        resource_name: resource_name,
        org_id: org_id,
        user_id: user_id,
        username: "hello",
        ip_address: "127.0.0.1",
        operation_id: operation_id,
        timestamp: DateTime.from_unix!(0),
        metadata: %{"hello" => "world"},
        medium: Medium.value(:Web)
      })

    assert event.resource == Resource.value(:Secret)
    assert event.operation == Operation.value(:Added)
    assert event.resource_id == resource_id
    assert event.resource_name == resource_name
    assert event.org_id == org_id
    assert event.user_id == user_id
    assert event.operation_id == operation_id
    assert event.ip_address == "127.0.0.1"
    assert event.username == "hello"
    assert event.metadata == %{"hello" => "world"}
    assert event.medium == Medium.value(:Web)
  end

  test "listing events" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()

    {:ok, _} =
      Audit.Event.create(%{
        resource: Resource.value(:Secret),
        operation: Operation.value(:Added),
        org_id: org_id,
        user_id: user_id,
        username: "hello",
        ip_address: "127.0.0.1",
        operation_id: Ecto.UUID.generate(),
        timestamp: DateTime.from_unix!(100),
        medium: Medium.value(:Web)
      })

    {:ok, _} =
      Audit.Event.create(%{
        resource: Resource.value(:Secret),
        operation: Operation.value(:Removed),
        org_id: org_id,
        user_id: user_id,
        username: "hello",
        ip_address: "127.0.0.1",
        operation_id: Ecto.UUID.generate(),
        timestamp: DateTime.from_unix!(200),
        medium: Medium.value(:Web)
      })

    {:ok, _} =
      Audit.Event.create(%{
        resource: Resource.value(:Secret),
        operation: Operation.value(:Removed),
        org_id: Ecto.UUID.generate(),
        user_id: user_id,
        username: "hello",
        ip_address: "127.0.0.1",
        operation_id: Ecto.UUID.generate(),
        timestamp: DateTime.from_unix!(300),
        medium: Medium.value(:Web)
      })

    events = Audit.Event.all(%{org_id: org_id})
    assert length(events) == 2

    assert Enum.at(events, 0).resource == Resource.value(:Secret)
    assert Enum.at(events, 0).operation == Operation.value(:Added)
    assert Enum.at(events, 0).org_id == org_id
    assert Enum.at(events, 0).user_id == user_id
    assert Enum.at(events, 0).operation_id != ""
    assert Enum.at(events, 0).username == "hello"
    assert Enum.at(events, 0).medium == Medium.value(:Web)

    assert Enum.at(events, 1).resource == Resource.value(:Secret)
    assert Enum.at(events, 1).operation == Operation.value(:Removed)
    assert Enum.at(events, 1).org_id == org_id
    assert Enum.at(events, 1).user_id == user_id
    assert Enum.at(events, 0).operation_id != ""
    assert Enum.at(events, 1).username == "hello"
    assert Enum.at(events, 1).medium == Medium.value(:Web)
  end

  describe "paginated/2" do
    defp create_event(org_id, seconds, opts \\ []) do
      {:ok, event} =
        Audit.Event.create(%{
          resource: Resource.value(:Secret),
          operation: Operation.value(:Added),
          org_id: org_id,
          user_id: Ecto.UUID.generate(),
          username: "hello",
          ip_address: "127.0.0.1",
          operation_id: Keyword.get_lazy(opts, :operation_id, &Ecto.UUID.generate/0),
          timestamp: DateTime.from_unix!(seconds),
          medium: Medium.value(:Web)
        })

      event
    end

    defp walk(org_id, params, page_size, token \\ "", acc \\ []) do
      {events, next, _prev} =
        Audit.Event.paginated(
          Map.merge(%{org_id: org_id}, params),
          %{page_size: page_size, page_token: token, direction: :NEXT}
        )

      acc = acc ++ Enum.map(events, & &1.id)

      if next in [nil, ""], do: acc, else: walk(org_id, params, page_size, next, acc)
    end

    test "walking NEXT pages returns every event exactly once, also across timestamp ties" do
      org_id = Ecto.UUID.generate()
      other_org_id = Ecto.UUID.generate()

      # many events share a timestamp, so page boundaries land inside ties
      events =
        for seconds <- [10, 10, 10, 20, 20, 30, 30, 30, 30, 40], do: create_event(org_id, seconds)

      _ = for seconds <- [10, 20, 30], do: create_event(other_org_id, seconds)

      expected =
        events
        |> Enum.sort_by(&{DateTime.to_unix(&1.timestamp), &1.operation_id, &1.id}, :desc)
        |> Enum.map(& &1.id)

      for page_size <- [1, 2, 3, 4, 20] do
        assert walk(org_id, %{}, page_size) == expected
      end
    end

    test "walking NEXT pages keeps every event of one operation (same timestamp and operation_id)" do
      org_id = Ecto.UUID.generate()
      operation_id = Ecto.UUID.generate()

      same_operation = for _ <- 1..5, do: create_event(org_id, 10, operation_id: operation_id)

      others = for seconds <- [5, 20], do: create_event(org_id, seconds)

      expected =
        (same_operation ++ others)
        |> Enum.sort_by(&{DateTime.to_unix(&1.timestamp), &1.operation_id, &1.id}, :desc)
        |> Enum.map(& &1.id)

      for page_size <- [1, 2, 3] do
        assert walk(org_id, %{}, page_size) == expected
      end
    end

    test "a token issued before id was a cursor field still pages forward without losing rows" do
      org_id = Ecto.UUID.generate()
      operation_id = Ecto.UUID.generate()

      [first | _] = for _ <- 1..3, do: create_event(org_id, 10, operation_id: operation_id)
      older = create_event(org_id, 5)

      legacy_token = Paginator.cursor_for_record(first, [:timestamp, :operation_id])

      {events, _, _} =
        Audit.Event.paginated(%{org_id: org_id}, %{
          page_size: 10,
          page_token: legacy_token,
          direction: :NEXT
        })

      ids = Enum.map(events, & &1.id)

      # everything at or after the legacy cursor, older events included
      assert older.id in ids
      assert length(ids) == 4
    end

    test "NEXT pages are bounded by the cursor timestamp (keeps the export linear)" do
      org_id = Ecto.UUID.generate()
      event = create_event(org_id, 10)
      token = Paginator.cursor_for_record(event, [:timestamp, :operation_id, :id])

      {sql, params} =
        Ecto.Adapters.SQL.to_sql(
          :all,
          Audit.Repo,
          Audit.Event.paginated_query(
            %{org_id: org_id, from_timestamp: nil, to_timestamp: nil},
            %{
              direction: :NEXT,
              page_token: token
            }
          )
        )

      assert sql =~ ~r/"timestamp" <= \$\d/
      assert DateTime.from_unix!(10) in params

      {sql, _} =
        Ecto.Adapters.SQL.to_sql(
          :all,
          Audit.Repo,
          Audit.Event.paginated_query(
            %{org_id: org_id, from_timestamp: nil, to_timestamp: nil},
            %{
              direction: :PREVIOUS,
              page_token: token
            }
          )
        )

      refute sql =~ ~r/"timestamp" <= /
    end

    test "a crafted token with a bogus timestamp gets no bound" do
      token = Paginator.Cursor.encode(%{timestamp: "not a datetime", operation_id: "x", id: 1})

      {sql, _} =
        Ecto.Adapters.SQL.to_sql(
          :all,
          Audit.Repo,
          Audit.Event.paginated_query(
            %{org_id: Ecto.UUID.generate(), from_timestamp: nil, to_timestamp: nil},
            %{direction: :NEXT, page_token: token}
          )
        )

      refute sql =~ ~r/"timestamp" <= /
    end

    test "a token issued before id was a cursor field still pages backward" do
      org_id = Ecto.UUID.generate()
      operation_id = Ecto.UUID.generate()

      newer = create_event(org_id, 20)
      [first | _] = for _ <- 1..3, do: create_event(org_id, 10, operation_id: operation_id)

      legacy_token = Paginator.cursor_for_record(first, [:timestamp, :operation_id])

      {events, _, _} =
        Audit.Event.paginated(%{org_id: org_id}, %{
          page_size: 10,
          page_token: legacy_token,
          direction: :PREVIOUS
        })

      ids = Enum.map(events, & &1.id)

      assert newer.id in ids
      assert length(ids) == 4
    end

    test "walking NEXT pages inside a time range" do
      org_id = Ecto.UUID.generate()

      events = for seconds <- [10, 10, 20, 20, 20, 30, 40], do: create_event(org_id, seconds)

      range = %{from_timestamp: DateTime.from_unix!(10), to_timestamp: DateTime.from_unix!(30)}

      expected =
        events
        |> Enum.filter(&(DateTime.to_unix(&1.timestamp) in [10, 20]))
        |> Enum.sort_by(&{DateTime.to_unix(&1.timestamp), &1.operation_id, &1.id}, :desc)
        |> Enum.map(& &1.id)

      for page_size <- [1, 2, 5, 20] do
        assert walk(org_id, range, page_size) == expected
      end
    end

    test "PREVIOUS pages still work after the cursor bound" do
      org_id = Ecto.UUID.generate()
      for seconds <- [10, 20, 30, 40], do: create_event(org_id, seconds)

      {_, next, _} =
        Audit.Event.paginated(%{org_id: org_id}, %{page_size: 2, page_token: "", direction: :NEXT})

      {page2, _, prev} =
        Audit.Event.paginated(%{org_id: org_id}, %{
          page_size: 2,
          page_token: next,
          direction: :NEXT
        })

      assert Enum.map(page2, &DateTime.to_unix(&1.timestamp)) == [20, 10]

      {page1, _, _} =
        Audit.Event.paginated(%{org_id: org_id}, %{
          page_size: 2,
          page_token: prev,
          direction: :PREVIOUS
        })

      assert Enum.map(page1, &DateTime.to_unix(&1.timestamp)) == [40, 30]
    end

    test "a token that is not a valid cursor fails the same way as before" do
      org_id = Ecto.UUID.generate()
      create_event(org_id, 10)

      assert_raise ArgumentError, fn ->
        Audit.Event.paginated(%{org_id: org_id}, %{
          page_size: 2,
          page_token: "not a cursor!",
          direction: :NEXT
        })
      end
    end
  end
end
