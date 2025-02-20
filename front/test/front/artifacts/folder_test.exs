defmodule Front.Artifacts.FolderTest do
  use ExUnit.Case

  alias Front.Artifacts.Folder, as: Subject

  describe ".get_navigation" do
    test "it parse path into correct navigation components" do
      requested_path = "aaa/bbbb/cccc/dddd"

      expected = [
        %{last: false, name: "aaa", path: "aaa"},
        %{last: false, name: "bbbb", path: "aaa/bbbb"},
        %{last: false, name: "cccc", path: "aaa/bbbb/cccc"},
        %{last: true, name: "dddd", path: "aaa/bbbb/cccc/dddd"}
      ]

      assert Subject.get_navigation(requested_path) == expected
      assert Subject.get_navigation("") == []
    end
  end
end
