defmodule Zebra.Workers.FinishedJobCleanerTest do
  use Zebra.DataCase

  alias Zebra.LegacyRepo, as: Repo
  alias Zebra.Models.Job
  alias Zebra.Workers.FinishedJobCleaner, as: Cleaner

  @ssh_key "fake-debug-ssh-key"

  # DataCase truncates jobs between tests but not the cursor table
  setup do
    Repo.delete_all("job_cleanup_cursors")
    :ok
  end

  defp worker(overrides \\ []) do
    {:ok, worker} =
      Cleaner.build(
        Keyword.merge(
          [cutoff_days: 3, batch_size: 100, naptime: 1, longnaptime: 2],
          overrides
        )
      )

    worker
  end

  defp days_ago(days, extra_seconds \\ 0) do
    DateTime.utc_now()
    |> DateTime.add(-days * 86_400 - extra_seconds, :second)
    |> DateTime.truncate(:second)
  end

  defp finished_job(finished_at, params \\ %{}) do
    {:ok, job} =
      Support.Factories.Job.create(
        :finished,
        Map.merge(
          %{result: "passed", finished_at: finished_at, private_ssh_key: @ssh_key},
          params
        )
      )

    job
  end

  defp run_to_completion(worker, acc \\ %{scanned: 0, cleaned: 0, trimmed: 0, ticks: 0}) do
    {:ok, stats} = Cleaner.tick(worker)

    acc = %{
      scanned: acc.scanned + stats.scanned,
      cleaned: acc.cleaned + stats.cleaned,
      trimmed: acc.trimmed + stats.trimmed,
      ticks: acc.ticks + 1
    }

    if stats.scanned == 0, do: acc, else: run_to_completion(worker, acc)
  end

  describe ".tick" do
    test "clears credentials of jobs finished before the cutoff" do
      old = finished_job(days_ago(3, 60))
      older = finished_job(days_ago(200))

      assert {:ok, %{scanned: 2, cleaned: 2}} = Cleaner.tick(worker())

      for job <- [old, older] do
        reloaded = Job.reload(job)
        assert is_nil(reloaded.agent_auth_token)
        assert is_nil(reloaded.private_ssh_key)
        assert reloaded.aasm_state == "finished"
        assert reloaded.result == "passed"
      end
    end

    test "leaves jobs finished after the cutoff untouched" do
      recent = finished_job(days_ago(2))
      just_inside = finished_job(days_ago(3, -3600))

      assert {:ok, %{scanned: 0, cleaned: 0}} = Cleaner.tick(worker())

      for job <- [recent, just_inside] do
        reloaded = Job.reload(job)
        # post-job processing may still need the token
        assert reloaded.agent_auth_token == "lol"
        assert reloaded.private_ssh_key == @ssh_key
      end
    end

    test "never touches jobs that are not finished" do
      {:ok, running} = Support.Factories.Job.create(:started, %{private_ssh_key: @ssh_key})

      # a finished_at in the past on a job that is not finished must not matter either
      {:ok, odd} =
        Support.Factories.Job.create(:started, %{
          private_ssh_key: @ssh_key,
          finished_at: days_ago(10)
        })

      run_to_completion(worker())

      for job <- [running, odd] do
        reloaded = Job.reload(job)
        assert reloaded.agent_auth_token == "lol"
        assert reloaded.private_ssh_key == @ssh_key
      end
    end

    test "respects the batch size and resumes from its cursor" do
      jobs = for d <- 10..14, do: finished_job(days_ago(d))

      w = worker(batch_size: 2)

      assert {:ok, %{scanned: 2, cleaned: 2}} = Cleaner.tick(w)
      assert Enum.count(jobs, fn j -> is_nil(Job.reload(j).agent_auth_token) end) == 2

      # a fresh worker with the same config (a restart) continues where it stopped
      assert {:ok, %{scanned: 2, cleaned: 2}} = Cleaner.tick(worker(batch_size: 2))
      assert {:ok, %{scanned: 1, cleaned: 1}} = Cleaner.tick(w)
      assert {:ok, %{scanned: 0, cleaned: 0}} = Cleaner.tick(w)

      assert Enum.all?(jobs, fn j -> is_nil(Job.reload(j).agent_auth_token) end)
    end

    test "walks jobs that share a finished_at one by one" do
      finished_at = days_ago(20)
      jobs = for _ <- 1..3, do: finished_job(finished_at)

      assert %{scanned: 3, cleaned: 3, ticks: 4} = run_to_completion(worker(batch_size: 1))
      assert Enum.all?(jobs, fn j -> is_nil(Job.reload(j).private_ssh_key) end)
    end

    test "jobs crossing the cutoff later are picked up by the same cursor" do
      finished_job(days_ago(30))
      w = worker()

      assert %{cleaned: 1} = run_to_completion(w)

      later = finished_job(days_ago(2))
      assert %{cleaned: 0} = run_to_completion(w)
      assert Job.reload(later).agent_auth_token == "lol"

      # two days later the job is past the cutoff
      assert %{cleaned: 1} = run_to_completion(worker(cutoff_days: 1))
      assert is_nil(Job.reload(later).agent_auth_token)
    end

    test "a second full pass changes nothing" do
      for d <- 5..8, do: finished_job(days_ago(d))
      finished_job(days_ago(9), %{agent_auth_token: nil, private_ssh_key: nil})

      assert %{scanned: 5, cleaned: 4} = run_to_completion(worker())

      Repo.delete_all("job_cleanup_cursors")

      assert %{scanned: 5, cleaned: 0} = run_to_completion(worker())
    end

    test "separate cursors make separate passes" do
      finished_job(days_ago(5))

      assert %{scanned: 1} = run_to_completion(worker(cursor_name: "a"))
      assert %{scanned: 0} = run_to_completion(worker(cursor_name: "a"))
      assert %{scanned: 1, cleaned: 0} = run_to_completion(worker(cursor_name: "b"))
    end
  end

  describe ".tick request trimming" do
    alias Zebra.Workers.JobRequestFactory.JobRequest

    defp full_request do
      %{
        "commands" => ["make test"],
        "files" => [JobRequest.file("/home/semaphore/.npmrc", "{SANITIZED}", "0600")],
        "env_vars" => [
          JobRequest.env_var("SEMAPHORE_GIT_SHA", "4f3b2a1"),
          JobRequest.env_var("SEMAPHORE_JOB_ID", "job-id"),
          JobRequest.env_var("MY_SECRET", "{SANITIZED}", encode_to_base64: false)
        ]
      }
    end

    defp git_only_request do
      %{"env_vars" => [JobRequest.env_var("SEMAPHORE_GIT_SHA", "4f3b2a1")]}
    end

    test "reduces the request of jobs finished before the cutoff to their git env vars" do
      old = finished_job(days_ago(10), %{request: full_request()})

      assert {:ok, %{scanned: 1, trimmed: 1}} = Cleaner.tick(worker())

      assert Job.reload(old).request == git_only_request()
    end

    test "keeps the old request shape" do
      git_var = %{
        "name" => "SEMAPHORE_GIT_BRANCH",
        "unencrypted_content" => Base.encode64("main")
      }

      old =
        finished_job(days_ago(10), %{
          request: %{
            "commands" => ["x"],
            "environment_variables" => [
              git_var,
              %{"name" => "A", "unencrypted_content" => "Yg=="}
            ]
          }
        })

      run_to_completion(worker())

      assert Job.reload(old).request == %{"environment_variables" => [git_var]}
    end

    test "leaves the request of recent and running jobs untouched" do
      recent = finished_job(days_ago(2), %{request: full_request()})
      {:ok, running} = Support.Factories.Job.create(:started, %{request: full_request()})

      {:ok, odd} =
        Support.Factories.Job.create(:started, %{
          request: full_request(),
          finished_at: days_ago(9)
        })

      assert %{trimmed: 0} = run_to_completion(worker())

      for job <- [recent, running, odd] do
        assert Job.reload(job).request == full_request()
      end
    end

    test "a second full pass changes nothing" do
      for d <- 5..7, do: finished_job(days_ago(d), %{request: full_request()})
      finished_job(days_ago(8), %{request: nil})
      finished_job(days_ago(9), %{request: %{}})

      assert %{scanned: 5, trimmed: 3} = run_to_completion(worker())

      Repo.delete_all("job_cleanup_cursors")

      assert %{scanned: 5, cleaned: 0, trimmed: 0} = run_to_completion(worker())
    end

    test "respects the batch size" do
      for d <- 10..14, do: finished_job(days_ago(d), %{request: full_request()})

      assert {:ok, %{scanned: 2, trimmed: 2}} = Cleaner.tick(worker(batch_size: 2))
    end

    test "a row deleted by retention while the tick runs is skipped, the batch goes on" do
      first =
        finished_job(days_ago(10), %{
          request: full_request(),
          agent_auth_token: nil,
          private_ssh_key: nil
        })

      second =
        finished_job(days_ago(10), %{
          request: full_request(),
          agent_auth_token: nil,
          private_ssh_key: nil
        })

      victim = Enum.max_by([first, second], & &1.id)
      survivor = Enum.min_by([first, second], & &1.id)

      parent = self()

      # claims and deletes the row like JobDeletionPolicyWorker does, holding the
      # lock until after the cleaner has read the batch
      deleter =
        Task.async(fn ->
          Repo.transaction(fn ->
            Repo.query!("SELECT id FROM jobs WHERE id = $1 FOR UPDATE", [
              Ecto.UUID.dump!(victim.id)
            ])

            send(parent, :claimed)
            Process.sleep(1_000)
            Repo.query!("DELETE FROM jobs WHERE id = $1", [Ecto.UUID.dump!(victim.id)])
          end)
        end)

      assert_receive :claimed, 5_000

      assert {:ok, %{scanned: 2, trimmed: 1, trim_skipped: 0}} = Cleaner.tick(worker())
      Task.await(deleter, 10_000)

      assert Job.reload(survivor).request == git_only_request()
      assert {:error, :not_found} = Job.find(victim.id)

      # the cursor moved past both rows
      assert %{scanned: 0} = run_to_completion(worker())
    end

    test "does not trim when the git env vars served by the API would change" do
      git_var = %{
        "name" => "SEMAPHORE_GIT_BRANCH",
        "unencrypted_content" => Base.encode64("main")
      }

      # both keys: the API reads env_vars (no git vars here) and ignores the
      # legacy key, but the trim would keep only the legacy git var
      both = %{
        "commands" => ["x"],
        "env_vars" => [JobRequest.env_var("SEMAPHORE_JOB_ID", "id")],
        "environment_variables" => [git_var]
      }

      # a value the API cannot decode
      broken = %{
        "commands" => ["x"],
        "env_vars" => [%{"name" => "SEMAPHORE_GIT_SHA", "value" => "not base64!"}]
      }

      jobs = [
        finished_job(days_ago(10), %{request: both}),
        finished_job(days_ago(11), %{request: broken})
      ]

      assert %{trimmed: 0} = run_to_completion(worker())
      assert Enum.map(jobs, &Job.reload(&1).request) == [both, broken]
    end

    test "a job with a trimmed request can still be copied for a rebuild" do
      {:ok, task} = Support.Factories.Task.create()
      old = finished_job(days_ago(10), %{request: full_request(), build_id: task.id})

      run_to_completion(worker())

      assert {:ok, copy} = Job.create_copy(Job.reload(old), Ecto.UUID.generate())
      assert copy.original_job_id == old.id
      assert copy.request == git_only_request()
      assert copy.spec == Job.reload(old).spec
    end
  end

  describe ".naptime" do
    test "short nap while full batches keep coming, long nap otherwise" do
      w = worker(batch_size: 10, naptime: 1_000, longnaptime: 600_000)

      assert Cleaner.naptime(w, {:ok, %{scanned: 10, cleaned: 3, trimmed: 0}}) == 1_000
      assert Cleaner.naptime(w, {:ok, %{scanned: 9, cleaned: 9}}) == 600_000
      assert Cleaner.naptime(w, {:ok, %{scanned: 0, cleaned: 0}}) == 600_000
      assert Cleaner.naptime(w, {:ok, :locked}) == 600_000
      assert Cleaner.naptime(w, {:error, :boom}) == 600_000
    end
  end

  describe ".build" do
    test "accepts a valid configuration" do
      assert {:ok, %Cleaner{cutoff_days: 3, batch_size: 250, naptime: 1000, longnaptime: 5}} =
               Cleaner.build(cutoff_days: 3, batch_size: 250, naptime: 1000, longnaptime: 5)
    end

    test "rejects missing or non positive values" do
      base = [cutoff_days: 3, batch_size: 250, naptime: 1000, longnaptime: 5]

      for key <- [:cutoff_days, :batch_size, :naptime, :longnaptime] do
        assert {:error, _} = Cleaner.build(Keyword.put(base, key, 0))
        assert {:error, _} = Cleaner.build(Keyword.delete(base, key))
      end
    end
  end
end
