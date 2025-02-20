defmodule Rbac.Services.UserCreatorTest do
  use Rbac.RepoCase, async: false

  @exchange_name "user_exchange_test"
  @routing_key "created_test"
  @service_name "rbac-service-test"

  setup do
    Support.Rbac.Store.clear!()

    :ok
  end

  describe ".handle_message" do
    test "message processing when the server is available" do
      # Create test consumer to remove flaky tests completely.
      # Consumer will receive the message and send it to the test process
      {:module, consumer_module, _, _} =
        Support.TestConsumer.create_test_consumer(
          self(),
          Application.get_env(:rbac, :amqp_url),
          @exchange_name,
          @routing_key,
          @service_name,
          Rbac.Services.UserCreator
        )

      {:ok, _} = consumer_module.start_link()

      {:ok, _} = GenServer.start(Rbac.Utils.Counter, 0, name: :test_counter)

      user = Support.Factories.user()

      {:ok, front_user} =
        %Rbac.FrontRepo.User{
          id: user.user_id,
          name: user.name,
          email: user.email
        }
        |> Rbac.FrontRepo.insert()

      github_uids = ["184065", "44306450"]

      github_uids
      |> Enum.each(fn github_uid ->
        {:ok, _repo_host_account} =
          Support.Members.insert_repo_host_account(
            login: "radwo",
            repo_host: "github",
            user_id: front_user.id,
            permission_scope: "repo",
            github_uid: github_uid
          )
      end)

      publish_event(user)
      GenServer.stop(:test_counter)

      assert_receive {:ok, Rbac.Services.UserCreator}, 10_000

      assert front_user.id ==
               Rbac.Store.User.find_id_by_provider_uid("184065", "github")

      assert front_user.id ==
               Rbac.Store.User.find_id_by_provider_uid("44306450", "github")

      # Check if the user was synced with RBAC
      assert Rbac.Store.RbacUser.fetch(front_user.id) != nil
    end
  end

  #
  # Helpers
  #

  def publish_event(user) do
    event = %InternalApi.User.UserCreated{user_id: user.user_id}
    message = InternalApi.User.UserCreated.encode(event)

    options = %{
      url: Application.get_env(:rbac, :amqp_url),
      exchange: @exchange_name,
      routing_key: @routing_key
    }

    Tackle.publish(message, options)
  end
end
