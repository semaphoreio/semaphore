defmodule Ppl.DeleteRequests.Model.DeleteRequests.Test do
  use ExUnit.Case
  doctest Ppl.DeleteRequests.Model.DeleteRequests
    
  setup do
    Test.Helpers.truncate_db()
    
    {:ok, %{}}
  end
end