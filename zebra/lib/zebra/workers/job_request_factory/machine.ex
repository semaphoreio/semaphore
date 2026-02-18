defmodule Zebra.Workers.JobRequestFactory.Machine do
  def validate(org_id, job) do
    cond do
      Zebra.Models.Job.self_hosted?(job.machine_type) ->
        validate_self_hosted_type(org_id, job.machine_type)

      Zebra.Machines.Brownout.os_image_in_brownout?(
        DateTime.utc_now(),
        job.organization_id,
        job.machine_os_image
      ) ->
        Watchman.increment(
          {"brownout.job_stopped", [job.machine_os_image, job.organization_id, job.project_id]}
        )

        {
          :stop_job_processing,
          "OS image '#{job.machine_os_image}' for machine type '#{job.machine_type}' is currently in a brownout phase. Please use another OS image."
        }

      Zebra.Machines.registered?(job.organization_id, job.machine_type, job.machine_os_image) ->
        :ok

      Zebra.Machines.obsoleted?(job.machine_type, job.machine_os_image) ->
        Zebra.Machines.default_os_image(job.organization_id, job.machine_type)
        |> case do
          {:ok, default_os_image} ->
            {
              :stop_job_processing,
              "Machine type '#{job.machine_type}' with os image '#{job.machine_os_image}' is obsoleted. Please use '#{default_os_image}' os image for your jobs."
            }

          {:error, _} ->
            {
              :stop_job_processing,
              "Unknown machine type '#{job.machine_type}' with os image '#{job.machine_os_image}'"
            }
        end

      true ->
        {
          :stop_job_processing,
          "Unknown machine type '#{job.machine_type}' with os image '#{job.machine_os_image}'"
        }
    end
  end

  def validate_self_hosted_type(org_id, machine_type) do
    case Zebra.Workers.Agent.SelfHostedAgent.load(org_id) do
      {:ok, available_types} ->
        if Enum.any?(available_types, fn t -> t == machine_type end) do
          :ok
        else
          {:stop_job_processing, "Unknown self-hosted agent type '#{machine_type}'"}
        end

      # If we can't load the agent types,
      # we assume the agent type exists, and return true.
      _ ->
        true
    end
  end

  def uses_docker_containers?(job) do
    spec = Zebra.Models.Job.decode_spec(job.spec)

    spec.agent.containers != []
  end

  def home_path(job) do
    cond do
      uses_docker_containers?(job) ->
        "~"

      Zebra.Models.Job.self_hosted?(job.machine_type) ->
        "~"

      Zebra.Machines.mac?(job.machine_type) ->
        "/Users/semaphore"

      Zebra.Machines.linux?(job.machine_type) ->
        "/home/semaphore"

      true ->
        raise "Unknown home path"
    end
  end

  def agent_environment(job) do
    if uses_docker_containers?(job) do
      "container"
    else
      "VM"
    end
  end
end
