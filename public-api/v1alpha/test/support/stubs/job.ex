defmodule Support.Stubs.Job do
  alias Support.Stubs.DB
  alias Google.Protobuf.Timestamp
  alias InternalApi.ServerFarm.Job.Job, as: JobGRPC
  alias Util.Proto

  require Logger

  def init do
    DB.add_table(:jobs, [:id, :api_model])

    __MODULE__.Grpc.init()
  end

  def create(ppl_id, build_request_id, params \\ []) do
    api_model = build_api_model(ppl_id, build_request_id, params)

    DB.insert(:jobs, %{
      id: api_model.id,
      api_model: api_model
    })
  end

  def build_api_model(ppl_id, build_request_id, params \\ []) do
    defaults = [
      id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      branch_id: UUID.uuid4(),
      hook_id: UUID.uuid4(),
      timeline: %{
        created_at: DateTime.utc_now(),
        enqueued_at: DateTime.utc_now(),
        started_at: DateTime.utc_now(),
        finished_at: DateTime.utc_now(),
        execution_started_at: DateTime.utc_now(),
        execution_finished_at: DateTime.utc_now()
      },
      state: "finished",
      result: "passed",
      build_server_ip: "192.168.0.1",
      ppl_id: ppl_id,
      name: "Unit tests",
      index: 0,
      failure_reason: "",
      machine_type: "e1-standard-2",
      machine_os_image: "ubuntu1804",
      agent_host: "",
      agent_ctrl_port: 0,
      agent_ssh_port: 0,
      agent_auth_token: "",
      priority: 50,
      is_debug_job: false,
      debug_user_id: "",
      self_hosted: false,
      organization_id: UUID.uuid4(),
      build_req_id: build_request_id,
      agent_name: ""
    ]

    params = defaults |> Keyword.merge(params)

    trasnformation_functions = %{
      Timestamp => {__MODULE__, :date_time_to_timestamps},
      JobGRPC.State => {__MODULE__, :string_to_enum_atom_or_0},
      JobGRPC.Result => {__MODULE__, :string_to_enum_atom_or_0}
    }

    Proto.deep_new!(JobGRPC, params, transformations: trasnformation_functions)
  end

  def date_time_to_timestamps(_field_name, nil), do: %{seconds: 0, nanos: 0}

  def date_time_to_timestamps(_field_name, date_time = %DateTime{}) do
    %{}
    |> Map.put(:seconds, DateTime.to_unix(date_time, :second))
    |> Map.put(:nanos, elem(date_time.microsecond, 0) * 1_000)
  end

  def date_time_to_timestamps(_field_name, value), do: value

  def string_to_enum_atom_or_0(_field_name, field_value)
      when is_binary(field_value) and field_value != "" do
    field_value |> String.upcase() |> String.to_atom()
  end

  def string_to_enum_atom_or_0(_field_name, _field_value), do: 0

  defmodule Grpc do
    alias Support.Stubs.DB

    def init do
      GrpcMock.stub(JobMock, :describe, &__MODULE__.describe/2)
    end

    def describe(req, _) do
      alias InternalApi.ServerFarm.Job.DescribeResponse

      case find(req) do
        {:ok, job} ->
          DescribeResponse.new(status: InternalApi.ResponseStatus.new(), job: job.api_model)

        {:error, nil} ->
          DescribeResponse.new(
            status:
              InternalApi.ResponseStatus.new(
                code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM),
                message: "Not found."
              ),
            job: nil
          )
      end
    end

    defp find(req) do
      case DB.find_by(:jobs, :id, req.job_id) do
        nil ->
          {:error, nil}

        job ->
          {:ok, job}
      end
    end
  end
end
