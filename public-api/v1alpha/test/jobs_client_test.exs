defmodule PipelinesAPI.JobsClient.Test do
  use ExUnit.Case
  use Plug.Test

  alias PipelinesAPI.JobsClient
  alias Support.Stubs.Job
  alias InternalApi.ServerFarm.Job.Job.{State, Result}
  alias Google.Protobuf.Timestamp
  alias Util.Proto

  @ppl_id UUID.uuid4()
  @build_request_id UUID.uuid4()

  setup do
    Support.Stubs.reset()
  end

  describe ".describe" do
    test "existing job" do
      job = Job.create(@ppl_id, @build_request_id)

      params = %{"job_id" => job.id}
      assert {:ok, response} = JobsClient.describe(params)

      tf_map = %{
        Timestamp => {__MODULE__, :timestamp_to_datetime_string},
        State => {__MODULE__, :enum_to_string},
        Result => {__MODULE__, :enum_to_string}
      }

      assert response == job.api_model |> Proto.to_map!(transformations: tf_map)
    end

    test "non-existing job" do
      params = %{"job_id" => UUID.uuid4()}

      assert {:error, {:not_found, "Not found."}} = JobsClient.describe(params)
    end
  end

  # Utility

  def timestamp_to_datetime_string(_name, %{nanos: 0, seconds: 0}), do: ""

  def timestamp_to_datetime_string(_name, %{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    DateTime.to_string(ts_date_time)
  end

  def enum_to_string(_name, value) when is_binary(value) do
    value |> Atom.to_string() |> String.downcase()
  end

  def enum_to_string(name, value) when is_integer(value) do
    atom =
      case name do
        :state -> State.key(value)
        :result -> Result.key(value)
      end

    atom |> Atom.to_string() |> String.downcase()
  end
end
