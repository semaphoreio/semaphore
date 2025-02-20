defmodule Block.CodeRepo.Local.Test do
  use ExUnit.Case
  doctest Block.CodeRepo.Local

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")
    :ok
  end

end
