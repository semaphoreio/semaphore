defmodule Zebra.Machines.BrownoutTest do
  use ExUnit.Case, async: false
  alias Zebra.Machines.Brownout

  setup do
    Mox.stub_with(Support.MockedProvider, Support.StubbedProvider)

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

  describe "applying brownout on a schedule" do
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

    test "ignores not browned out os images", %{schedules: schedules} do
      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-01 00:10:00], "1", "ubuntu2004") ==
               false
    end

    test "works with multiple os images", %{schedules: schedules} do
      assert Brownout.os_image_in_brownout?(schedules, ~N[2024-01-02 00:10:00], "1", "ubuntu2004") ==
               true
    end
  end

  describe "exclude_from_brownouts feature flag" do
    test "excludes organization with feature enabled", %{schedules: schedules} do
      excluded_org = Support.StubbedProvider.exclude_from_brownouts_org_id()

      assert Brownout.os_image_in_brownout?(
               schedules,
               ~N[2024-01-01 00:10:00],
               excluded_org,
               "ubuntu1804"
             ) == false
    end

    test "applies brownout for organization without feature enabled", %{schedules: schedules} do
      assert Brownout.os_image_in_brownout?(
               schedules,
               ~N[2024-01-01 00:10:00],
               "regular-org",
               "ubuntu1804"
             ) == true
    end
  end

  describe "resolving brownout status" do
    test "returns :not_in_brownout outside a scheduled window", %{schedules: schedules} do
      assert Brownout.status(schedules, ~N[2024-01-01 00:15:01], "regular-org", "ubuntu1804") ==
               :not_in_brownout
    end

    test "returns :not_in_brownout for an os image without a schedule", %{schedules: schedules} do
      assert Brownout.status(schedules, ~N[2024-01-01 00:10:00], "regular-org", "ubuntu2004") ==
               :not_in_brownout
    end

    test "returns :in_brownout inside a scheduled window", %{schedules: schedules} do
      assert Brownout.status(schedules, ~N[2024-01-01 00:10:00], "regular-org", "ubuntu1804") ==
               :in_brownout
    end

    test "returns :excluded for an opted out organization", %{schedules: schedules} do
      excluded_org = Support.StubbedProvider.exclude_from_brownouts_org_id()

      assert Brownout.status(schedules, ~N[2024-01-01 00:10:00], excluded_org, "ubuntu1804") ==
               :excluded
    end

    test "returns :not_in_brownout for an opted out organization outside a window", %{
      schedules: schedules
    } do
      excluded_org = Support.StubbedProvider.exclude_from_brownouts_org_id()

      assert Brownout.status(schedules, ~N[2024-01-01 00:15:01], excluded_org, "ubuntu1804") ==
               :not_in_brownout
    end
  end

  describe "applying brownout without schedules" do
    test "works" do
      assert Brownout.os_image_in_brownout?([], ~N[2024-01-01 00:10:00], "1", "ubuntu1804") ==
               false
    end
  end

  describe "applying brownout on default schedules" do
    test "works for macos-xcode16" do
      assert Brownout.os_image_in_brownout?(
               ~U[2026-09-07 10:10:00Z],
               "regular-org",
               "macos-xcode16"
             ) == true

      assert Brownout.os_image_in_brownout?(
               ~U[2026-09-07 10:15:01Z],
               "regular-org",
               "macos-xcode16"
             ) == false

      assert Brownout.os_image_in_brownout?(
               ~U[2026-10-04 23:30:00Z],
               "regular-org",
               "macos-xcode16"
             ) == true

      assert Brownout.os_image_in_brownout?(
               ~U[2026-09-07 10:10:00Z],
               "regular-org",
               "macos-xcode15"
             ) == false
    end
  end
end
