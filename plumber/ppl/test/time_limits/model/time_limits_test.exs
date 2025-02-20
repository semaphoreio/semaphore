defmodule Ppl.TimeLimits.Model.TimeLimits.Test do
  use ExUnit.Case
  doctest Ppl.TimeLimits.Model.TimeLimits

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

end
