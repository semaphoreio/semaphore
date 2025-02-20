defmodule JobMatrix.TransformerTest do
  use ExUnit.Case

  alias JobMatrix.Transformer

  doctest JobMatrix.Transformer

  test "nil matrix" do
    assert {:ok, []} = Transformer.to_env_vars_list(nil)
  end

end
