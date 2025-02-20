defmodule Audit.Streamer.SchedulerTest do
  use Support.DataCase

  alias InternalApi.Audit.Event.{Resource, Operation, Medium}
  alias InternalApi, as: IA
  alias ExAws.S3

  test "test locking and processing" do
    config = create_streamer_conf()
    evs = create_events(config.org_id)

    Audit.Streamer.Scheduler.lock_and_process(config.org_id)

    first = %{timestamp: DateTime.from_unix!(0)}
    last = %{timestamp: DateTime.from_unix!(40)}
    ## S3 get object to verify content
    object =
      S3.get_object(
        config.metadata.bucket_name,
        Audit.Streamer.Scheduler.new_file_name(first, last)
      )
      |> ExAws.request!(
        access_key_id: config.cridentials.key_id,
        secret_access_key: config.cridentials.key_secret,
        host: System.fetch_env!("S3_HOST"),
        port: 9090,
        scheme: "http://"
      )

    assert object.body == Audit.Streamer.FileFormatter.csv(evs)
  end

  test "test locking and batch processing" do
    config = create_streamer_conf()

    num_create = div(3 * Audit.Streamer.Scheduler.max_events_limit(), 2)
    _evs = create_events(config.org_id, num_create)

    events_before = Audit.Event.all(%{org_id: config.org_id})
    assert num_create == length(events_before)

    Audit.Streamer.Scheduler.lock_and_process(config.org_id)

    should_be_unprocessed = num_create - Audit.Streamer.Scheduler.max_events_limit()
    events_after_the_1st_processing = Audit.Event.all(%{org_id: config.org_id, streamed: false})
    assert should_be_unprocessed == length(events_after_the_1st_processing)

    Audit.Streamer.Scheduler.lock_and_process(config.org_id)
    events_after_the_2nd_processing = Audit.Event.all(%{org_id: config.org_id, streamed: false})
    assert Enum.empty?(events_after_the_2nd_processing)
  end

  def create_streamer_conf do
    org_id = Ecto.UUID.generate()

    Audit.Streamer.Config.create(
      config = %{
        org_id: org_id,
        provider: IA.Audit.StreamProvider.value(:S3),
        metadata: %{
          bucket_name: "test-bucket",
          host: System.fetch_env!("S3_HOST"),
          port: 9090,
          scheme: "http://"
        },
        cridentials: %{
          key_id: "key-id",
          key_secret: "the-cake-is-a-lie-secret"
        },
        paused: false,
        last_streamed: Timex.shift(Timex.now(), days: -1)
      }
    )

    config
  end

  def create_events(org_id) do
    operation1 = Ecto.UUID.generate()
    operation2 = Ecto.UUID.generate()
    _operation3 = Ecto.UUID.generate()

    user_id1 = Ecto.UUID.generate()
    user_id2 = Ecto.UUID.generate()
    events = []

    {:ok, _} =
      Audit.Event.create(
        ev = %{
          resource: Resource.value(:Secret),
          operation: Operation.value(:Added),
          org_id: org_id,
          user_id: user_id1,
          username: "hello",
          operation_id: operation1,
          ip_address: "1.1.1.1",
          timestamp: DateTime.from_unix!(0),
          resource_id: Ecto.UUID.generate(),
          resource_name: "my-secret",
          metadata: %{"hello" => "world"},
          medium: Medium.value(:Web)
        }
      )

    events = [ev | events]

    {:ok, _} =
      Audit.Event.create(
        ev = %{
          resource: Resource.value(:Secret),
          operation: Operation.value(:Added),
          org_id: org_id,
          user_id: user_id1,
          username: "hello",
          operation_id: operation1,
          ip_address: "1.1.1.1",
          timestamp: DateTime.from_unix!(20),
          resource_id: Ecto.UUID.generate(),
          resource_name: "my-secret",
          metadata: %{"hello" => "world", "how" => "are you?"},
          medium: Medium.value(:Web)
        }
      )

    events = [ev | events]

    {:ok, _} =
      Audit.Event.create(
        ev = %{
          resource: Resource.value(:Secret),
          operation: Operation.value(:Removed),
          org_id: org_id,
          user_id: user_id2,
          username: "hello",
          operation_id: operation2,
          ip_address: "1.2.1.1",
          timestamp: DateTime.from_unix!(30),
          resource_id: Ecto.UUID.generate(),
          resource_name: "my-secret",
          metadata: %{"hello" => "world"},
          medium: Medium.value(:Web)
        }
      )

    events = [ev | events]

    {:ok, _} =
      Audit.Event.create(
        ev = %{
          resource: Resource.value(:Secret),
          operation: Operation.value(:Removed),
          org_id: org_id,
          user_id: user_id2,
          username: "hello",
          operation_id: operation2,
          ip_address: "1.2.1.1",
          timestamp: DateTime.from_unix!(40),
          resource_id: Ecto.UUID.generate(),
          resource_name: "my-secret",
          metadata: %{"hello" => "world", "how" => "are you doing?"},
          medium: Medium.value(:Web)
        }
      )

    events = [ev | events]

    Enum.reverse(events)
  end

  def create_events(org_id, qty) do
    1..qty
    |> Enum.each(&create_event(org_id, &1))
  end

  defp create_event(org_id, id) do
    {:ok, _} =
      Audit.Event.create(
        _ev = %{
          resource: Resource.value(:Secret),
          operation: Operation.value(:Added),
          org_id: org_id,
          user_id: Ecto.UUID.generate(),
          username: "hello #{id}",
          operation_id: Ecto.UUID.generate(),
          ip_address: "1.1.1.1",
          timestamp: DateTime.from_unix!(0),
          resource_id: Ecto.UUID.generate(),
          resource_name: "my-secret",
          metadata: %{"hello #{id}" => "world #{id}"},
          medium: Medium.value(:Web)
        }
      )
  end
end
