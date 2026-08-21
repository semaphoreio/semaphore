defmodule Projecthub.Github.PathSegmentTest do
  use ExUnit.Case, async: true

  alias Projecthub.Github.PathSegment

  describe ".validate/1 with legitimate GitHub identifiers" do
    test "accepts a typical org/user login" do
      assert {:ok, "renderedtext"} = PathSegment.validate("renderedtext")
    end

    test "accepts logins and repo names with hyphens, underscores, and dots" do
      assert {:ok, "semaphore-ci"} = PathSegment.validate("semaphore-ci")
      assert {:ok, "ex_tackle"} = PathSegment.validate("ex_tackle")
      assert {:ok, "my.repo"} = PathSegment.validate("my.repo")
    end

    test "accepts a numeric-looking login" do
      assert {:ok, "12345"} = PathSegment.validate("12345")
    end
  end

  describe ".validate/1 with hostile or malformed input" do
    test "rejects CRLF (request-splitting payload)" do
      assert {:error, :invalid_github_path_segment} = PathSegment.validate("x\r\nX-Injected: yes")
    end

    test "rejects a bare LF" do
      assert {:error, :invalid_github_path_segment} = PathSegment.validate("foo\nbar")
    end

    test "rejects a bare CR" do
      assert {:error, :invalid_github_path_segment} = PathSegment.validate("foo\rbar")
    end

    test "rejects an embedded space" do
      assert {:error, :invalid_github_path_segment} = PathSegment.validate("foo bar")
    end

    test "rejects other control characters" do
      assert {:error, :invalid_github_path_segment} = PathSegment.validate("foo" <> <<0x07>> <> "bar")
    end

    test "rejects an embedded path separator (extra path segment)" do
      assert {:error, :invalid_github_path_segment} = PathSegment.validate("owner/../other")
    end

    test "rejects an embedded query delimiter" do
      assert {:error, :invalid_github_path_segment} = PathSegment.validate("repo?evil=1")
    end

    test "rejects an embedded fragment delimiter" do
      assert {:error, :invalid_github_path_segment} = PathSegment.validate("repo#fragment")
    end

    test "rejects the empty string" do
      assert {:error, :invalid_github_path_segment} = PathSegment.validate("")
    end

    test "rejects non-string input" do
      assert {:error, :invalid_github_path_segment} = PathSegment.validate(nil)
      assert {:error, :invalid_github_path_segment} = PathSegment.validate(123)
    end
  end
end
