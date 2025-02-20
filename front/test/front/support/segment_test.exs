defmodule Front.Support.SegmentTest do
  use ExUnit.Case
  alias Front.Support.Segment

  describe ".determine" do
    test "segment is nil for a non paid plan" do
      status = %{plan: "free", last_charge_in_dollars: 0}

      refute Segment.determine(status)
    end

    test "when the last charge was above 1000$ => is gold" do
      status = %{plan: "paid", last_charge_in_dollars: 1001}

      assert Segment.determine(status) == "gold"
    end

    test "when the last charge was 1000$ => is gold" do
      status = %{plan: "paid", last_charge_in_dollars: 1000}

      assert Segment.determine(status) == "gold"
    end

    test "when the last charge was 999$ => is silver" do
      status = %{plan: "paid", last_charge_in_dollars: 999}

      assert Segment.determine(status) == "silver"
    end

    test "when the last charge was 300$ => is silver" do
      status = %{plan: "paid", last_charge_in_dollars: 300}

      assert Segment.determine(status) == "silver"
    end

    test "when the last charge was 299$ => is iron" do
      status = %{plan: "paid", last_charge_in_dollars: 299}

      assert Segment.determine(status) == "iron"
    end

    test "when the last charge was 30$ => is iron" do
      status = %{plan: "paid", last_charge_in_dollars: 30}

      assert Segment.determine(status) == "iron"
    end

    test "when the last charge was 29$ => is carbon" do
      status = %{plan: "paid", last_charge_in_dollars: 29}

      assert Segment.determine(status) == "carbon"
    end

    test "when the last charge was 0$ => is carbon" do
      status = %{plan: "paid", last_charge_in_dollars: 0}

      assert Segment.determine(status) == "carbon"
    end
  end
end
