defmodule Zebra.Models.Job do
  use Ecto.Schema

  alias Zebra.LegacyRepo
  alias Zebra.Workers.JobRequestFactory.JobRequest

  import Ecto.Changeset

  require Ecto.Query
  alias Ecto.Query, as: Q

  require Logger

  def state_pending, do: "pending"
  def state_enqueued, do: "enqueued"
  def state_scheduled, do: "scheduled"
  def state_waiting_for_agent, do: "waiting-for-agent"
  def state_started, do: "started"
  def state_finished, do: "finished"

  def result_passed, do: "passed"
  def result_failed, do: "failed"
  def result_stopped, do: "stopped"

  def valid_states,
    do: [
      state_pending(),
      state_enqueued(),
      state_scheduled(),
      state_waiting_for_agent(),
      state_started(),
      state_finished()
    ]

  def valid_results,
    do: [
      nil,
      result_passed(),
      result_failed(),
      result_stopped()
    ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @required_fields ~w(name organization_id project_id aasm_state created_at updated_at machine_type spec)a
  @optional_fields ~w(build_id priority execution_time_limit deployment_target_id repository_id enqueued_at scheduled_at started_at finished_at request index port name machine_os_image failure_reason result agent_id agent_name agent_ip_address agent_ctrl_port agent_auth_token private_ssh_key)a

  schema "jobs" do
    belongs_to(:task, Zebra.Models.Task, foreign_key: :build_id)
    has_one(:job_stop_request, Zebra.Models.JobStopRequest)
    has_one(:debug, Zebra.Models.Debug)

    field(:name, :string)
    field(:failure_reason, :string)
    field(:index, :integer)
    field(:port, :integer)
    field(:aasm_state, :string)
    field(:result, :string)
    field(:spec, :map)
    field(:machine_type, :string)
    field(:machine_os_image, :string, default: "")
    field(:request, :map)
    field(:organization_id, :binary_id)
    field(:project_id, :binary_id)
    field(:deployment_target_id, :binary_id)
    field(:repository_id, :binary_id)
    field(:agent_id, :binary_id)
    field(:agent_name, :string, default: "")
    field(:agent_ctrl_port, :integer)
    field(:agent_ip_address, :string)
    field(:agent_auth_token, :string)
    field(:private_ssh_key, :string)
    field(:execution_time_limit, :integer, default: 24 * 60 * 60)
    field(:priority, :integer)

    field(:created_at, :utc_datetime)
    field(:updated_at, :utc_datetime)
    field(:enqueued_at, :utc_datetime)
    field(:scheduled_at, :utc_datetime)
    field(:started_at, :utc_datetime)
    field(:finished_at, :utc_datetime)
    field(:expires_at, :utc_datetime)
  end

  def create(params) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    params =
      params
      |> Map.new()
      |> Map.merge(%{
        aasm_state: state_pending(),
        created_at: now,
        updated_at: now
      })

    params = %{params | spec: encode_spec(params.spec)}
    params = set_machine_type_if_empty(params)

    changeset(%__MODULE__{}, params)
    |> LegacyRepo.insert()
    |> case do
      {:ok, job} ->
        {:ok, job}

      {:error, changeset} ->
        {:error, readable_changeset_errors(changeset)}
    end
  end

  def update(job, params \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    params = params |> Map.merge(%{updated_at: now})

    changeset(job, params)
    |> LegacyRepo.update()
    |> case do
      {:ok, job} ->
        {:ok, job}

      {:error, changeset} ->
        {:error, readable_changeset_errors(changeset)}
    end
  end

  defp readable_changeset_errors(changeset) do
    Enum.map_join(changeset.errors, ", ", fn {field, {msg, _}} -> "#{field}: #{msg}" end)
  end

  defp set_machine_type_if_empty(params) do
    if Map.get(params, :machine_os_image, "") in ["", nil] do
      case Zebra.Machines.default_os_image(params.organization_id, params.machine_type) do
        {:ok, os_image} ->
          Map.merge(params, %{machine_os_image: os_image})

        {:error, _} ->
          # JobRequestFactory will kill it
          Map.merge(params, %{machine_os_image: ""})
      end
    else
      params
    end
  end

  def pending?(job), do: job.aasm_state == state_pending()
  def enqueued?(job), do: job.aasm_state == state_enqueued()
  def scheduled?(job), do: job.aasm_state == state_scheduled()
  def waiting_for_agent?(job), do: job.aasm_state == state_waiting_for_agent()
  def started?(job), do: job.aasm_state == state_started()
  def finished?(job), do: job.aasm_state == state_finished()

  def passed?(job), do: job.result == result_passed()
  def failed?(job), do: job.result == result_failed()
  def stopped?(job), do: job.result == result_stopped()
  def no_result?(job), do: job.result == nil

  ## Scopes

  def running(query \\ __MODULE__) do
    query |> Q.where([j], is_nil(j.result))
  end

  def scheduled_running(query \\ __MODULE__) do
    query
    |> Q.where(
      [j],
      j.aasm_state == "scheduled" or
        j.aasm_state == "started"
    )
  end

  def pending(query \\ __MODULE__) do
    query |> Q.where([j], j.aasm_state == ^state_pending())
  end

  def enqueued(query \\ __MODULE__) do
    query |> Q.where([j], j.aasm_state == ^state_enqueued())
  end

  def scheduled(query \\ __MODULE__) do
    query |> Q.where([j], j.aasm_state == ^state_scheduled())
  end

  def waiting_for_agent(query \\ __MODULE__) do
    query |> Q.where([j], j.aasm_state == ^state_waiting_for_agent())
  end

  def cloud_scheduled(query \\ __MODULE__) do
    query
    |> Q.where([j], j.aasm_state == ^state_scheduled())
    |> Q.where([j], not like(j.machine_type, "s1-%"))
  end

  def cloud_scheduled_per_machine_type(query \\ __MODULE__) do
    query
    |> Q.where([j], j.aasm_state == ^state_scheduled())
    |> Q.where([j], not like(j.machine_type, "s1-%"))
    |> Q.group_by([j], j.machine_type)
    |> Q.select([j], %{
      machine_type: j.machine_type,
      count: count(j.id)
    })
  end

  def self_hosted_scheduled(query \\ __MODULE__) do
    query
    |> Q.where([j], j.aasm_state == ^state_scheduled())
    |> Q.where([j], like(j.machine_type, "s1-%"))
  end

  def started(query \\ __MODULE__) do
    query |> Q.where([j], j.aasm_state == ^state_started())
  end

  def cloud_started(query \\ __MODULE__) do
    query
    |> Q.where([j], j.aasm_state == ^state_started())
    |> Q.where([j], not like(j.machine_type, "s1-%"))
  end

  def self_hosted_started(query \\ __MODULE__) do
    query
    |> Q.where([j], j.aasm_state == ^state_started())
    |> Q.where([j], like(j.machine_type, "s1-%"))
  end

  def finished(query \\ __MODULE__) do
    query |> Q.where([j], j.aasm_state == ^state_finished())
  end

  ##
  ## Transitions
  ##

  # credo:disable-for-next-line
  def valid_transition?(old, new) do
    cond do
      old == state_pending() && new == state_enqueued() -> true
      old == state_pending() && new == state_finished() -> true
      old == state_enqueued() && new == state_scheduled() -> true
      old == state_enqueued() && new == state_finished() -> true
      old == state_scheduled() && new == state_waiting_for_agent() -> true
      old == state_scheduled() && new == state_started() -> true
      old == state_scheduled() && new == state_finished() -> true
      old == state_waiting_for_agent() && new == state_started() -> true
      old == state_waiting_for_agent() && new == state_finished() -> true
      old == state_started() && new == state_finished() -> true
      true -> false
    end
  end

  def enqueue(job, request, rsa) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    if valid_transition?(job.aasm_state, state_enqueued()) do
      res =
        update(job, %{
          aasm_state: state_enqueued(),
          enqueued_at: now,
          private_ssh_key: if(rsa != nil, do: rsa.private_key, else: nil),
          request: request
        })

      Zebra.Workers.Scheduler.lock_and_process_async(job.organization_id)

      res
    else
      {:error, :invalid_transition}
    end
  end

  def force_finish(job, reason) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, job} =
      update(job, %{
        aasm_state: state_finished(),
        finished_at: now,
        result: result_failed(),
        failure_reason: reason
      })

    optimisticaly_finish_task(job)

    Zebra.Workers.Scheduler.lock_and_process_async(job.organization_id)

    {:ok, job}
  end

  def bulk_force_finish([], _), do: []

  def bulk_force_finish(job_ids, reason) do
    import Ecto.Query, only: [select: 2, where: 3]

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Zebra.Models.Job
    |> select([
      :id,
      :name,
      :project_id,
      :organization_id,
      :created_at,
      :machine_type,
      :spec,
      :request
    ])
    |> where([j], j.id in ^job_ids)
    |> Zebra.LegacyRepo.all()
    |> Enum.each(fn j ->
      params = %{
        aasm_state: state_finished(),
        updated_at: now,
        finished_at: now,
        result: result_failed(),
        failure_reason: reason,
        request: JobRequest.sanitize(j.request)
      }

      case update(j, params) do
        {:ok, _} ->
          Logger.info("Forcefully finished #{j.id}")

        e ->
          Logger.info("Error while forcefully finishing #{j.id}: #{inspect(e)}")
      end
    end)
  end

  def schedule(job) do
    if enqueued?(job) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      update(job, %{
        aasm_state: state_scheduled(),
        scheduled_at: now
      })
    else
      {:error, :invalid_transition}
    end
  end

  def bulk_schedule([]), do: []

  def bulk_schedule(job_ids) do
    import Ecto.Query, only: [from: 2]

    query = from(j in Zebra.Models.Job, where: j.id in ^job_ids)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Zebra.LegacyRepo.update_all(query,
      set: [
        aasm_state: state_scheduled(),
        updated_at: now,
        scheduled_at: now
      ]
    )
  end

  def mark_jobs_for_deletion(org_id, cutoff_date, deletion_days) do
    import Ecto.Query, only: [from: 2]

    query =
      from(j in Zebra.Models.Job,
        where:
          is_nil(j.expires_at) and
            j.organization_id == ^org_id and
            j.created_at <= ^cutoff_date,
        update: [
          set: [
            expires_at: fragment("CURRENT_TIMESTAMP + (? * INTERVAL '1 day')", ^deletion_days)
          ]
        ]
      )

    Zebra.LegacyRepo.update_all(query, [])
  end

  def delete_old_job_stop_requests(limit) do
    import Ecto.Query,
      only: [from: 2, where: 3, subquery: 1, limit: 2, order_by: 2]

    jobs_subquery =
      from(j in Zebra.Models.Job,
        where: not is_nil(j.expires_at) and j.expires_at <= fragment("CURRENT_TIMESTAMP"),
        order_by: [asc: j.created_at],
        limit: ^limit,
        select: j.id
      )

    query =
      from(jsr in Zebra.Models.JobStopRequest,
        where: jsr.job_id in subquery(jobs_subquery)
      )

    {deleted_count, _} = Zebra.LegacyRepo.delete_all(query)

    {:ok, deleted_count}
  end

  def delete_old_jobs(limit) do
    import Ecto.Query, only: [from: 2, subquery: 1]

    jobs_subquery =
      from(j in Zebra.Models.Job,
        where: not is_nil(j.expires_at) and j.expires_at <= fragment("CURRENT_TIMESTAMP"),
        order_by: [asc: j.created_at],
        limit: ^limit,
        select: j.id
      )

    query =
      from(j in Zebra.Models.Job,
        where: j.id in subquery(jobs_subquery)
      )

    {deleted_count, _} = Zebra.LegacyRepo.delete_all(query)

    {:ok, deleted_count}
  end

  def wait_for_agent(job) do
    if valid_transition?(job.aasm_state, state_waiting_for_agent()) do
      update(job, %{aasm_state: state_waiting_for_agent()})
    else
      {:error, :invalid_transition}
    end
  end

  def start(job, agent, options \\ []) do
    defaults = [sanitize_request: false]
    options = Keyword.merge(defaults, options)

    if valid_transition?(job.aasm_state, state_started()) do
      update(job, start_params(job, agent, Keyword.get(options, :sanitize_request)))
    else
      {:error, :invalid_transition}
    end
  end

  defp start_params(_job, agent, _sanitize_request? = false) do
    %{
      aasm_state: state_started(),
      started_at: DateTime.truncate(DateTime.utc_now(), :second),
      agent_id: agent.id,
      agent_name: agent.name,
      agent_ip_address: agent.ip_address,
      port: agent.ssh_port,
      agent_ctrl_port: agent.ctrl_port,
      agent_auth_token: agent.auth_token
    }
  end

  defp start_params(job, agent, _sanitize_request? = true) do
    %{
      aasm_state: state_started(),
      started_at: DateTime.truncate(DateTime.utc_now(), :second),
      agent_id: agent.id,
      agent_name: agent.name,
      agent_ip_address: agent.ip_address,
      port: agent.ssh_port,
      agent_ctrl_port: agent.ctrl_port,
      agent_auth_token: agent.auth_token,
      request: JobRequest.sanitize(job.request)
    }
  end

  def sanitize_job_request(job_id) do
    case find(job_id) do
      {:ok, job} ->
        if !JobRequest.sanitized?(job.request) do
          update(job, %{
            request: JobRequest.sanitize(job.request)
          })
        end

      {:error, :not_found} ->
        Logger.error("Error sanitizing '#{job_id}': not found")
    end
  end

  def finish(job, result) do
    if result == nil do
      {:error, :result_cant_be_nil}
    else
      if valid_transition?(job.aasm_state, state_finished()) do
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        params = %{
          aasm_state: state_finished(),
          finished_at: now,
          result: result
        }

        case update(job, params) do
          {:ok, job} ->
            optimisticaly_finish_task(job)

            Zebra.Workers.Scheduler.lock_and_process_async(job.organization_id)

            :ok = publish_finished_event(job)
            {:ok, job}

          e ->
            e
        end
      else
        {:error, :invalid_transition}
      end
    end
  end

  def stop(job) do
    if valid_transition?(job.aasm_state, state_finished()) do
      Logger.info("Stopping job '#{job.id}'")

      if hosted?(job.machine_type), do: stop_hosted_job(job)
      if self_hosted?(job.machine_type), do: stop_self_hosted_job(job)

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      params = %{
        aasm_state: state_finished(),
        finished_at: now,
        result: result_stopped(),
        request: JobRequest.sanitize(job.request),
        machine_type: job.machine_type || ""
      }

      case update(job, params) do
        {:ok, job} ->
          optimisticaly_finish_task(job)
          :ok = publish_finished_event(job)

          Zebra.Workers.Scheduler.lock_and_process_async(job.organization_id)

          {:ok, job}

        e ->
          e
      end
    else
      {:error, :invalid_transition}
    end
  end

  def stop_hosted_job(job) do
    # Ideally, this would be async
    if job.agent_ip_address do
      host = job.agent_ip_address
      port = job.agent_ctrl_port
      token = job.agent_auth_token
      body = Poison.encode!(%{"job_hash_id" => job.id})

      Logger.info("Sending terminate request to the agent job_id:'#{job.id}'")
      Zebra.Workers.Agent.HostedAgent.send(host, port, token, "/jobs/terminate", body)
    end
  end

  def stop_self_hosted_job(job) do
    Zebra.Workers.Agent.SelfHostedAgent.stop(job)
  end

  def publish_finished_event(job) do
    publish_event(job, "job_finished", job.finished_at)
  end

  def publish_teardown_finished_event(job) do
    publish_event(job, "job_teardown_finished", DateTime.utc_now())
  end

  def publish_event(job, routing_key, finished_at) do
    mod = InternalApi.ServerFarm.MQ.JobStateExchange.JobFinished

    timestamp = Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(finished_at))

    message =
      mod.new(job_id: job.id, timestamp: timestamp, self_hosted: self_hosted?(job.machine_type))
      |> mod.encode

    exchange_name = "server_farm.job_state_exchange"
    {:ok, channel} = AMQP.Application.get_channel(:job_finisher)

    Tackle.Exchange.create(channel, exchange_name)
    :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)
  end

  ##
  ## Lookup
  ##

  def find(id) do
    case Zebra.LegacyRepo.get(__MODULE__, id) do
      nil -> {:error, :not_found}
      job -> {:ok, job}
    end
  end

  def reload(job) do
    LegacyRepo.get(__MODULE__, job.id)
  end

  def self_hosted?(machine_type) when is_bitstring(machine_type) do
    String.slice(machine_type, 0..1) == "s1"
  end

  def self_hosted?(_), do: false

  def hosted?(machine_type) when is_bitstring(machine_type) do
    String.slice(machine_type, 0..1) != "s1"
  end

  def hosted?(_), do: false

  #
  # Helpers
  #

  def changeset(job, params \\ %{}) do
    job
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:aasm_state, valid_states())
    |> validate_inclusion(:result, valid_results())
  end

  def encode_spec(spec) do
    spec |> Poison.encode!() |> Poison.decode!()
  end

  def decode_spec(spec) do
    Util.Proto.deep_new!(Semaphore.Jobs.V1alpha.Job.Spec, spec, string_keys_to_atoms: true)
  end

  def optimisticaly_finish_task(job) do
    # Trigger a task finishing check immediately after finishing the job.
    if job.build_id != nil do
      Zebra.Workers.TaskFinisher.lock_and_process(job.build_id)
    end
  end

  def detect_type(job) do
    alias Zebra.Models.Debug

    case job.build_id do
      nil ->
        case Debug.find_by_job_id(job.id) do
          {:error, :not_found} -> :project_debug_job
          {:ok, %{debugged_type: "job"}} -> :debug_job
          {:ok, %{debugged_type: "project"}} -> :project_debug_job
        end

      _ ->
        :pipeline_job
    end
  end
end
