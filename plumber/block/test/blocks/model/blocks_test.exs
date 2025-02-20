defmodule Block.Blocks.Model.Blocks.Test do
  use ExUnit.Case
  doctest Block.Blocks.Model.Blocks

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")
    :ok
  end
end
