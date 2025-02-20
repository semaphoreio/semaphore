defmodule Notifications.Workers.Webhook.Signature.Test do
  use Notifications.DataCase

  alias Notifications.Workers.Webhook.Signature

  describe ".sign" do
    test "returns nil if secret is empty" do
      assert Signature.sign("body", nil) == nil
      assert Signature.sign("body", "") == nil
    end

    test "return signature" do
      assert Signature.sign("body", "secret") ==
               "dc46983557fea127b43af721467eb9b3fde2338fe3e14f51952aa8478c13d355"
    end
  end
end
