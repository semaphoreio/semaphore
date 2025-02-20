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
end
