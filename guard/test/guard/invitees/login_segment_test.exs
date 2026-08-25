defmodule Guard.Invitees.LoginSegmentTest do
  use ExUnit.Case, async: true

  alias Guard.Invitees.LoginSegment

  describe ".validate/1 with legitimate GitHub/GitLab logins" do
    test "accepts a typical login" do
      assert {:ok, "radwo"} = LoginSegment.validate("radwo")
    end

    test "accepts logins with hyphens, underscores, and dots" do
      assert {:ok, "semaphore-ci"} = LoginSegment.validate("semaphore-ci")
      assert {:ok, "radwo_gitlab"} = LoginSegment.validate("radwo_gitlab")
      assert {:ok, "my.login"} = LoginSegment.validate("my.login")
    end

    test "accepts a numeric-looking login" do
      assert {:ok, "12345"} = LoginSegment.validate("12345")
    end

    test "accepts realistic usernames mixing letters, digits, and separators" do
      assert {:ok, "radwo-the.dev"} = LoginSegment.validate("radwo-the.dev")
      assert {:ok, "some_user"} = LoginSegment.validate("some_user")
      assert {:ok, "a-b-c-1"} = LoginSegment.validate("a-b-c-1")
      assert {:ok, "radwo-the.dev_gitlab"} = LoginSegment.validate("radwo-the.dev_gitlab")
    end
  end

  describe ".validate/1 with hostile or malformed input" do
    test "rejects CRLF (request-splitting payload)" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("x\r\nX-Injected: yes")
    end

    test "rejects a bare LF" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("foo\nbar")
    end

    test "rejects a bare CR" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("foo\rbar")
    end

    test "rejects an embedded space" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("foo bar")
    end

    test "rejects other control characters" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("foo" <> <<0x07>> <> "bar")
    end

    test "rejects an embedded path separator" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("foo/../bar")
    end

    test "rejects an embedded query delimiter" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("radwo?evil=1")
    end

    test "rejects an embedded fragment delimiter" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("radwo#fragment")
    end

    test "rejects a query-parameter smuggling payload" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("radwo&username=admin")
    end

    test "rejects an ampersand" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("foo&bar")
    end

    test "rejects an equals sign" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("foo=bar")
    end

    test "rejects a semicolon" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("foo;bar")
    end

    test "rejects an at sign" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("foo@bar")
    end

    test "rejects a percent sign" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("foo%2Fbar")
    end

    test "rejects a trailing newline (PCRE $ bypass)" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("radwo\n")
    end

    test "rejects the empty string" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate("")
    end

    test "rejects non-string input" do
      assert {:error, :invalid_login_segment} = LoginSegment.validate(nil)
      assert {:error, :invalid_login_segment} = LoginSegment.validate(123)
    end
  end
end
