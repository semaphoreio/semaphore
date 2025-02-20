defmodule FrontWeb.SwitchViewTest do
  use FrontWeb.ConnCase

  describe ".triggered_at" do
    test "returns formatted date time" do
      assert FrontWeb.SwitchView.triggered_at(%{triggered_at: 1_533_543_418}) ==
               "2018-08-06T08:16:58+00:00"
    end
  end
end
