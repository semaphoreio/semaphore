defmodule Zebra.Apis.PublicJobApi.Serializer do
  alias Semaphore.Jobs.V1alpha.Job

  def serialize(job) do
    Job.new(metadata: metadata(job), spec: spec(job), status: status(job))
  end

  def metadata(job) do
    Job.Metadata.new(
      [
        id: job.id,

        #
        # We didn't require names to be non-empty before (we do now),
        # so we need to default to empty string here to avoid throwing
        # a Protobuf.InvalidError error here.
        #
        name: job.name || ""
      ] ++
        encode_timestamps(
          create_time: job.created_at,
          update_time: job.updated_at,
          start_time: job.started_at,
          finish_time: job.finished_at
        )
    )
  end

  def spec(job) do
    if job.spec do
      env_vars = request_git_vars(job.request)

      job.spec
      |> Map.replace!("env_vars", job.spec["env_vars"] ++ env_vars)
      |> Zebra.Models.Job.decode_spec()
    else
      Job.Spec.new()
    end
  end

  def status(job) do
    status = [state: map_state(job), result: map_result(job)]
    status = status ++ map_status_agent(job)

    Job.Status.new(status)
  end

  def map_status_agent(job) do
    # If the job has not been assigned to an agent yet, there's no agent field.
    if job.aasm_state != Zebra.Models.Job.state_started() &&
         job.aasm_state != Zebra.Models.Job.state_finished() do
      []
    else
      [
        agent:
          Job.Status.Agent.new(
            name: map_agent_name(job),
            ip: map_agent_ip(job),
            ports: map_agent_ports(job)
          )
      ]
    end
  end

  def map_agent_ip(job) do
    if job.agent_ip_address do
      job.agent_ip_address
    else
      ""
    end
  end

  def map_agent_name(job) do
    if job.agent_name do
      job.agent_name
    else
      ""
    end
  end

  def map_agent_ports(job) do
    if job.port do
      [Job.Status.Agent.Port.new(name: "ssh", number: job.port)]
    else
      []
    end
  end

  def map_state(job) do
    case job.aasm_state do
      "pending" -> Job.Status.State.value(:PENDING)
      "enqueued" -> Job.Status.State.value(:QUEUED)
      "scheduled" -> Job.Status.State.value(:QUEUED)
      "waiting-for-agent" -> Job.Status.State.value(:QUEUED)
      "started" -> Job.Status.State.value(:RUNNING)
      "finished" -> Job.Status.State.value(:FINISHED)
    end
  end

  def map_result(job) do
    case job.result do
      "passed" -> Job.Status.Result.value(:PASSED)
      "failed" -> Job.Status.Result.value(:FAILED)
      "stopped" -> Job.Status.Result.value(:STOPPED)
      nil -> Job.Status.Result.value(:NONE)
    end
  end

  def encode_timestamps(timestamps) do
    timestamps
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.map(fn {k, v} -> {k, DateTime.to_unix(v)} end)
  end

  def request_git_vars(%{"env_vars" => env_vars}) do
    env_vars
    |> Enum.filter(fn env_var ->
      String.starts_with?(env_var["name"], "SEMAPHORE_GIT_")
    end)
    |> Enum.map(fn %{"name" => name, "value" => value} ->
      %{"name" => name, "value" => Base.decode64!(value)}
    end)
  end

  # Jobs before 2019-04-30 had a different structure.
  def request_git_vars(%{"environment_variables" => env_vars}) do
    env_vars
    |> Enum.filter(fn env_var ->
      String.starts_with?(env_var["name"], "SEMAPHORE_GIT_")
    end)
    |> Enum.map(fn %{"name" => name, "unencrypted_content" => value} ->
      %{"name" => name, "value" => Base.decode64!(value)}
    end)
  end

  def request_git_vars(_), do: []
end
