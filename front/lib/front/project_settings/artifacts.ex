defmodule Front.ProjectSettings.Artifacts do
  @moduledoc """
  Communication with artifacthub about artifact retention policy.
  This module is used by the project settings / artifacts screen
  to fetch, update and render details about artifact settings.
  """

  def get_settings(project_id) do
    with {:ok, res} <- Front.Models.Artifacthub.describe(project_id, true) do
      {:ok, __MODULE__.JSData.prepare(res.retention_policy)}
    end
  end

  def update_settings(project_id, raw_form_data) do
    with {:ok, policy} <- __MODULE__.FormData.parse(raw_form_data),
         {:ok, res} <- Front.Models.Artifacthub.update_retention_policy(project_id, policy) do
      {:ok, __MODULE__.JSData.prepare(res.retention_policy)}
    end
  end

  def audit_summary(raw_form_data) do
    with {:ok, policy} <- __MODULE__.FormData.parse(raw_form_data) do
      policy
      |> __MODULE__.JSData.prepare()
      |> Poison.encode!()
    end
  end

  defmodule JSData do
    @moduledoc """
    Retention policy prepares data for the JS applicaiton.
    """

    def prepare(retention_policy) do
      %{
        "project" => prepare_rules(retention_policy.project_level_retention_policies),
        "workflow" => prepare_rules(retention_policy.workflow_level_retention_policies),
        "job" => prepare_rules(retention_policy.job_level_retention_policies)
      }
    end

    def prepare_rules(rules) do
      Enum.map(rules, fn r ->
        %{"selector" => r.selector, "age" => r.age}
      end)
    end
  end

  defmodule FormData do
    @moduledoc """
      This module is able to parse the submitted form data when you click
      save changes on the artifacts projects settings.

      The form data has the following format:

      {
        "project" => {
          "age" => [age1, age2, age3],
          "selector" => [selector1, selecto2, selector3]
        },
        "workflow" => {
          "age" => [age1, age2, age3],
          "selector" => [selector1, selecto2, selector3]
        },
        "job" => {
          "age" => [age1, age2, age3],
          "selector" => [selector1, selecto2, selector3]
        }
      }
    """

    alias InternalApi.Artifacthub.RetentionPolicy, as: Policy
    alias InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule, as: Rule

    @spec parse(any()) :: {:ok, Policy.t()} | {:error, String.t()}
    def parse(nil), do: {:ok, new_policy([], [], [])}

    def parse(data) do
      with {:ok, project} <- parse_section(Map.get(data, "project")),
           {:ok, workflow} <- parse_section(Map.get(data, "workflow")),
           {:ok, job} <- parse_section(Map.get(data, "job")) do
        {:ok, new_policy(project, workflow, job)}
      end
    end

    @spec parse_section(any()) :: {:ok, [Policy.t()]}
    defp parse_section(nil), do: {:ok, []}

    defp parse_section(data) do
      selectors = data |> Map.get("selector")
      ages = data |> Map.get("age") |> ages_to_numbers()

      rules =
        Enum.zip(selectors, ages)
        |> Enum.map(&new_rule/1)
        |> remove_rules_with_empty_selectors()

      {:ok, rules}
    end

    defp remove_rules_with_empty_selectors(rules) do
      Enum.filter(rules, fn rule -> rule.selector != "" end)
    end

    defp new_policy(project, workflow, job) do
      Policy.new(
        project_level_retention_policies: project,
        workflow_level_retention_policies: workflow,
        job_level_retention_policies: job
      )
    end

    defp new_rule({selector, age}) do
      Rule.new(selector: selector, age: age)
    end

    defp ages_to_numbers(ages) do
      Enum.map(ages, fn a ->
        {num, _} = Integer.parse(a)
        num
      end)
    end
  end
end
