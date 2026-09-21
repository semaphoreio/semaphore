defmodule Projecthub.Models.PeriodicTask.DefinitionTest do
  use ExUnit.Case, async: true

  alias Projecthub.Models.PeriodicTask.Definition

  describe "format_branch_as_reference/1" do
    test "non-empty branch name becomes refs/heads/<branch>" do
      assert Definition.format_branch_as_reference("develop") == "refs/heads/develop"
    end

    test "tag reference is passed through unchanged" do
      assert Definition.format_branch_as_reference("refs/tags/v1.0") == "refs/tags/v1.0"
    end

    test "pull-request reference is passed through unchanged" do
      assert Definition.format_branch_as_reference("refs/pull/42/head") == "refs/pull/42/head"
    end

    test "empty string falls back to refs/heads/master" do
      assert Definition.format_branch_as_reference("") == "refs/heads/master"
    end

    test "nil falls back to refs/heads/master" do
      assert Definition.format_branch_as_reference(nil) == "refs/heads/master"
    end
  end

  describe "status_to_state/1" do
    test ":STATUS_ACTIVE -> :ACTIVE" do
      assert Definition.status_to_state(:STATUS_ACTIVE) == :ACTIVE
    end

    test ":STATUS_INACTIVE -> :PAUSED" do
      assert Definition.status_to_state(:STATUS_INACTIVE) == :PAUSED
    end

    test "anything else -> :UNCHANGED" do
      assert Definition.status_to_state(:STATUS_UNSPECIFIED) == :UNCHANGED
      assert Definition.status_to_state(nil) == :UNCHANGED
    end
  end
end
