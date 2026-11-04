defmodule Zebra.Models.JobStopRequestTest do
  use Zebra.DataCase

  alias Zebra.Models.JobStopRequest

  @build_id Ecto.UUID.generate()
  @job_id Ecto.UUID.generate()

  describe ".find_by_job_id" do
    test "when the record exists => returns the record" do
      {:ok, req} = JobStopRequest.create(@build_id, @job_id)

      assert {:ok, ^req} = JobStopRequest.find_by_job_id(@job_id)
    end

    test "when the record exists => returns an error" do
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(@job_id)
    end
  end

  describe ".create" do
    test "it sets created_at and updated_at" do
      {:ok, req} = JobStopRequest.create(@build_id, @job_id)

      assert req.created_at != nil
      assert req.updated_at != nil

      assert req.created_at == req.updated_at
    end
  end

  describe ".bulk_create" do
    test "when there are no conflicting recorgs => creates all the entries" do
      # tuples of {task_id, job_id}
      tuples = [
        {Ecto.UUID.generate(), Ecto.UUID.generate()},
        {Ecto.UUID.generate(), Ecto.UUID.generate()},
        {Ecto.UUID.generate(), Ecto.UUID.generate()}
      ]

      assert {:ok, 3} = JobStopRequest.bulk_create(tuples)

      tuples
      |> Enum.each(fn {task_id, job_id} ->
        assert {:ok, stop_request} = JobStopRequest.find_by_job_id(job_id)
        assert stop_request.build_id == task_id
      end)
    end

    test "when there are no conflicting recorgs => ignores conflicts" do
      # tuples of {task_id, job_id}
      tuples = [
        {Ecto.UUID.generate(), Ecto.UUID.generate()},
        {Ecto.UUID.generate(), Ecto.UUID.generate()}
      ]

      assert {:ok, 2} = JobStopRequest.bulk_create(tuples)

      tuples =
        tuples ++
          [
            {Ecto.UUID.generate(), Ecto.UUID.generate()}
          ]

      assert {:ok, 1} = JobStopRequest.bulk_create(tuples)

      tuples
      |> Enum.each(fn {task_id, job_id} ->
        assert {:ok, stop_request} = JobStopRequest.find_by_job_id(job_id)
        assert stop_request.build_id == task_id
      end)
    end
  end

  describe ".bulk_create at the Postgres bind parameter limit" do
    # 6 parameters per row: 10,922 rows fit in 65,535 parameters, 10,923 do not.
    for count <- [10_922, 10_923, 25_000] do
      test "inserts #{count} rows" do
        tuples = uuid_tuples(unquote(count))

        assert {:ok, unquote(count)} = JobStopRequest.bulk_create(tuples)
        assert stop_request_count() == unquote(count)
      end
    end

    test "ignores conflicts that land in a later chunk" do
      chunk = JobStopRequest.bulk_create_chunk_size()
      existing = uuid_tuples(10)

      assert {:ok, 10} = JobStopRequest.bulk_create(existing)

      tuples = uuid_tuples(chunk) ++ existing ++ uuid_tuples(chunk)

      assert {:ok, inserted} = JobStopRequest.bulk_create(tuples)
      assert inserted == 2 * chunk
      assert stop_request_count() == 2 * chunk + 10
    end

    test "a failing chunk rolls back the chunks inserted before it" do
      chunk = JobStopRequest.bulk_create_chunk_size()
      tuples = uuid_tuples(chunk) ++ [{Ecto.UUID.generate(), "not-a-uuid"}]

      assert_raise Ecto.ChangeError, fn -> JobStopRequest.bulk_create(tuples) end
      assert stop_request_count() == 0
    end
  end

  defp uuid_tuples(count) do
    Enum.map(1..count, fn _ -> {Ecto.UUID.generate(), Ecto.UUID.generate()} end)
  end

  defp stop_request_count, do: Zebra.LegacyRepo.aggregate(JobStopRequest, :count)

  describe ".update" do
    test "it updates updated_at" do
      {:ok, req} = JobStopRequest.create(@build_id, @job_id)

      :timer.sleep(1000)

      old_updated_at = req.updated_at

      {:ok, req} = req |> JobStopRequest.update()

      new_updated_at = req.updated_at

      assert DateTime.compare(old_updated_at, new_updated_at) == :lt
    end

    test "it updates the fields" do
      {:ok, req} = Zebra.Models.JobStopRequest.create(@build_id, @job_id)
      assert req.result != "success"

      {:ok, req} = req |> JobStopRequest.update(%{result: "success"})

      assert req.result == "success"
    end
  end

  describe ".complete" do
    test "it sets the result" do
      {:ok, req} = JobStopRequest.create(@build_id, @job_id)
      assert req.result != "failed"

      {:ok, req} =
        JobStopRequest.complete(
          req,
          JobStopRequest.result_failure(),
          JobStopRequest.result_reason_job_already_finished()
        )

      assert req.state == "done"
      assert req.result == "failure"
      assert req.result_reason == JobStopRequest.result_reason_job_already_finished()
      assert req.done_at != nil
    end
  end
end
