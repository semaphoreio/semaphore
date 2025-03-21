defmodule Rbac.Services.UserDeletedTest do
  use Rbac.RepoCase

  import Mock

  describe ".handle_message" do
    test "message processing when the server is avaible" do
      with_mock Rbac.Store.RbacUser, delete: fn _ -> {:ok, nil} end do
        user_id = Ecto.UUID.generate()
        publish_event(user_id)
        :timer.sleep(300)

        # Checking if sync with rbac is working
        assert_called_exactly(Rbac.Store.RbacUser.delete(user_id), 1)
      end
    end

    test "make sure okta user is disconnected" do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, okta_user} = Support.Factories.OktaUser.insert(user_id: user.id)

      publish_event(user.id)
      :timer.sleep(300)

      refute Rbac.Store.RbacUser.fetch(user.id)

      # Reload the okta user to see its current state
      okta_user_after_deletion = Rbac.Repo.get(Rbac.Repo.OktaUser, okta_user.id)

      assert okta_user_after_deletion != nil
      assert okta_user_after_deletion.user_id == nil
    end

    test "make sure saml_jit user is disconnected" do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, saml_jit_user} = Support.Factories.SamlJitUser.insert(user_id: user.id)

      publish_event(user.id)
      :timer.sleep(300)

      refute Rbac.Store.RbacUser.fetch(user.id)

      # Reload the saml_jit user to see its current state
      saml_jit_user_after_deletion = Rbac.Repo.get(Rbac.Repo.SamlJitUser, saml_jit_user.id)

      assert saml_jit_user_after_deletion != nil
      assert saml_jit_user_after_deletion.user_id == nil
    end
  end

  #
  # Helpers
  #

  def publish_event(user_id) do
    event = %InternalApi.User.UserDeleted{user_id: user_id}

    message = InternalApi.User.UserDeleted.encode(event)

    options = %{
      url: Application.get_env(:rbac, :amqp_url),
      exchange: "user_exchange",
      routing_key: "deleted"
    }

    Tackle.publish(message, options)
  end
end
