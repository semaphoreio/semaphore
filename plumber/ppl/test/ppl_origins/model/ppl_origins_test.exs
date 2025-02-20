defmodule Ppl.PplOrigins.Model.PplOrigins.Test do
  use ExUnit.Case

  doctest Ppl.PplOrigins.Model.PplOrigins

  setup do
    Test.Helpers.truncate_db()
    :ok
  end
end
