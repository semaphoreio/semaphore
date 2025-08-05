defmodule Notifications.Workers.Coordinator.Filter do
  import Ecto.Query
  alias Notifications.Models.Rule
  alias Notifications.Repo

  def find_rules(org_id, project, branch, pr_branch, pipeline, result) do
    Rule
    |> where([r], r.org_id == ^org_id)
    |> with_pattern(project, "project")
    |> with_pattern([branch, pr_branch], "branch")
    |> with_pattern(pipeline, "pipeline")
    |> with_pattern(result, "result")
    |> preload(:notification)
    |> Repo.all()
  end

  defp with_pattern(query, [actual_value, ""], pattern_type) do
    with_pattern(query, actual_value, pattern_type)
  end

  defp with_pattern(query, [actual_value1, actual_value2], pattern_type) do
    query
    |> where(
      [r],
      fragment(
        """
         EXISTS (
             SELECT id
             FROM patterns
             WHERE patterns.rule_id = r0.id AND patterns.type = ? AND (
               CASE
               WHEN patterns.regex IS FALSE AND (? = patterns.term OR ? = patterns.term) THEN true
               WHEN patterns.regex IS TRUE  AND (? ~ patterns.term OR ? ~ patterns.term) THEN true
               ELSE false
               END
             )
           )
        """,
        ^pattern_type,
        ^actual_value1,
        ^actual_value2,
        ^actual_value1,
        ^actual_value2
      )
    )
  end

  defp with_pattern(query, actual_value, pattern_type) do
    query
    |> where(
      [r],
      fragment(
        """
         EXISTS (
             SELECT id
             FROM patterns
             WHERE patterns.rule_id = r0.id AND patterns.type = ? AND (
               CASE
               WHEN patterns.regex IS FALSE AND ? = patterns.term THEN true
               WHEN patterns.regex IS TRUE  AND ? ~ patterns.term THEN true
               ELSE false
               END
             )
           )
        """,
        ^pattern_type,
        ^actual_value,
        ^actual_value
      )
    )
  end
end
