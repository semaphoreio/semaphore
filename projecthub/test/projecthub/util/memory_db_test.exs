defmodule Support.MemoryDbTest do
  use Projecthub.DataCase
  alias Support.MemoryDb
  doctest MemoryDb, import: true

  setup do
    {:ok, _} = start_supervised({MemoryDb, name: MemoryDbTest})
    :ok
  end

  describe "MemoryDb" do
    test ".all returns no records for empty tables" do
      assert [] == MemoryDb.all(MemoryDbTest, :users)
    end

    test ".add adds records to the database" do
      assert MemoryDb.add(MemoryDbTest, :users, %{name: "adam"})
      assert MemoryDb.add(MemoryDbTest, :users, %{name: "john"})
      assert MemoryDb.add(MemoryDbTest, :users, %{name: "joe"})

      assert 3 == length(MemoryDb.all(MemoryDbTest, :users))
    end

    test ".add replaces existing records" do
      %{id: id} = MemoryDb.add(MemoryDbTest, :users, %{name: "adam"})
      assert [%{name: "adam"}] = MemoryDb.all(MemoryDbTest, :users)

      MemoryDb.add(MemoryDbTest, :users, %{id: id, name: "joe"})
      assert [%{name: "joe"}] = MemoryDb.all(MemoryDbTest, :users)

      MemoryDb.add(MemoryDbTest, :users, %{name: "joe"})
      assert [%{name: "joe"}, %{name: "joe"}] = MemoryDb.all(MemoryDbTest, :users)
    end

    test ".get fetches record by internal id" do
      id = 1
      assert nil == MemoryDb.get(MemoryDbTest, :users, id)
      MemoryDb.add(MemoryDbTest, :users, %{id: id, name: "adam"})
      assert %{name: "adam", id: id} == MemoryDb.get(MemoryDbTest, :users, id)
    end

    test ".find looks for records matching predicate" do
      MemoryDb.add(MemoryDbTest, :users, %{name: "adam", cookies: 2})
      MemoryDb.add(MemoryDbTest, :users, %{name: "john", cookies: 4})
      MemoryDb.add(MemoryDbTest, :users, %{name: "joe", broken_cookies: 2})

      assert %{name: "john"} =
               MemoryDb.find(MemoryDbTest, :users, fn user ->
                 String.length(user.name) == 4 && user.cookies == 4
               end)

      assert nil ==
               MemoryDb.find(MemoryDbTest, :users, fn user ->
                 String.length(user.name) == 3 && Map.get(user, :cookies) == 2
               end)
    end
  end
end
