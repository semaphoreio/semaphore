defmodule Ppl.PplTraces.Model.PplTraces.Test do
  use ExUnit.Case
  doctest Ppl.PplTraces.Model.PplTraces

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

end
