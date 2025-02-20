defmodule Ppl.Sup.STM.Test do
  use ExUnit.Case

  setup  do
    Test.Helpers.truncate_db()

    :ok
  end

  test "STM supervisor can start up without issues" do
    assert {:ok, pid} = start_supervised(Ppl.Sup.STM)
  end
end
