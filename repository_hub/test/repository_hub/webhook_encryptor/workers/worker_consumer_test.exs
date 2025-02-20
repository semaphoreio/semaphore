defmodule RepositoryHub.WebhookEncryptor.WorkerConsumerTest do
  use ExUnit.Case, async: true

  alias RepositoryHub.WebhookEncryptor.WorkerConsumer

  describe "handle_event/1" do
    test "when there is no worker for token then starts a new worker" do
      state = create_state([], min_demand: 5, max_demand: 10)
      event = create_event(integration_type: "github_oauth_token", token: "token")

      state = WorkerConsumer.handle_event(event, state)
      assert_receive {:perform, ^event}

      worker = Map.get(state.workers, "token")
      assert :queue.len(worker.events) == 1
      assert ^event = :queue.last(worker.events)
      assert worker.attempts == 1
      assert worker.ref && !worker.timer_ref
    end

    test "when there is a worker for token then queues event" do
      state =
        create_state([
          create_worker("github_oauth_token", "token", 5)
        ])

      event = create_event(integration_type: "github_oauth_token", token: "token")

      state = WorkerConsumer.handle_event(event, state)
      refute_received {:perform, ^event}

      worker = Map.get(state.workers, "token")
      assert :queue.len(worker.events) == 6
      assert ^event = :queue.last(worker.events)
    end
  end

  describe "dequeue_and_start/3" do
    test "when there is no worker for ref then logs and ignores it" do
      state = create_state([], min_demand: 5, max_demand: 10)
      event = create_event(integration_type: "github_oauth_token", token: "token")

      task = perform_async(event)
      assert_receive {:perform, ^event}

      assert ^state = WorkerConsumer.dequeue_and_start({:debug, "test"}, task.ref, state)
      refute_received {:perform, ^event}
    end

    test "when there is worker and has no events left then removes it" do
      worker = create_worker("github_oauth_token", "token", 1)
      {event, events} = :queue.out(worker.events)

      timer_ref = Process.send_after(self(), {:timeout, worker.token}, 5_000)
      task = perform_async(event)
      assert_receive {:perform, ^event}

      state =
        create_state([
          %{
            worker
            | events: events,
              ref: task.ref,
              timer_ref: timer_ref,
              attempts: 1
          }
        ])

      new_state = WorkerConsumer.dequeue_and_start({:debug, "test"}, task.ref, state)
      assert !Map.has_key?(new_state.workers, "token")
      refute Process.read_timer(timer_ref)
      refute_received {:perform, ^event}
    end

    test "when there is worker and has more events then starts a task" do
      worker = create_worker("github_oauth_token", "token", 7)
      timer_ref = Process.send_after(self(), {:timeout, worker.token}, 5_000)
      task = perform_async(:queue.peek(worker.events))
      assert_receive {:perform, _event}

      state =
        create_state([
          %{
            worker
            | ref: task.ref,
              timer_ref: timer_ref,
              attempts: 1
          }
        ])

      new_state = WorkerConsumer.dequeue_and_start({:debug, "test"}, task.ref, state)

      assert %{token: "token", events: events, attempts: 1, ref: ref, timer_ref: nil} =
               Map.get(new_state.workers, "token")

      assert is_reference(ref)
      assert :queue.len(events) == 6
      assert_receive {:perform, event}
      assert {:value, ^event} = :queue.peek(events)
      assert_receive {:"$gen_producer", _ref, {:ask, 9}}
    end

    test "when there is worker and has exceeded max attempts then moves on" do
      worker = create_worker("github_oauth_token", "token", 4)
      timer_ref = Process.send_after(self(), {:timeout, worker.token}, 5_000)

      {:value, event} = :queue.peek(worker.events)
      task = perform_async(event)
      assert_receive {:perform, ^event}

      state =
        create_state([
          %{
            worker
            | ref: task.ref,
              timer_ref: timer_ref,
              attempts: 3
          },
          create_worker("github_oauth_token", "token2", 1),
          create_worker("github_oauth_token", "token3", 1),
          create_worker("github_oauth_token", "token4", 1),
          create_worker("github_oauth_token", "token5", 1)
        ])

      new_state = WorkerConsumer.dequeue_and_start({:debug, "test"}, task.ref, state)

      assert %{token: "token", events: events, attempts: 1, ref: ref, timer_ref: nil} =
               Map.get(new_state.workers, "token")

      assert is_reference(ref)
      assert :queue.len(events) == 3
      assert_receive {:perform, event}
      assert {:value, ^event} = :queue.peek(events)

      refute_receive {:"$gen_producer", _ref, _}
    end
  end

  describe "schedule_retry/1" do
    test "when there is no worker for ref then logs and ignores it" do
      state = create_state([], min_demand: 5, max_demand: 10)
      event = create_event(integration_type: "github_oauth_token", token: "token")

      task = perform_async(event)
      assert_receive {:perform, ^event}

      assert ^state = WorkerConsumer.schedule_retry(20, task.ref, state)
      refute_received {:perform, ^event}
      assert_receive {:"$gen_producer", _ref, {:ask, 10}}
    end

    test "when there is a worker with timer then cancels it and schedules a new one" do
      worker = create_worker("github_oauth_token", "token", 7)
      old_tref = Process.send_after(self(), {:timeout, worker.token}, 5_000)

      {:value, event} = :queue.peek(worker.events)
      task = perform_async(event)
      assert_receive {:perform, ^event}

      state =
        create_state([
          %{
            worker
            | ref: task.ref,
              timer_ref: old_tref,
              attempts: 1
          }
        ])

      new_state = WorkerConsumer.schedule_retry(20, task.ref, state)

      assert %{token: "token", events: events, attempts: 1, ref: ref, timer_ref: tref} =
               Map.get(new_state.workers, "token")

      assert events == worker.events
      assert ref == task.ref
      refute old_tref == tref

      assert_in_delta Process.read_timer(tref), 20_000, 1_000
      refute Process.read_timer(old_tref)
    end
  end

  describe "maybe_ask_for_demand/1" do
    test "when there are no workers then asks for max demand" do
      state = create_state([], min_demand: 5, max_demand: 10)
      WorkerConsumer.maybe_ask_for_demand(state)
      assert_received {:"$gen_producer", _ref, {:ask, 10}}
    end

    test "when there are workers below the min demand then asks for diff" do
      state =
        create_state(
          Enum.into(1..3, [], &create_worker("github_oauth_token", "token#{&1}", 5)),
          min_demand: 5,
          max_demand: 10
        )

      WorkerConsumer.maybe_ask_for_demand(state)
      assert_received {:"$gen_producer", _ref, {:ask, 7}}
    end

    test "when there are workers with overloaded event queues then doesn't ask for demand" do
      state =
        create_state(
          Enum.into(1..3, [], &create_worker("github_oauth_token", "token#{&1}", &1 * 10)),
          min_demand: 5,
          max_demand: 10
        )

      WorkerConsumer.maybe_ask_for_demand(state)
      refute_received {:"$gen_producer", _ref, _}
    end

    test "when there are workers equal to min demand then doesn't ask for demand" do
      state =
        create_state(
          Enum.into(1..5, [], &create_worker("github_oauth_token", "token#{&1}", 5)),
          min_demand: 5,
          max_demand: 10
        )

      WorkerConsumer.maybe_ask_for_demand(state)
      refute_receive {:"$gen_producer", _ref, _}
    end

    test "when there are workers above the max demand then doesn't ask for demand" do
      state =
        create_state(
          Enum.into(1..7, [], &create_worker("github_oauth_token", "token#{&1}", 5)),
          min_demand: 5,
          max_demand: 10
        )

      WorkerConsumer.maybe_ask_for_demand(state)
      refute_receive {:"$gen_producer", _ref, _}
    end
  end

  def perform_async(event) do
    caller_pid = self()

    Task.async(fn ->
      Process.send(caller_pid, {:perform, event}, [])
    end)
  end

  defp create_state(workers, args \\ []) do
    %{
      workers: Map.new(workers, &{&1.token, &1}),
      worker_module: __MODULE__,
      min_demand: args[:min_demand] || 5,
      max_demand: args[:max_demand] || 10,
      producer: {self(), make_ref()}
    }
  end

  defp create_worker(integration_type, token, num_events) do
    args = [integration_type: integration_type, token: token]

    events =
      Enum.reduce(1..num_events//1, :queue.new(), fn index, queue ->
        :queue.in(create_event(Keyword.merge(args, index: index)), queue)
      end)

    %{events: events, token: token, ref: nil, timer_ref: nil, attempts: 0}
  end

  defp create_event(args) do
    %{
      org_id: UUID.uuid4(),
      org_username: "org_username",
      project_id: UUID.uuid4(),
      project_owner_id: UUID.uuid4(),
      repository_id: UUID.uuid4(),
      token: args[:token],
      git_repository: %{
        owner: args[:owner] || "owner",
        name: args[:repo] || "repo#{args[:index] || ""}"
      },
      integration_type: args[:integration_type]
    }
  end
end
