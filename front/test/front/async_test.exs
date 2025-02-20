defmodule Front.AsyncTest do
  use ExUnit.Case

  alias Front.Async

  describe "run" do
    test "return tuple of results when list of functions is passed" do
      assert Async.run([
               fn -> "S" end,
               fn -> "E" end,
               fn -> "M" end,
               fn -> "A" end,
               fn -> "P" end,
               fn -> "H" end,
               fn -> "O" end,
               fn -> "R" end,
               fn -> "E" end
             ]) == {"S", "E", "M", "A", "P", "H", "O", "R", "E"}
    end
  end
end
