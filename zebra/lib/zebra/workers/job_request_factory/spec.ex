defmodule Zebra.Workers.JobRequestFactory.Spec do
  alias Zebra.Workers.JobRequestFactory.JobRequest

  @max_num_of_envs 300

  def commands(spec) do
    cmds = spec.commands |> Enum.map(&JobRequest.command/1)

    {:ok, cmds}
  end

  def env_vars(%{env_vars: env_vars}) when length(env_vars) > @max_num_of_envs do
    {
      :stop_job_processing,
      "The number of environment variables is higher than #{@max_num_of_envs}"
    }
  end

  def env_vars(spec) do
    envs =
      spec.env_vars
      |> Enum.map(fn v ->
        JobRequest.env_var(v.name, v.value)
      end)

    {:ok, envs}
  end

  def files(spec) do
    files =
      spec.files
      |> Enum.map(fn f ->
        {:ok, content} = Base.decode64(f.content, ignore: :whitespace, padding: true)

        JobRequest.file(f.path, content, "0644")
      end)

    {:ok, files}
  end

  def epilogue(spec) do
    always =
      if is_list(spec.epilogue_always_commands) && spec.epilogue_always_commands != [] do
        spec.epilogue_always_commands
      else
        spec.epilogue_commands
      end

    {:ok,
     %{
       always_commands: always |> Enum.map(&JobRequest.command/1),
       on_pass: spec.epilogue_on_pass_commands |> Enum.map(&JobRequest.command/1),
       on_fail: spec.epilogue_on_fail_commands |> Enum.map(&JobRequest.command/1)
     }}
  end
end
