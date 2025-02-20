defmodule Front.KondoTest do
  use ExUnit.Case

  alias Front.Kondo

  describe ".categorize_by_name" do
    test "it categorizes list of projects and each category is sorted by name" do
      unsorted = [
        %{name: "Test7", desc: "aa"},
        %{name: "404a", desc: "bb"},
        %{name: "202"},
        %{name: "Test2"}
      ]

      assert Kondo.categorize_by_name(unsorted) ==
               [
                 {"0-9", [%{name: "202"}, %{name: "404a", desc: "bb"}]},
                 {"T", [%{name: "Test2"}, %{name: "Test7", desc: "aa"}]}
               ]
    end
  end
end
