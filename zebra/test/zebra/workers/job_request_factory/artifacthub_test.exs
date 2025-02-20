defmodule Zebra.Workers.JobRequestFactory.ArtifacthubTest do
  use Zebra.DataCase

  alias Zebra.Workers.JobRequestFactory.Artifacthub
  alias Zebra.Workers.JobRequestFactory.JobRequest

  @token "asdfg"
  @artifact_id Ecto.UUID.generate()
  @job_id Ecto.UUID.generate()
  @project_id Ecto.UUID.generate()
  @job_spec %{
    env_vars: [
      %{name: "SEMAPHORE_WORKFLOW_ID", value: Ecto.UUID.generate()}
    ]
  }

  describe ".generate_token" do
    setup do
      GrpcMock.stub(Support.FakeServers.ArtifactApi, :generate_token, fn _, _ ->
        %InternalApi.Artifacthub.GenerateTokenResponse{
          token: @token
        }
      end)

      :ok
    end

    test "on nil, empty artifact storage => returns stop_job_processing" do
      assert Artifacthub.generate_token(nil, @job_id, @project_id, @job_spec) ==
               {:stop_job_processing, "Job is missing artifact storage"}

      assert Artifacthub.generate_token("", @job_id, @project_id, @job_spec) ==
               {:stop_job_processing, "Job is missing artifact storage"}
    end

    test "on valid storage ID => returns env var" do
      assert {:ok, vars} =
               Artifacthub.generate_token(@artifact_id, @job_id, @project_id, @job_spec)

      assert vars == [
               JobRequest.env_var("SEMAPHORE_ARTIFACT_TOKEN", @token)
             ]
    end

    test "error communicating with API => returns communication_error" do
      GrpcMock.stub(Support.FakeServers.ArtifactApi, :generate_token, fn _, _ ->
        raise "i refuse to return"
      end)

      assert {:error, :communication_error} ==
               Artifacthub.generate_token(@artifact_id, @job_id, @project_id, @job_spec)
    end
  end
end
