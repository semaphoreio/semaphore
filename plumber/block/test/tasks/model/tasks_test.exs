defmodule Block.Tasks.Model.Tasks.Test do
  use ExUnit.Case
  doctest Block.Tasks.Model.Tasks

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")
    :ok
  end

end
