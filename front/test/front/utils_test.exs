defmodule Front.UtilsTest do
  use ExUnit.Case

  test "users case" do
    assert Front.Utils.regexp_split("/master|release-calient-v([4-9]|{2,}|3\.({2,}|[4-9]).*)/") ==
             [
               "/master|release-calient-v([4-9]|{2,}|3\.({2,}|[4-9]).*)/"
             ]
  end

  test "user case 2" do
    assert Front.Utils.regexp_split("develop,/feature\\/.+/,/release\\/.+/,/hotfix\\/.+/") ==
             [
               "develop",
               "/feature\\/.+/",
               "/release\\/.+/",
               "/hotfix\\/.+/"
             ]
  end

  test "split regexp with escaped /" do
    assert Front.Utils.regexp_split("/branch1\\//") == [
             "/branch1\\//"
           ]
  end

  test "split one branch" do
    assert Front.Utils.regexp_split("branch1") == [
             "branch1"
           ]
  end

  test "split one regexp" do
    assert Front.Utils.regexp_split("/branch1/") == [
             "/branch1/"
           ]
  end

  test "split simple branches" do
    assert Front.Utils.regexp_split("branch1, branch2") == [
             "branch1",
             "branch2"
           ]
  end

  test "split branch and regexp with trimable characters" do
    assert Front.Utils.regexp_split(" branch1 , /branch2/") == [
             "branch1",
             "/branch2/"
           ]
  end

  test "split one regexp with comma inside" do
    assert Front.Utils.regexp_split("/bra, nch2/") == [
             "/bra, nch2/"
           ]
  end

  test "split two regexpes" do
    assert Front.Utils.regexp_split("/b, ra/, /nch2/") == [
             "/b, ra/",
             "/nch2/"
           ]
  end

  test "decorate relative" do
    now = DateTime.utc_now()

    thirty_minutes_ago = DateTime.add(now, -30 * 60, :second)
    two_days_ago = DateTime.new!(Date.add(Date.utc_today(), -2), ~T[14:30:00])
    three_days_ago = DateTime.new!(Date.add(Date.utc_today(), -3), ~T[10:15:00])

    assert Front.Utils.decorate_relative(0) == ""
    assert Front.Utils.decorate_relative(nil) == ""
    assert Front.Utils.decorate_relative(now) == "now"

    assert Front.Utils.decorate_relative(thirty_minutes_ago) == "30 minutes ago"

    ordinal_suffix_regex = "(st|nd|rd|th)"

    assert Regex.match?(
             ~r/on \w{3} \d{2}#{ordinal_suffix_regex} \w{3} \d{4} at \d{2}:\d{2}/,
             Front.Utils.decorate_relative(two_days_ago)
           )

    assert Regex.match?(
             ~r/on \w{3} \d{2}#{ordinal_suffix_regex} \w{3} \d{4} at \d{2}:\d{2}/,
             Front.Utils.decorate_relative(three_days_ago)
           )

    assert Front.Utils.decorate_relative(~U[2025-03-05 22:05:26.833945Z]) ==
             "on Wed 05th Mar 2025"
  end
end
