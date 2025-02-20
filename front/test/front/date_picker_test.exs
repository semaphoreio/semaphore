defmodule Front.DatePickerTest do
  use ExUnit.Case

  alias Front.DatePicker

  describe ".construct" do
    test "when dates are empty => it returns default range" do
      assert %{
               label: "Last 7 days",
               range: _,
               options: _,
               custom: false
             } = DatePicker.construct("", "")
    end

    test "when dates are invalid => it returns default range" do
      assert DatePicker.construct("2019-03-03", "foo_bar").label == "Last 7 days"
    end

    test "when dates are outside of standard ones => it returns custom range" do
      assert %{
               label: "03 Mar 2019 - 30 Mar 2019",
               range: _,
               options: _,
               custom: true
             } = DatePicker.construct("2019-03-03", "2019-03-30")
    end

    test "when dates indicates one of ranges => it returns this range" do
      yday = Timex.shift(Timex.today(), days: -1) |> Timex.format!("{YYYY}-{0M}-{0D}")

      assert DatePicker.construct(yday, yday).label == "Yesterday"
    end
  end
end
