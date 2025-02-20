defmodule Guard.Services.OrganizationUnsuspended.Test do
  use Guard.RepoCase

  @org_id "78114608-be8a-465a-b9cd-81970fb802c6"

  setup do
    Support.Guard.Store.clear!()

    :ok
  end

  describe ".handle_message" do
    test "message processing when the server is avaible" do
      Guard.Store.Suspension.add(@org_id)
      assert Guard.Store.Suspension.exists?(@org_id)

      publish_event()
      :timer.sleep(100)

      refute Guard.Store.Suspension.exists?(@org_id)
    end
  end

  #
  # Helpers
  #

  def publish_event do
    event = InternalApi.Organization.OrganizationUnblocked.new(org_id: @org_id)

    message = InternalApi.Organization.OrganizationUnblocked.encode(event)

    options = %{
      url: Application.get_env(:guard, :amqp_url),
      exchange: "organization_exchange",
      routing_key: "unblocked"
    }

    Tackle.publish(message, options)
  end
end
