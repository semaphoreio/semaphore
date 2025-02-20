defmodule Front.DurationFormatterTest do
  use FrontWeb.ConnCase
  alias Front.DurationFormatter

  describe "format when duration is below an hour" do
    test "converts 120 seconds to 02:00" do
      assert DurationFormatter.format(120) == "02:00"
    end

    test "converts 125 seconds to 02:05" do
      assert DurationFormatter.format(125) == "02:05"
    end

    test "converts 0 seconds to 00:00" do
      assert DurationFormatter.format(0) == "00:00"
    end
  end

  describe "format when duration is between an hour and a day" do
    test "converts 3600 seconds to 01:00:00" do
      assert DurationFormatter.format(3600) == "01:00:00"
    end

    test "converts 3659 seconds to 01:00:59" do
      assert DurationFormatter.format(3659) == "01:00:59"
    end
  end

  describe "format when duration is above a day" do
    test "converts 86400 seconds to 1d 00:00:00" do
      assert DurationFormatter.format(86_400) == "1d 00:00:00"
    end

    test "converts 172860 seconds to 1d 00:00:00" do
      assert DurationFormatter.format(172_860) == "2d 00:01:00"
    end
  end
end
