defmodule Ppl.Ppls.Model.Ppls.Test do
  use ExUnit.Case
  doctest Ppl.Ppls.Model.Ppls

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

end
