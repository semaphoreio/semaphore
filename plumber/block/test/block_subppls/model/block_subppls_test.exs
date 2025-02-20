defmodule Block.BlockSubppls.Model.BlockSubppls.Test do
  use ExUnit.Case
  doctest Block.BlockSubppls.Model.BlockSubppls

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")
    :ok
  end

end
