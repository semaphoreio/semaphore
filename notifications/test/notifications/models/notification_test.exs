defmodule Notifications.Models.NotificationTest do
  use Notifications.DataCase

  alias Notifications.Models.Notification, as: Model

  describe ".uuid?" do
    test "when id is not binary, it returns false" do
      assert Model.uuid?("abc") == false
      assert Model.uuid?("#{Ecto.UUID.generate()}-extra§") == false
    end

    test "when id is binary, it returns true" do
      assert Model.uuid?(Ecto.UUID.generate()) == true
    end
  end
end
