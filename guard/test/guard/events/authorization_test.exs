defmodule Guard.Events.AuthorizationTest do
  use Guard.RepoCase

  describe "publish" do
    test "encodes and publishes the message" do
      assert {:ok, _message} =
               Guard.Events.Authorization.publish(
                 "collaborator_created",
                 "123",
                 "123",
                 "123"
               )
    end

    test "doesn't publish when routing key is invalid" do
      assert {:error, "cheese"} ==
               Guard.Events.Authorization.publish(
                 "cheese",
                 "123",
                 "123",
                 "123"
               )
    end
  end
end
