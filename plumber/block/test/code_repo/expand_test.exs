defmodule Block.CodeRepo.ExpandTest do
  use ExUnit.Case
  doctest Block.CodeRepo.Expand

  alias Block.CodeRepo.Expand

  test "full_name" do
    previous_dir = ["/", "foo/bar", "/foo/bar", "./foo", "fiz  "]
    file_names = ["a.yml", "test/a.yml", "../baz/a.yml", "./href/a.yml", "b.yml  "]
    # result matrix, rows are for different dirs and cols for different file_names
    expected =
      [
        "/a.yml",         "/test/a.yml",          "/baz/a.yml",     "/href/a.yml",         "/b.yml",
        "foo/bar/a.yml",  "foo/bar/test/a.yml",   "foo/baz/a.yml",  "foo/bar/href/a.yml",  "foo/bar/b.yml",
        "/foo/bar/a.yml", "/foo/bar/test/a.yml",  "/foo/baz/a.yml", "/foo/bar/href/a.yml", "/foo/bar/b.yml",
        "foo/a.yml",      "foo/test/a.yml",       "baz/a.yml",      "foo/href/a.yml",      "foo/b.yml",
        "fiz/a.yml",      "fiz/test/a.yml",       "baz/a.yml",     "fiz/href/a.yml",       "fiz/b.yml"
      ]

    res = for d <- previous_dir, f <- file_names do
      Expand.full_name(d, f)
    end
    assert(res == expected)
  end
end
