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
    two_days_ago = Timex.now() |> Timex.shift(days: -2) |> Timex.to_unix()
    three_days_ago = Timex.now() |> Timex.shift(days: -3) |> Timex.to_unix()
    assert Front.Utils.decorate_relative(0) == ""
    assert Front.Utils.decorate_relative(nil) == ""
    assert Front.Utils.decorate_relative(DateTime.utc_now()) == "now"
    assert Front.Utils.decorate_relative(two_days_ago) == "2 days ago"
    assert Front.Utils.decorate_relative(three_days_ago) == "3 days ago"
    assert Front.Utils.decorate_relative(~U[2025-03-05 22:05:26.833945Z]) == "Wed 05th Mar 2025"
  end
end
