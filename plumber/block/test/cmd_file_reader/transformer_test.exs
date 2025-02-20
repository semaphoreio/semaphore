defmodule Block.CommandsFileReader.TransformerTest do
  use ExUnit.Case

  alias Block.CommandsFileReader.Transformer

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    args = %{"service" => "local", "repo_name" => "4_cmd_file", "working_dir" => ".semaphore"}
    {:ok, %{"args" => args}}
  end

  test "Transformer replaces commands_file field with commands when given valid data", ctx do
      args = Map.get(ctx, "args")
      map = %{"commands_file" => "/.semaphore/cmd_file_1.sh"}

      assert {:ok, response} = Transformer.transform(map, args, :none)
      assert is_map(response)
      assert Map.has_key?(response, "commands")
      assert !Map.has_key?(response, "commands_file")
      assert ["echo foo", "echo bar", "echo baz"] == Map.get(response, "commands")
  end

  test "Transformer returns :malformed error when given file does not exist", ctx do
      args = Map.get(ctx, "args")
      map = %{"commands_file" => "does-not-exist.sh"}

      assert {:error, {:malformed, _message}} = Transformer.transform(map, args, :none)
  end

  test "Transformer returns error if element parameter is not map", ctx do
      args = Map.get(ctx, "args")
      not_map = "This should be map."

      assert {:error, response} = Transformer.transform(not_map, args, :none)
      assert String.contains?(response, "Expected map, got: This should be map.")
  end

  test "Transformer appends commands from cmd_file to commands list if merging_order = :global_first", ctx do
    args = Map.get(ctx, "args")
    map = %{"commands" => ["echo one", "echo two"], "commands_file" => "/.semaphore/cmd_file_1.sh"}

    assert {:ok, response} = Transformer.transform(map, args, :global_first)
    assert is_map(response)
    assert Map.has_key?(response, "commands")
    assert !Map.has_key?(response, "commands_file")
    assert ["echo one", "echo two", "echo foo", "echo bar", "echo baz"] == Map.get(response, "commands")
  end

  test "Transformer appends commands list to commands from cmd_file if merging_order = :local_first", ctx do
    args = Map.get(ctx, "args")
    map = %{"commands" => ["echo one", "echo two"], "commands_file" => "/.semaphore/cmd_file_1.sh"}

    assert {:ok, response} = Transformer.transform(map, args, :local_first)
    assert is_map(response)
    assert Map.has_key?(response, "commands")
    assert !Map.has_key?(response, "commands_file")
    assert ["echo foo", "echo bar", "echo baz", "echo one", "echo two"] == Map.get(response, "commands")
  end

  test "Transformer trims each line read from cmd_file" do
    lines = "First line\r\nSecond line\t\nThird line\nFourht line\n"

    assert {:ok, cmds} = Transformer.get_commands_from_lines({:ok, lines})

    assert ["First line", "Second line", "Third line", "Fourht line"] == cmds
  end
end
