defmodule Front.Browser.ProjectSettings.ArtifactsTest do
  use FrontWeb.WallabyCase

  @project_policies Query.data("container", "project-policies")
  @workflow_policies Query.data("container", "workflow-policies")
  @job_policies Query.data("container", "job-policies")

  @add_policy_link Query.css("a", text: "+ Add retention policy")
  @last_input_field Query.css("[data-name=input-form]:last-child input")
  @last_select_field Query.css("[data-name=input-form]:last-child select")
  @max_rules_message Query.css("span", text: "You can have at most 10 rules.")

  setup data do
    stubs = Support.Browser.ProjectSettings.create_project()
    context = Map.merge(data, stubs)

    {:ok, context}
  end

  browser_test "adding and removing policies", params do
    alias InternalApi.Artifacthub.RetentionPolicy, as: Policy
    alias InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule, as: Rule

    Support.Stubs.Feature.enable_feature(params.org.id, :permission_patrol)
    Support.Stubs.PermissionPatrol.allow_everything(params.org.id, params.user.id)

    params
    |> open()
    |> add_policy(@project_policies, "/test-results/**/*", "1 week")
    |> add_policy(@workflow_policies, "/**/*", "1 month")
    |> add_policy(@workflow_policies, "/hello/**/*", "1 year")
    |> add_policy(@workflow_policies, "/hello-world/**/*", "5 years")
    |> add_policy(@job_policies, "/hello/**/*", "1 month")
    |> save()

    expected_policy =
      Policy.new(
        project_level_retention_policies: [
          Rule.new(selector: "/test-results/**/*", age: 7 * 24 * 3600)
        ],
        workflow_level_retention_policies: [
          Rule.new(selector: "/**/*", age: 30 * 24 * 3600),
          Rule.new(selector: "/hello/**/*", age: 365 * 24 * 3600),
          Rule.new(selector: "/hello-world/**/*", age: 5 * 365 * 24 * 3600)
        ],
        job_level_retention_policies: [
          Rule.new(selector: "/hello/**/*", age: 30 * 24 * 3600)
        ]
      )

    assert_policy_saved(expected_policy)

    params
    |> open()
    |> remove_policy(@workflow_policies, index: 0)
    |> save()

    expected_policy =
      Policy.new(
        project_level_retention_policies: [
          Rule.new(selector: "/test-results/**/*", age: 7 * 24 * 3600)
        ],
        workflow_level_retention_policies: [
          Rule.new(selector: "/hello/**/*", age: 365 * 24 * 3600),
          Rule.new(selector: "/hello-world/**/*", age: 5 * 365 * 24 * 3600)
        ],
        job_level_retention_policies: [
          Rule.new(selector: "/hello/**/*", age: 30 * 24 * 3600)
        ]
      )

    assert_policy_saved(expected_policy)
  end

  browser_test "deleting all policies on a project", params do
    alias InternalApi.Artifacthub.RetentionPolicy, as: Policy
    alias InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule, as: Rule

    Support.Stubs.Feature.enable_feature(params.org.id, :permission_patrol)
    Support.Stubs.PermissionPatrol.allow_everything(params.org.id, params.user.id)

    params
    |> open()
    |> add_policy(@project_policies, "/test-results/**/*", "1 week")
    |> save()

    params
    |> open()
    |> remove_policy(@project_policies, index: 0)
    |> save()

    expected_policy =
      Policy.new(
        project_level_retention_policies: [],
        workflow_level_retention_policies: [],
        job_level_retention_policies: []
      )

    assert_policy_saved(expected_policy)
  end

  browser_test "empty rules are ignored", params do
    alias InternalApi.Artifacthub.RetentionPolicy, as: Policy
    alias InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule, as: Rule

    Support.Stubs.Feature.enable_feature(params.org.id, :permission_patrol)
    Support.Stubs.PermissionPatrol.allow_everything(params.org.id, params.user.id)

    params
    |> open()
    |> add_policy(@project_policies, "/test-results/**/*", "1 week")
    |> add_policy(@workflow_policies, "", "1 month")
    |> add_policy(@workflow_policies, "/hello/**/*", "1 year")
    |> add_policy(@job_policies, "/hello/**/*", "1 month")
    |> save()

    expected_policy =
      Policy.new(
        project_level_retention_policies: [
          Rule.new(selector: "/test-results/**/*", age: 7 * 24 * 3600)
        ],
        workflow_level_retention_policies: [
          Rule.new(selector: "/hello/**/*", age: 365 * 24 * 3600)
        ],
        job_level_retention_policies: [
          Rule.new(selector: "/hello/**/*", age: 30 * 24 * 3600)
        ]
      )

    assert_policy_saved(expected_policy)
  end

  browser_test "hitting the max limit for the number of defined policies", params do
    Support.Stubs.Feature.enable_feature(params.org.id, :permission_patrol)
    Support.Stubs.PermissionPatrol.allow_everything(params.org.id, params.user.id)

    page = open(params)

    Enum.each(1..9, fn _ ->
      add_policy(page, @project_policies, "/test-results/**/*", "1 week")
    end)

    find(page, @project_policies, fn section ->
      assert_has(section, @add_policy_link)
      refute_has(section, @max_rules_message)
    end)

    page |> add_policy(@project_policies, "/test-results/**/*", "1 week")

    find(page, @project_policies, fn section ->
      refute_has(section, @add_policy_link)
      assert_has(section, @max_rules_message)
    end)
  end

  defp last_saved_policy do
    Support.Stubs.DB.last(:artifacts_retention_policies).api_model
  end

  defp assert_policy_saved(expected_policy) do
    assert_eventually(fn ->
      assert last_saved_policy() == expected_policy
    end)
  end

  defp assert_eventually(fun, attempts \\ 20)
  defp assert_eventually(fun, 0), do: fun.()

  defp assert_eventually(fun, attempts) do
    fun.()
  rescue
    _error in [ExUnit.AssertionError, KeyError] ->
      Process.sleep(100)
      assert_eventually(fun, attempts - 1)
  end

  defp save(page) do
    page
    |> execute_script("window.confirm = function(){return true;}")
    |> click(Query.css("button", text: "Save changes"))
  end

  defp add_policy(page, section_selector, pattern, age) do
    find(page, section_selector, fn section ->
      section
      |> click(@add_policy_link)
      |> fill_in(@last_input_field, with: pattern)
      |> find(@last_select_field, fn select ->
        select |> click(Query.option(age))
      end)
    end)
  end

  defp remove_policy(page, section_selector, index: index) do
    find(page, section_selector, fn section ->
      input_forms = all(section, Query.data("name", "input-form"))
      input_form = Enum.at(input_forms, index)

      input_form |> click(Query.data("action", "remove-retention-policy"))
    end)
  end

  defp open(params) do
    path = "/projects/#{params.project.name}/settings/artifacts"

    params.session |> visit(path)
  end
end
