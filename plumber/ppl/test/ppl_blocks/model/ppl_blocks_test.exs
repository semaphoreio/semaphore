defmodule Ppl.PplBlocks.Model.PplBlocks.Test do
  use ExUnit.Case
  doctest Ppl.PplBlocks.Model.PplBlocks

  setup do
    Test.Helpers.truncate_db()
    :ok
  end
end
