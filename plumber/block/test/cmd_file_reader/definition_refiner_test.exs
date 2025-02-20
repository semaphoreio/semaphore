defmodule Block.CommandsFileReader.DefinitionRefinerTest do
  use ExUnit.Case

  alias Block.CommandsFileReader.DefinitionRefiner

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    args = %{"service" => "local", "repo_name" => "4_cmd_file",
            "working_dir" => ".semaphore", "file_name" => "semaphore.yml"}
    jobs = [%{"commands" => ["echo foo"], "name" => "Job 1"}]
    build =  %{"jobs" => jobs}
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    ppl = %{"build" =>build, "name" => "Cmd_File test", "agent" => agent, "version" => "v1.0"}
    {:ok, %{"data" => {args, ppl, build}}}
  end

  test "commands_file in jobs in request is replaced with command field", ctx do
    {args, ppl, build} = Map.get(ctx, "data")
    jobs = [%{"commands_file" => "cmd_file_1.sh", "name" => "Job 1"}]
    ppl = %{ppl | "build" => Map.put(build, "jobs", jobs)}

    assert {:ok, response} = DefinitionRefiner.cmd_files_to_commands(ppl, args)

    build = Map.get(response, "build")
    job = Enum.at(Map.get(build, "jobs"), 0)
    assert Map.has_key?(job, "commands")
    assert !Map.has_key?(job, "commands_file")
    assert ["echo foo", "echo bar", "echo baz"] == Map.get(job, "commands")
  end

  test "commands_file in prologue in request is replaced with command field", ctx do
    {args, ppl, build} = Map.get(ctx, "data")
    prologue = %{"commands_file" => "cmd_file_1.sh"}
    ppl = %{ppl | "build" => Map.put(build, "prologue", prologue)}

    assert {:ok, response} = DefinitionRefiner.cmd_files_to_commands(ppl, args)

    build = Map.get(response, "build")
    prologue = Map.get(build, "prologue")
    assert Map.has_key?(prologue, "commands")
    assert !Map.has_key?(prologue, "commands_file")
    assert ["echo foo", "echo bar", "echo baz"] == Map.get(prologue, "commands")
  end

  test "commands_file in all epilogue variants in request is replaced with command field", ctx do
    {args, ppl, build} = Map.get(ctx, "data")
    cmds = %{"commands_file" => "cmd_file_1.sh"}
    epilogue = %{"always" => cmds, "on_pass" => cmds, "on_fail" => cmds}
    ppl = %{ppl | "build" => Map.put(build, "epilogue", epilogue)}

    assert {:ok, response} = DefinitionRefiner.cmd_files_to_commands(ppl, args)

    build = Map.get(response, "build")
    epilogue = Map.get(build, "epilogue")
    assert_epilogue_variant_valid(epilogue, "always")
    assert_epilogue_variant_valid(epilogue, "on_pass")
    assert_epilogue_variant_valid(epilogue, "on_fail")
  end

  defp assert_epilogue_variant_valid(epilogue, key) do
    epilogue_variant = Map.get(epilogue, key)
    assert Map.has_key?(epilogue_variant, "commands")
    assert !Map.has_key?(epilogue_variant, "commands_file")
    assert ["echo foo", "echo bar", "echo baz"] == Map.get(epilogue_variant, "commands")
  end

  test "commands field in job is not replaced if there is no commands_file field", ctx do
    {args, ppl, _build} = Map.get(ctx, "data")

    assert {:ok, response} = DefinitionRefiner.cmd_files_to_commands(ppl, args)

    build = Map.get(response, "build")
    job = Enum.at(Map.get(build, "jobs"), 0)
    assert Map.has_key?(job, "commands")
    commands = Map.get(job, "commands")
    assert length(commands) == 1
    command = Enum.at(commands, 0)
    assert command == "echo foo"
  end

  test "commands field in prologue is not replaced if there is no commands_file field", ctx do
    {args, ppl, build} = Map.get(ctx, "data")
    prologue = %{"commands" => ["echo prologue"]}
    ppl = %{ppl | "build" => Map.put(build, "prologue", prologue)}

    assert {:ok, response} = DefinitionRefiner.cmd_files_to_commands(ppl, args)

    build = Map.get(response, "build")
    prologue = Map.get(build, "prologue")
    assert Map.has_key?(prologue, "commands")
    commands = Map.get(prologue, "commands")
    assert length(commands) == 1
    command = Enum.at(commands, 0)
    assert command == "echo prologue"
  end

  test "commands field in epilogue is not replaced if there is no commands_file field", ctx do
    {args, ppl, build} = Map.get(ctx, "data")
    epilogue = %{"always" => %{"commands" => ["echo epilogue"]}}
    ppl = %{ppl | "build" => Map.put(build, "epilogue", epilogue)}

    assert {:ok, response} = DefinitionRefiner.cmd_files_to_commands(ppl, args)

    build = Map.get(response, "build")
    epilogue = Map.get(build, "epilogue")
    always = Map.get(epilogue, "always")
    assert Map.has_key?(always, "commands")
    commands = Map.get(always, "commands")
    assert length(commands) == 1
    command = Enum.at(commands, 0)
    assert command == "echo epilogue"
  end

  test "file given in commands_file field in job doesn't exist", ctx do
    {args, ppl, build} = Map.get(ctx, "data")
    jobs = [%{"commands_file" => "does-not-exist.sh", "name" => "Job 1"}]
    ppl = %{ppl | "build" => Map.put(build, "jobs", jobs)}

    assert {:error, {:malformed, _message}} = DefinitionRefiner.cmd_files_to_commands(ppl, args)
  end

  test "file given in commands_file field in prologue doesn't exist", ctx do
    {args, ppl, build} = Map.get(ctx, "data")
    prologue = %{"commands_file" => "does-not-exist.sh"}
    ppl = %{ppl | "build" => Map.put(build, "prologue", prologue)}

    assert {:error, {:malformed, _message}} = DefinitionRefiner.cmd_files_to_commands(ppl, args)
  end

  test "file given in commands_file field in epilogue doesn't exist", ctx do
    {args, ppl, build} = Map.get(ctx, "data")
    epilogue = %{"always" => %{"commands_file" => "does-not-exist.sh"}}
    ppl = %{ppl | "build" => Map.put(build, "epilogue", epilogue)}

    assert {:error, {:malformed, _message}} = DefinitionRefiner.cmd_files_to_commands(ppl, args)
  end


end
