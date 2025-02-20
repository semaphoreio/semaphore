defmodule Zebra.Workers.JobTeardownCallbackWorkerTest do
  use Zebra.DataCase

  alias Zebra.Workers.JobTeardownCallbackWorker, as: W
  alias Support.FakeServers.ChmuraApi, as: Chmura

  describe ".handle_message" do
    test "when the job is present in the db => tries to release agent" do
      GrpcMock.stub(Chmura, :release_agent, fn _, _ ->
        %InternalApi.Chmura.ReleaseAgentResponse{}
      end)

      {:ok, j} = Support.Factories.Job.create(:finished)

      callback_message = %{"job_hash_id" => j.id} |> Poison.encode!()

      assert :ok = W.handle_message(callback_message)
    end

    test "when the job is present in the db => tries to release agent => fails" do
      GrpcMock.stub(Chmura, :release_agent, fn _, _ ->
        raise "muhahaha"
      end)

      {:ok, j} = Support.Factories.Job.create(:finished)

      callback_message = %{"job_hash_id" => j.id} |> Poison.encode!()

      assert_raise RuntimeError, fn -> W.handle_message(callback_message) end
    end

    test "when the container is not present in the DB => does nothing" do
      job_id = Ecto.UUID.generate()
      callback_message = %{"job_hash_id" => job_id} |> Poison.encode!()

      # raises no exception
      W.handle_message(callback_message)
    end
  end
end
