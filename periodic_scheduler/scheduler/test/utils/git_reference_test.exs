defmodule Scheduler.Utils.GitReference.Test do
  use ExUnit.Case
  doctest Scheduler.Utils.GitReference

  alias Scheduler.Utils.GitReference

  describe "normalize/1" do
    test "converts branch name to full reference" do
      assert GitReference.normalize("master") == "refs/heads/master"
      assert GitReference.normalize("develop") == "refs/heads/develop"
      assert GitReference.normalize("feature-branch") == "refs/heads/feature-branch"
    end

    test "leaves full references unchanged" do
      assert GitReference.normalize("refs/heads/master") == "refs/heads/master"
      assert GitReference.normalize("refs/tags/v1.0.0") == "refs/tags/v1.0.0"
      assert GitReference.normalize("refs/pull/123/head") == "refs/pull/123/head"
    end

    test "handles nil input" do
      assert GitReference.normalize(nil) == nil
    end
  end

  describe "extract_name/1" do
    test "extracts branch name from full reference" do
      assert GitReference.extract_name("refs/heads/master") == "master"
      assert GitReference.extract_name("refs/heads/develop") == "develop"
      assert GitReference.extract_name("refs/heads/feature-branch") == "feature-branch"
    end

    test "extracts tag name from full reference" do
      assert GitReference.extract_name("refs/tags/v1.0.0") == "v1.0.0"
      assert GitReference.extract_name("refs/tags/release") == "release"
    end

    test "extracts PR reference from full reference" do
      assert GitReference.extract_name("refs/pull/123/head") == "123/head"
    end

    test "leaves short names unchanged" do
      assert GitReference.extract_name("master") == "master"
      assert GitReference.extract_name("develop") == "develop"
    end

    test "handles nil input" do
      assert GitReference.extract_name(nil) == nil
    end
  end

  describe "build_full_reference/2" do
    test "builds branch references" do
      assert GitReference.build_full_reference("BRANCH", "master") == "refs/heads/master"
      assert GitReference.build_full_reference("BRANCH", "develop") == "refs/heads/develop"
    end

    test "builds tag references" do
      assert GitReference.build_full_reference("TAG", "v1.0.0") == "refs/tags/v1.0.0"
      assert GitReference.build_full_reference("TAG", "release") == "refs/tags/release"
    end

    test "builds PR references" do
      assert GitReference.build_full_reference("PR", "123") == "refs/pull/123/head"
    end

    test "returns name unchanged for unknown types" do
      assert GitReference.build_full_reference("UNKNOWN", "something") == "something"
      assert GitReference.build_full_reference("", "test") == "test"
    end
  end

  describe "get_type/1" do
    test "identifies branch references" do
      assert GitReference.get_type("refs/heads/master") == :branch
      assert GitReference.get_type("refs/heads/develop") == :branch
      # short names assumed to be branches
      assert GitReference.get_type("master") == :branch
    end

    test "identifies tag references" do
      assert GitReference.get_type("refs/tags/v1.0.0") == :tag
      assert GitReference.get_type("refs/tags/release") == :tag
    end

    test "identifies PR references" do
      assert GitReference.get_type("refs/pull/123/head") == :pull_request
    end

    test "handles unknown ref types" do
      assert GitReference.get_type("refs/unknown/something") == :branch
    end

    test "handles nil input" do
      assert GitReference.get_type(nil) == nil
    end
  end
end
