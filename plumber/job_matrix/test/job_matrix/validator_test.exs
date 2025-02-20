defmodule JobMatrix.ValidatorTest do
  use ExUnit.Case

  alias JobMatrix.Validator

  doctest JobMatrix.Validator


  test "send matrix of wrong type, should fail" do
    matrix = "matrix"
    assert {:error, {:malformed, msg}} = Validator.validate(matrix)
    assert msg == "'matrix' must be non-empty List."
  end

  test "send an empty matrix, should fail" do
    matrix = []
    assert {:error, {:malformed, msg}} = Validator.validate(matrix)
    assert msg == "'matrix' must be non-empty List."
  end

  test "send two axes with same 'env_var' value, should fail" do
    axis  = %{"env_var" => "ERLANG", "values" => ["18", "19"]}
    axis1 = %{"env_var" => "ELIXIR", "values" => ["1.5", "1.4"]}
    axis2 = %{"env_var" => "PYTHON", "values" => ["2.7", "3.4"]}
    axis3 = %{"env_var" => "NODE",   "values" => ["6.9", "6.8"]}
    matrix = [axis1, axis, axis2, axis3, axis]
    assert {:error, {:malformed, msg}} = Validator.validate(matrix)
    assert msg == "Duplicate name: 'ERLANG' in Matrix."
  end

  test "send two axes with same 'env_var' and 'software' value, should fail" do
    env_var_axis = %{"env_var" => "ERLANG", "values" => ["18", "19"]}
    axis1 = %{"env_var" => "ELIXIR", "values" => ["1.5", "1.4"]}
    axis2 = %{"env_var" => "PYTHON", "values" => ["2.7", "3.4"]}
    axis3 = %{"software" => "NODE", "versions" => ["6.9", "6.8"]}
    software_axis = %{"software" => "ERLANG", "versions" => ["15", "16"]}
    matrix = [env_var_axis, axis1, axis2, axis3, software_axis]
    assert {:error, {:malformed, msg}} = Validator.validate(matrix)
    assert msg == "Duplicate name: 'ERLANG' in Matrix."
  end

  test "send two axes with same 'software' value, should fail" do
    axis  = %{"software" => "ERLANG", "versions" => ["18", "19"]}
    axis1 = %{"software" => "ELIXIR", "versions" => ["1.5", "1.4"]}
    axis2 = %{"software" => "PYTHON", "versions" => ["2.7", "3.4"]}
    axis3 = %{"software" => "NODE", "versions" => ["6.9", "6.8"]}
    matrix = [axis1, axis2, axis, axis3, axis]
    assert {:error, {:malformed, msg}} = Validator.validate(matrix)
    assert msg == "Duplicate name: 'ERLANG' in Matrix."
  end

  test "send an axis of invalid type, should fail" do
    axis = "invalid axis type"
    matrix = [axis]
    assert {:error, {:malformed, msg}} = Validator.validate(matrix)
    assert msg == "Job matrix: #{inspect axis} missing required field(s)."
  end

  test "send an empty axis, should fail" do
    axis = %{}
    matrix = [axis]
    assert {:error, {:malformed, msg}} = Validator.validate(matrix)
    assert msg == "Job matrix: %{} missing required field(s)."
  end

  test "send an axis that has an 'env_var' field of invalid type, should fail" do
    axis = %{"env_var" => 5, "values" => ["14", "15"]}
    matrix = [axis]
    assert {:error, {:malformed, msg}} = Validator.validate(matrix)
    assert msg == "Job matrix: #{inspect axis} missing required field(s)."
  end

  test "send an axis that has a 'software' field of invalid type, should fail" do
    axis = %{"software" => 5, "versions" => ["14", "15"]}
    matrix = [axis]
    assert {:error, {:malformed, msg}} = Validator.validate(matrix)
    assert msg == "Job matrix: #{inspect axis} missing required field(s)."
  end

  test "send axis that has 'values' field of invalid type, should fail" do
    axis = %{"env_var" => "name", "values" => 5}
    matrix = [axis]
    assert {:error, {:malformed, msg}} = Validator.validate(matrix)
    assert msg == "Job matrix: #{inspect axis} missing required field(s)."
  end

  test "send axis that has 'versions' field of invalid type, should fail" do
    axis = %{"software" => "name", "versions" => 5}
    matrix = [axis]
    assert {:error, {:malformed, msg}} = Validator.validate(matrix)
    assert msg == "Job matrix: #{inspect axis} missing required field(s)."
  end

  test "send axis that has an empty List for 'values' field, should fail" do
    axis = %{"env_var" => "name", "values" => []}
    matrix = [axis]
    assert {:error, {:malformed, msg}} = Validator.validate(matrix)
    assert msg == "List 'values' in job matrix must not be empty."
  end

  test "send axis that has an empty List for 'versions' field, should fail" do
    axis = %{"software" => "name", "versions" => []}
    matrix = [axis]
    assert {:error, {:malformed, msg}} = Validator.validate(matrix)
    assert msg == "List 'versions' in job matrix must not be empty."
  end

end
