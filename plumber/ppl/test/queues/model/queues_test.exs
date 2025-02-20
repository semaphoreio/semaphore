defmodule Ppl.Queues.Model.Queues.Test do
  use ExUnit.Case
  doctest Ppl.Queues.Model.Queues

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

end
