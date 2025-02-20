defmodule Scouter.Grpc.ServerTest do
  use Scouter.RepoCase

  @moduletag :integration

  describe "creating events" do
    test "performs validation on context" do
      result =
        channel()
        |> InternalApi.Scouter.ScouterService.Stub.signal(%InternalApi.Scouter.SignalRequest{
          event_id: "test_event_id",
          context: %InternalApi.Scouter.Context{}
        })

      assert {:error, error} = result
      assert error.status == GRPC.Status.invalid_argument()

      assert error.message ==
               "at least one of organization_id, user_id, or project_id must be provided"
    end

    test "performs validation on event_id" do
      result =
        channel()
        |> InternalApi.Scouter.ScouterService.Stub.signal(%InternalApi.Scouter.SignalRequest{
          context: %InternalApi.Scouter.Context{
            organization_id: "test_organization_id"
          }
        })

      assert {:error, error} = result
      assert error.status == GRPC.Status.invalid_argument()
      assert error.message == "event_id can't be blank"
    end

    test "creates an event" do
      result =
        channel()
        |> InternalApi.Scouter.ScouterService.Stub.signal(%InternalApi.Scouter.SignalRequest{
          event_id: "test_event_id",
          context: %InternalApi.Scouter.Context{
            organization_id: "test_organization_id"
          }
        })

      assert {:ok, response} = result
      event = response.event

      assert event.id == "test_event_id"
      assert event.context.organization_id == "test_organization_id"

      [db_event] =
        Scouter.Storage.Event
        |> Scouter.Repo.all()

      assert db_event.event_id == "test_event_id"
      assert db_event.organization_id == "test_organization_id"
      assert db_event.project_id == ""
      assert db_event.user_id == ""
    end
  end

  describe "various cases" do
    setup do
      [channel: channel()]
    end

    test "when two signals are fired for the same event and context, only one event is created",
         %{channel: channel} do
      {:ok, _} =
        channel
        |> InternalApi.Scouter.ScouterService.Stub.signal(%InternalApi.Scouter.SignalRequest{
          event_id: "test_event_id",
          context: %InternalApi.Scouter.Context{
            organization_id: "test_organization_id"
          }
        })

      {:ok, _} =
        channel
        |> InternalApi.Scouter.ScouterService.Stub.signal(%InternalApi.Scouter.SignalRequest{
          event_id: "test_event_id",
          context: %InternalApi.Scouter.Context{
            organization_id: "test_organization_id"
          }
        })

      assert {:ok, result} =
               channel
               |> InternalApi.Scouter.ScouterService.Stub.list_events(
                 %InternalApi.Scouter.ListEventsRequest{
                   event_ids: [],
                   context: %InternalApi.Scouter.Context{
                     organization_id: "test_organization_id"
                   }
                 }
               )

      assert length(result.events) == 1
    end

    test "events are distinct accross contexts", %{channel: channel} do
      {:ok, _} =
        channel
        |> InternalApi.Scouter.ScouterService.Stub.signal(%InternalApi.Scouter.SignalRequest{
          event_id: "test_event_id",
          context: %InternalApi.Scouter.Context{
            organization_id: "test_organization_id"
          }
        })

      {:ok, _} =
        channel
        |> InternalApi.Scouter.ScouterService.Stub.signal(%InternalApi.Scouter.SignalRequest{
          event_id: "test_event_id",
          context: %InternalApi.Scouter.Context{
            organization_id: "test_organization_id_2"
          }
        })

      assert {:ok, result} =
               channel
               |> InternalApi.Scouter.ScouterService.Stub.list_events(
                 %InternalApi.Scouter.ListEventsRequest{
                   event_ids: [],
                   context: %InternalApi.Scouter.Context{
                     organization_id: "test_organization_id"
                   }
                 }
               )

      assert length(result.events) == 1

      {:ok, _} =
        channel
        |> InternalApi.Scouter.ScouterService.Stub.signal(%InternalApi.Scouter.SignalRequest{
          event_id: "test_event_id",
          context: %InternalApi.Scouter.Context{
            organization_id: "test_organization_id",
            user_id: "test_user_id"
          }
        })

      assert {:ok, result} =
               channel
               |> InternalApi.Scouter.ScouterService.Stub.list_events(
                 %InternalApi.Scouter.ListEventsRequest{
                   event_ids: [],
                   context: %InternalApi.Scouter.Context{
                     organization_id: "test_organization_id"
                   }
                 }
               )

      assert length(result.events) == 1

      assert {:ok, result} =
               channel
               |> InternalApi.Scouter.ScouterService.Stub.list_events(
                 %InternalApi.Scouter.ListEventsRequest{
                   event_ids: [],
                   context: %InternalApi.Scouter.Context{
                     organization_id: "test_organization_id",
                     user_id: "test_user_id"
                   }
                 }
               )

      assert length(result.events) == 1
    end

    test "listing when there are no events works", %{channel: channel} do
      assert {:ok, result} =
               channel
               |> InternalApi.Scouter.ScouterService.Stub.list_events(
                 %InternalApi.Scouter.ListEventsRequest{
                   event_ids: [],
                   context: %InternalApi.Scouter.Context{}
                 }
               )

      assert Enum.empty?(result.events)

      assert {:ok, result} =
               channel
               |> InternalApi.Scouter.ScouterService.Stub.list_events(
                 %InternalApi.Scouter.ListEventsRequest{
                   event_ids: [],
                   context: %InternalApi.Scouter.Context{
                     organization_id: "test_organization_id"
                   }
                 }
               )

      assert Enum.empty?(result.events)
    end

    test "handles events in a reasonable time", %{channel: channel} do
      users_count = 1000
      user_ids = Enum.to_list(0..users_count)

      for user_id <- user_ids do
        random_signal(channel, event_id: "user.login", context: %{user_id: "user_id_#{user_id}"})
        random_signal(channel, event_id: "user.logout", context: %{user_id: "user_id_#{user_id}"})
      end

      organizations_count = 10
      organization_ids = Enum.to_list(0..organizations_count)

      for organization_id <- organization_ids do
        random_signal(
          channel,
          event_id: "organization.created",
          context: %{organization_id: "organization_id_#{organization_id}"}
        )

        random_signal(
          channel,
          event_id: "organization.updated",
          context: %{organization_id: "organization_id_#{organization_id}"}
        )
      end

      for split_user_ids <- Enum.chunk_every(user_ids, organizations_count),
          split_user_id <- split_user_ids,
          organization_id <- organization_ids do
        random_signal(
          channel,
          event_id: "user.clicked_a_button",
          context: %{
            user_id: "user_id_#{split_user_id}",
            organization_id: "organization_id_#{organization_id}"
          }
        )
      end

      assert {:ok, result} =
               channel
               |> InternalApi.Scouter.ScouterService.Stub.list_events(
                 %InternalApi.Scouter.ListEventsRequest{
                   context: %InternalApi.Scouter.Context{
                     user_id: "user_id_1"
                   }
                 }
               )

      assert length(result.events) == 2

      assert {:ok, %{events: [event]}} =
               channel
               |> InternalApi.Scouter.ScouterService.Stub.list_events(
                 %InternalApi.Scouter.ListEventsRequest{
                   context: %InternalApi.Scouter.Context{
                     user_id: "user_id_1",
                     organization_id: "organization_id_1"
                   }
                 }
               )

      assert event.id == "user.clicked_a_button"
    end
  end

  defp random_signal(channel, opts) do
    assert {:ok, _} =
             channel
             |> InternalApi.Scouter.ScouterService.Stub.signal(%InternalApi.Scouter.SignalRequest{
               event_id: get_in(opts, [:event_id]),
               context: %InternalApi.Scouter.Context{
                 organization_id: get_in(opts, [:context, :organization_id]),
                 project_id: get_in(opts, [:context, :project_id]),
                 user_id: get_in(opts, [:context, :user_id])
               }
             })
  end

  defp channel do
    {:ok, channel} =
      GRPC.Stub.connect("localhost:50051")

    channel
  end
end
