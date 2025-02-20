defmodule Zebra.Apis.PublicJobApi.Debug do
  alias Zebra.Apis.PublicJobApi.Serializer

  def debug_job_params(job, duration \\ 0)
  def debug_job_params(job, 0), do: debug_job_params(job, 3600)

  def debug_job_params(job, duration_in_secs) do
    execution_time_limit = duration_in_secs

    name = "Debug Session for Job #{job.id}"
    serialized_spec = Serializer.spec(job)
    spec = job.spec
    sleep = "sleep #{execution_time_limit}"

    # Copy everything to new job, except commands
    spec = spec |> Map.put("epilogue_always_commands", [])
    spec = spec |> Map.put("epilogue_on_pass_commands", [])
    spec = spec |> Map.put("epilogue_on_fail_commands", [])

    # Overwrite commands with a sleep. This will keep the job up for N seconds.
    spec = spec |> Map.put("commands", [sleep])

    # Original commands are injected into a file
    spec = spec |> Map.put("files", [commands_file(job, serialized_spec)])

    spec = spec |> Zebra.Models.Job.decode_spec()

    params = [
      organization_id: job.organization_id,
      project_id: job.project_id,
      index: 0,
      machine_type: job.machine_type,
      machine_os_image: job.machine_os_image,
      execution_time_limit: execution_time_limit,
      name: name,
      spec: spec
    ]

    {:ok, params}
  end

  def make_debug_project_params(org_id, project, machine_type, duration) do
    machine_type = debug_project_machine(org_id, machine_type)
    os_image = get_default_os_image(org_id, machine_type)

    spec = %{
      project_id: project.id,
      agent: %{machine: %{os_image: os_image, type: machine_type}}
    }

    execution_time_limit = debug_project_duration(duration)

    sleep = "sleep #{execution_time_limit}"

    # This will keep the job up for N seconds.
    spec = spec |> Map.put("commands", [sleep])

    spec = spec |> Zebra.Models.Job.decode_spec()

    [
      organization_id: org_id,
      project_id: project.id,
      name: debug_project_name(project.name),
      machine_type: debug_project_machine(org_id, machine_type),
      execution_time_limit: execution_time_limit,
      index: 0,
      machine_os_image: os_image,
      spec: spec
    ]
  end

  def debug_project_machine(org_id, ""),
    do: debug_project_machine(org_id, Zebra.Machines.default_debug_project_machine(org_id))

  def debug_project_machine(_org_id, machine_type), do: machine_type

  def debug_project_duration(0), do: debug_project_duration(3600)
  def debug_project_duration(d), do: d

  defp debug_project_name(project_name) do
    "Debug Session for project " <> project_name
  end

  defp get_default_os_image(org_id, machine_type) do
    {:ok, os_image} = Zebra.Machines.default_os_image(org_id, machine_type)
    os_image
  end

  #
  # For a debug job, we overwrite the original commands with a sleep,
  # and put the original commands into a file that the user can source, if needed.
  #
  # For self-hosted jobs, we can't assume Linux
  # so we don't use an extension in the file name.
  #
  defp commands_file(job, spec) do
    commands_file_name =
      if Zebra.Models.Job.self_hosted?(job.machine_type) do
        "commands"
      else
        "commands.sh"
      end

    commands_file_content =
      [
        Enum.join(spec.commands, "\n"),
        Enum.join(spec.epilogue_always_commands, "\n"),
        Enum.join(spec.epilogue_on_pass_commands, "\n"),
        Enum.join(spec.epilogue_on_fail_commands, "\n")
      ]
      |> Enum.join("\n")

    %{
      path: commands_file_name,
      content: Base.encode64(commands_file_content)
    }
  end
end
