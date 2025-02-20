defmodule Zebra.Workers.Agent.HostedAgentTest do
  use Zebra.DataCase

  alias Zebra.Workers.Agent.HostedAgent, as: Agent
  alias Zebra.Models.Job
  alias InternalApi.Chmura.Chmura.Stub

  import Mock

  @agent_id Ecto.UUID.generate()

  describe ".send" do
    test "response is 401 signature error" do
      host = "1.2.3.4"
      response = %HTTPoison.Response{body: "signature is invalid", status_code: 401}

      with_mock HTTPoison, post: fn _, _, _, _ -> {:ok, response} end do
        with_mock Watchman, increment: fn _ -> nil end do
          Zebra.Models.Agent.send(host, 1000, "aa", "/job", "fake-payload")

          assert_called(
            Watchman.increment({"agent.send.error", ["401_invalid_signature", "1-2-3-4"]})
          )
        end
      end
    end
  end

  describe ".occupy" do
    test "returns occupied agent => when there is available one" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      request = %InternalApi.Chmura.OccupyAgentRequest{
        request_id: job.id
      }

      response = %InternalApi.Chmura.OccupyAgentResponse{
        agent: %InternalApi.Chmura.Agent{
          id: @agent_id
        }
      }

      with_mock Stub, occupy_agent: fn _, _, _ -> {:ok, response} end do
        assert Agent.occupy(job) == {:ok, Agent.construct_agent(response)}
      end
    end

    test "returns nil => when there is no available agents" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      error = %GRPC.RPCError{message: "Something is really bad", status: 13}

      with_mock Stub, occupy_agent: fn _, _, _ -> {:error, error} end do
        assert Agent.occupy(job) == {:error, error.message}
      end
    end
  end

  describe ".release" do
    test "on success => returns :ok" do
      {:ok, job} = Support.Factories.Job.create(:finished)

      GrpcMock.stub(Support.FakeServers.ChmuraApi, :release_agent, fn _, _ ->
        %InternalApi.Chmura.ReleaseAgentResponse{}
      end)

      assert Agent.release(job) == :ok
    end

    test "on server failure => returns :erorr" do
      {:ok, job} = Support.Factories.Job.create(:finished)

      GrpcMock.stub(Support.FakeServers.ChmuraApi, :release_agent, fn _, _ ->
        raise "muhahah"
      end)

      assert Agent.release(job) == {:error, "Internal Server Error"}
    end
  end

  describe ".construct_agent" do
    test "extracts Agent from response" do
      response = %InternalApi.Chmura.OccupyAgentResponse{
        agent: %InternalApi.Chmura.Agent{
          id: @agent_id
        }
      }

      assert Agent.construct_agent(response) == %Agent{
               id: @agent_id,
               auth_token: ""
             }
    end
  end
end
