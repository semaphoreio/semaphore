defmodule Front.Models.TaskTest do
  use FrontWeb.ConnCase

  alias Front.Models

  describe ".find_many" do
    test "returns tasks => when API returns response" do
      GrpcMock.stub(TaskMock, :describe_many, fn _, _ ->
        InternalApi.Task.DescribeManyResponse.new(
          tasks: [
            InternalApi.Task.Task.new(),
            InternalApi.Task.Task.new()
          ]
        )
      end)

      assert Models.Task.describe_many([]) ==
               [
                 InternalApi.Task.Task.new(),
                 InternalApi.Task.Task.new()
               ]
               |> Models.Task.atomify_enums()
    end

    test "returns error tuple => when API returns GRPC error" do
      error = %GRPC.RPCError{
        message: "upstream connect error or disconnect/reset before headers",
        status: 14
      }

      GrpcMock.stub(TaskMock, :describe_many, fn _, _ -> raise error end)

      assert Models.Task.describe_many([]) == {:error, error}
    end
  end

  describe ".waiting_to_start?" do
    def create_tasks(longest_waiting_secs) do
      now = DateTime.utc_now() |> DateTime.to_unix()

      running_job =
        InternalApi.Task.Task.Job.new(
          state: InternalApi.Task.Task.Job.State.value(:RUNNING),
          enqueued_at: Google.Protobuf.Timestamp.new(seconds: now - 80)
        )

      waiting_short =
        InternalApi.Task.Task.Job.new(
          state: InternalApi.Task.Task.Job.State.value(:ENQUEUED),
          enqueued_at: Google.Protobuf.Timestamp.new(seconds: now - 1)
        )

      waiting_long =
        InternalApi.Task.Task.Job.new(
          state: InternalApi.Task.Task.Job.State.value(:ENQUEUED),
          enqueued_at: Google.Protobuf.Timestamp.new(seconds: now - longest_waiting_secs)
        )

      [
        InternalApi.Task.Task.new(jobs: [running_job, waiting_short]),
        InternalApi.Task.Task.new(jobs: [waiting_long])
      ]
      |> Front.Models.Task.atomify_enums()
    end

    test "waiting time is bigger than treshold => return true" do
      tasks = create_tasks(200)

      assert Front.Models.Task.waiting_to_start?(tasks, treshold: 10)
    end

    test "waiting time is less than treshold => return false" do
      tasks = create_tasks(5)

      refute Front.Models.Task.waiting_to_start?(tasks, treshold: 10)
    end

    test "no running tasks => return false" do
      tasks = []

      refute Front.Models.Task.waiting_to_start?(tasks, treshold: 10)
    end
  end
end
