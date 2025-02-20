defmodule FrontWeb.SharedHelpersTest do
  use FrontWeb.ConnCase

  setup do
    Support.FakeServices.stub_responses()
  end

  describe "icon" do
    test "it includes passed options" do
      {:safe, image_string_with_class} = FrontWeb.SharedHelpers.icon("test", class: "db")
      assert image_string_with_class =~ "class='db'"
      assert image_string_with_class =~ "test"
      refute image_string_with_class =~ "width"
      refute image_string_with_class =~ "height"

      {:safe, image_string_with_width} = FrontWeb.SharedHelpers.icon("test", width: "24")
      assert image_string_with_width =~ "width='24'"
      refute image_string_with_width =~ "class"

      {:safe, image_string_without_height} =
        FrontWeb.SharedHelpers.icon("test", width: "24", class: "db")

      assert image_string_without_height =~ "width='24'"
      assert image_string_without_height =~ "class='db'"
      refute image_string_without_height =~ "height"

      {:safe, image_string_with_height} = FrontWeb.SharedHelpers.icon("test", height: "24")
      assert image_string_with_height =~ "height='24'"
    end
  end
end
