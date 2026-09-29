defmodule Zebra.Apis.InternalTaskApi.SerializerTest do
  use Zebra.DataCase

  alias Zebra.Apis.InternalTaskApi.Serializer
  alias Google.Protobuf.Timestamp
  alias Support.Factories

  describe ".serialize" do
    test "task serialization" do
      {:ok, task} = Factories.Task.create_with_jobs()

      reply = Serializer.serialize(task)

      assert reply.id == task.id
      assert reply.state == InternalApi.Task.Task.State.value(:RUNNING)
      assert reply.ppl_id == task.ppl_id
      assert reply.wf_id == task.workflow_id
      assert reply.request_token == task.build_request_id

      task = Zebra.LegacyRepo.preload(task, [:jobs])

      assert reply.jobs == [
               InternalApi.Task.Task.Job.new(
                 id: Enum.at(task.jobs, 0).id,
                 index: 0,
                 priority: 50,
                 name: "RSpec 1/3",
                 state: InternalApi.Task.Task.Job.State.value(:RUNNING),
                 created_at: %Timestamp{seconds: Factories.Job.timestamp(), nanos: 0},
                 enqueued_at: %Timestamp{seconds: Factories.Job.timestamp(), nanos: 0},
                 scheduled_at: %Timestamp{seconds: Factories.Job.timestamp(), nanos: 0},
                 started_at: %Timestamp{seconds: Factories.Job.timestamp(), nanos: 0}
               ),
               InternalApi.Task.Task.Job.new(
                 id: Enum.at(task.jobs, 1).id,
                 index: 0,
                 priority: 50,
                 name: "RSpec 1/3",
                 state: InternalApi.Task.Task.Job.State.value(:RUNNING),
                 created_at: %Timestamp{seconds: Factories.Job.timestamp(), nanos: 0},
                 enqueued_at: %Timestamp{seconds: Factories.Job.timestamp(), nanos: 0},
                 scheduled_at: %Timestamp{seconds: Factories.Job.timestamp(), nanos: 0},
                 started_at: %Timestamp{seconds: Factories.Job.timestamp(), nanos: 0}
               )
             ]

      refute is_nil(reply.created_at)
      assert is_nil(reply.finished_at)
    end

    test "when the task is finished => returns finished_at = nil" do
      {:ok, task} = Support.Factories.Task.create()

      reply = Serializer.serialize(task)

      assert reply.finished_at == nil
    end

    test "when the task is not finished => returns finished_at = updated_at" do
      {:ok, task} = Support.Factories.Task.create(%{result: "passed"})

      reply = Serializer.serialize(task)

      assert reply.finished_at == %Timestamp{
               seconds: DateTime.to_unix(task.updated_at),
               nanos: 0
             }
    end
  end

  describe ".serialize_job" do
    test "job serialization" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{priority: 75})

      assert Serializer.serialize_job(job) ==
               InternalApi.Task.Task.Job.new(
                 id: job.id,
                 state: InternalApi.Task.Task.Job.State.value(:ENQUEUED),
                 name: job.name,
                 index: job.index,
                 priority: 75,
                 created_at: %Timestamp{seconds: Factories.Job.timestamp(), nanos: 0}
               )
    end
  end

  describe ".serialize_job with original_job_id (Describe lineage exposure)" do
    test "a copy row serializes original_job_id equal to the original id" do
      original_id = Ecto.UUID.generate()

      {:ok, copy} =
        Support.Factories.Job.create(:finished, %{
          original_job_id: original_id,
          result: "passed"
        })

      serialized = Serializer.serialize_job(copy)

      assert serialized.original_job_id == original_id
    end

    test "a normal job serializes with original_job_id absent (backward compatible)" do
      {:ok, job} = Support.Factories.Job.create(:pending)

      serialized = Serializer.serialize_job(job)

      # nil marker drops out via remove_nils_from_keywordlist, leaving the
      # proto default for non-copy jobs — existing consumers see no change.
      assert serialized.original_job_id in [nil, ""]
    end

    test "top-level serialize/1 loads original_job_id for copy jobs" do
      original_id = Ecto.UUID.generate()
      {:ok, task} = Support.Factories.Task.create()

      {:ok, _copy} =
        Support.Factories.Job.create(:finished, %{
          build_id: task.id,
          original_job_id: original_id,
          result: "passed"
        })

      reply = Serializer.serialize(task)

      assert [job] = reply.jobs
      assert job.original_job_id == original_id
    end
  end
end
