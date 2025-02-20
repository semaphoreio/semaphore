defmodule Notifications.Workers.Coordinator.FilterTest do
  use Notifications.DataCase

  alias Notifications.Workers.Coordinator.Filter
  alias Notifications.Models.Rule
  alias Notifications.Models.Pattern
  alias Notifications.Repo

  def create_rule(name, org_id \\ nil) do
    Repo.insert!(%Rule{name: name, org_id: org_id || Ecto.UUID.generate()})
  end

  def create_pattern(rule, type, is_regex, term) do
    Repo.insert!(%Pattern{
      org_id: rule.org_id,
      rule_id: rule.id,
      type: type,
      regex: is_regex,
      term: term
    })
  end

  def names(rules) do
    rules |> Enum.map(& &1.name) |> Enum.sort()
  end

  describe "org filter" do
    test "it filters by organization" do
      org1 = Ecto.UUID.generate()
      org2 = Ecto.UUID.generate()

      r1 = create_rule("A", org1)
      r2 = create_rule("B", org1)
      r3 = create_rule("C", org2)

      # match everything
      create_pattern(r1, "project", true, ".*")
      create_pattern(r1, "branch", true, ".*")
      create_pattern(r1, "pipeline", true, ".*")
      create_pattern(r1, "result", true, ".*")

      # match everything
      create_pattern(r2, "project", true, ".*")
      create_pattern(r2, "branch", true, ".*")
      create_pattern(r2, "pipeline", true, ".*")
      create_pattern(r2, "result", true, ".*")

      # match everything
      create_pattern(r3, "project", true, ".*")
      create_pattern(r3, "branch", true, ".*")
      create_pattern(r3, "pipeline", true, ".*")
      create_pattern(r3, "result", true, ".*")

      assert names(Filter.find_rules(org1, "cli", "master", "", "prod.yml", "passed")) == [
               "A",
               "B"
             ]

      assert names(Filter.find_rules(org2, "cli", "master", "", "prod.yml", "failed")) == ["C"]
    end
  end

  describe "filter by project" do
    test "exact match" do
      org = Ecto.UUID.generate()
      r = create_rule("A", org)

      create_pattern(r, "project", false, "cli")

      # match every branch/pipeline/result
      create_pattern(r, "branch", true, ".*")
      create_pattern(r, "pipeline", true, ".*")
      create_pattern(r, "result", true, ".*")

      assert names(Filter.find_rules(org, "api", "master", "", "prod.yml", "passed")) == []
      assert names(Filter.find_rules(org, "cli", "master", "", "prod.yml", "passed")) == ["A"]
    end

    test "regex match" do
      org = Ecto.UUID.generate()
      r = create_rule("A", org)

      create_pattern(r, "project", true, "s2.*")

      # match every branch/pipeline/result
      create_pattern(r, "branch", true, ".*")
      create_pattern(r, "pipeline", true, ".*")
      create_pattern(r, "result", true, ".*")

      assert names(Filter.find_rules(org, "s2-123", "master", "", "prod.yml", "passed")) == ["A"]
      assert names(Filter.find_rules(org, "api", "master", "", "prod.yml", "passed")) == []
    end
  end

  describe "filter by branch" do
    test "exact match" do
      org = Ecto.UUID.generate()
      r = create_rule("A", org)

      create_pattern(r, "branch", false, "master")

      # match every project/pipeline/result
      create_pattern(r, "project", true, ".*")
      create_pattern(r, "pipeline", true, ".*")
      create_pattern(r, "result", true, ".*")

      assert names(Filter.find_rules(org, "api", "master", "", "prod.yml", "passed")) == ["A"]
      assert names(Filter.find_rules(org, "api", "staging", "", "prod.yml", "passed")) == []

      assert names(
               Filter.find_rules(org, "api", "pull-request-54348", "master", "prod.yml", "passed")
             ) == ["A"]
    end

    test "regex match" do
      org = Ecto.UUID.generate()
      r = create_rule("A", org)

      create_pattern(r, "branch", true, "staging-.*")

      # match every project/pipeline/result
      create_pattern(r, "project", true, ".*")
      create_pattern(r, "pipeline", true, ".*")
      create_pattern(r, "result", true, ".*")

      assert names(Filter.find_rules(org, "api", "staging-123", "", "prod.yml", "passed")) == [
               "A"
             ]

      assert names(Filter.find_rules(org, "api", "master", "", "prod.yml", "passed")) == []

      assert names(
               Filter.find_rules(
                 org,
                 "api",
                 "pull-request-54348",
                 "staging-123",
                 "prod.yml",
                 "passed"
               )
             ) == ["A"]
    end
  end

  describe "filter by pipeline" do
    test "exact match" do
      org = Ecto.UUID.generate()
      r = create_rule("A", org)

      create_pattern(r, "pipeline", false, "semaphore.yml")

      # match every project/branch/result
      create_pattern(r, "project", true, ".*")
      create_pattern(r, "branch", true, ".*")
      create_pattern(r, "result", true, ".*")

      assert names(Filter.find_rules(org, "api", "master", "", "semaphore.yml", "passed")) == [
               "A"
             ]

      assert names(Filter.find_rules(org, "api", "master", "", "prod.yml", "passed")) == []
    end

    test "regex match" do
      org = Ecto.UUID.generate()
      r = create_rule("A", org)

      create_pattern(r, "pipeline", true, "stg-.*.yml")

      # match every project/branch/result
      create_pattern(r, "project", true, ".*")
      create_pattern(r, "branch", true, ".*")
      create_pattern(r, "result", true, ".*")

      assert names(Filter.find_rules(org, "api", "master", "", "stg-alpha.yml", "passed")) == [
               "A"
             ]

      assert names(Filter.find_rules(org, "api", "master", "", "prod.yml", "passed")) == []
    end
  end

  describe "filter by result" do
    test "exact match" do
      org = Ecto.UUID.generate()
      r = create_rule("A", org)

      create_pattern(r, "result", false, "failed")

      # match every project/branch/pipeline
      create_pattern(r, "project", true, ".*")
      create_pattern(r, "branch", true, ".*")
      create_pattern(r, "pipeline", true, ".*")

      assert names(Filter.find_rules(org, "api", "master", "", "semaphore.yml", "failed")) == [
               "A"
             ]

      assert names(Filter.find_rules(org, "api", "master", "", "prod.yml", "passed")) == []
    end

    test "regex match" do
      org = Ecto.UUID.generate()
      r = create_rule("A", org)

      create_pattern(r, "result", true, "^(?:passed|stopped)$")

      # match every project/branch/pipeline
      create_pattern(r, "project", true, ".*")
      create_pattern(r, "branch", true, ".*")
      create_pattern(r, "pipeline", true, ".*")

      assert names(Filter.find_rules(org, "api", "master", "", "prod.yml", "failed")) == []
      assert names(Filter.find_rules(org, "api", "master", "", "prod.yml", "exited")) == []
      assert names(Filter.find_rules(org, "api", "master", "", "stg.yml", "passed")) == ["A"]
      assert names(Filter.find_rules(org, "api", "master", "", "stg.yml", "stopped")) == ["A"]
    end
  end

  test "prevent poisonous false regex matching" do
    #
    # SQL doesn't have AND/OR short circuiting, and the order of subqueries is
    # not guaranteed.
    #
    # Example:
    #
    #   WHERE
    #     pattern.rule_id == rule.id AND
    #     (pattern.regex TRUE AND ? ~ pattern.term)
    #
    # The subqueries:
    #  - pattern.rule_id == rule.id
    #  - (pattern.regex TRUE AND ? ~ pattern.term)
    #
    # Will be executed in parallel.
    #

    org1 = Ecto.UUID.generate()
    org2 = Ecto.UUID.generate()

    r1 = create_rule("A", org1)
    r2 = create_rule("B", org2)

    # first create pattern with invalid regex
    create_pattern(r2, "project", false, "*")

    create_pattern(r1, "project", false, "a")
    create_pattern(r1, "branch", true, ".*")
    create_pattern(r1, "pipeline", true, ".*")
    create_pattern(r1, "block", true, ".*")
    create_pattern(r1, "result", true, ".*")

    assert names(Filter.find_rules(org1, "a", "stg", "", "semaphore.yml", "passed")) == ["A"]
  end
end
