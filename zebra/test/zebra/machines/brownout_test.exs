defmodule Zebra.Machines.BrownoutTest do
  use ExUnit.Case, async: true
  alias Zebra.Machines.Brownout

  describe "applying brownout on a schedule" do
    setup do
      old_configuration = Application.get_env(:zebra, Brownout, [])

      Application.put_env(:zebra, Brownout, excluded_organization_ids: "2,3")

      on_exit(fn ->
        Application.put_env(:zebra, Brownout, old_configuration)
      end)

      [
        schedules: [
          Brownout.schedule(~N[2024-01-01 00:00:00], ~N[2024-01-01 00:15:00], ["ubuntu1804"]),
          Brownout.schedule(~N[2024-01-02 00:00:00], ~N[2024-01-02 00:15:00], [
            "ubuntu1804",
            "ubuntu2004"
          ])
        ]
      ]
    end

    test "ignores excluded organizations", %{schedules: schedules} do
      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-01 00:10:00], "2", "ubuntu1804") ==
               false

      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-01 00:10:00], "3", "ubuntu1804") ==
               false
    end

    test "ignores not browned out os images", %{schedules: schedules} do
      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-01 00:10:00], "1", "ubuntu2004") ==
               false
    end

    test "works on a schedule", %{schedules: schedules} do
      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-12-31 23:59:59], "1", "ubuntu1804") ==
               false

      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-01 00:00:00], "1", "ubuntu1804") ==
               true

      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-01 00:10:00], "1", "ubuntu1804") ==
               true

      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-01 00:15:00], "1", "ubuntu1804") ==
               true

      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-01 00:15:01], "1", "ubuntu1804") ==
               false

      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-01 23:59:59], "1", "ubuntu1804") ==
               false

      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-02 00:00:00], "1", "ubuntu1804") ==
               true

      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-02 00:10:00], "1", "ubuntu1804") ==
               true

      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-02 00:15:00], "1", "ubuntu1804") ==
               true

      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-02 00:15:01], "1", "ubuntu1804") ==
               false
    end

    test "works with multiple os images", %{schedules: schedules} do
      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-02 00:10:00], "1", "ubuntu2004") ==
               true
    end
  end

  describe "applying brownout without configuration" do
    setup do
      old_configuration = Application.get_env(:zebra, Brownout, [])

      Application.put_env(:zebra, Brownout, nil)

      on_exit(fn ->
        Application.put_env(:zebra, Brownout, old_configuration)
      end)
    end

    test "works" do
      assert Brownout.os_image_in_brownout?([], ~N[2024-01-01 00:10:00], "1", "ubuntu1804") ==
               false
    end
  end
end
