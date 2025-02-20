defmodule Gofer.Deployment.Guardian do
  @moduledoc """
  Keeps access to deployment to allowed users
  """

  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Switch.Model.Switch
  alias Gofer.RBAC

  @doc """
    Verifies than given user is allowed to run deployment from given switch

    Returns:
    - {:ok, metadata} when access is granted
    - {:error, {reason, metadata}} when access is denied

    Reasons:
    - :BANNED_SUBJECT     - user has no access to deployment target
    - :BANNED_OBJECT      - deployment target cannot deploy from pipeline
    - :SYNCING_TARGET     - deployment target is in syncing state
    - :CORDONED_TARGET    - deployment target is cordoned
    - :CORRUPTED_TARGET   - deployment target has failed to synchronize secret

    Metadata:
    - git_ref_type        - git reference type (BRANCH/TAG/PR)
    - label               - git reference label (branch name, tag alias, PR number)
    - deployment_id       - deployment target ID
    - deployment_name     - deployment target name
    - triggerer           - user ID (for manual promotion)
                            or "Pipeline Done request" (for auto-promotions)
  """
  def verify(deployment, switch, triggerer, opts \\ [])

  def verify(deployment, switch, triggerer = nil, _opts),
    do: {:error, {:BANNED_SUBJECT, metadata_from(deployment, switch, triggerer)}}

  def verify(deployment, switch, triggerer = "", _opts),
    do: {:error, {:BANNED_SUBJECT, metadata_from(deployment, switch, triggerer)}}

  def verify(deployment = %Deployment{state: :SYNCING}, switch, triggerer, _opts),
    do: {:error, {:SYNCING_TARGET, metadata_from(deployment, switch, triggerer)}}

  def verify(deployment = %Deployment{result: :FAILURE}, switch, triggerer, _opts),
    do: {:error, {:CORRUPTED_TARGET, metadata_from(deployment, switch, triggerer)}}

  def verify(deployment = %Deployment{}, switch, triggerer, opts) do
    %Deployment{subject_rules: sub_rules, object_rules: obj_rules} = deployment
    subject = subject_for_deployment(deployment, triggerer)
    metadata = metadata_from(deployment, switch, triggerer)

    cond do
      is_nil(triggerer) or triggerer == "" -> {:error, {:BANNED_SUBJECT, metadata}}
      deployment.cordoned -> {:error, {:CORDONED_TARGET, metadata}}
      deployment.state == :SYNCING -> {:error, {:SYNCING_TARGET, metadata}}
      deployment.result == :FAILURE -> {:error, {:CORRUPTED_TARGET, metadata}}
      not object_rules_apply?(obj_rules, switch, opts) -> {:error, {:BANNED_OBJECT, metadata}}
      not subject_rules_apply?(sub_rules, subject, opts) -> {:error, {:BANNED_SUBJECT, metadata}}
      true -> {:ok, metadata}
    end
  end

  defp subject_for_deployment(deployment, triggerer) do
    %RBAC.Subject{
      organization_id: deployment.organization_id,
      project_id: deployment.project_id,
      triggerer: triggerer
    }
  end

  defp metadata_from(deployment, switch = %Switch{}, triggerer) do
    metadata_from(deployment, {switch.git_ref_type, switch.label}, triggerer)
  end

  defp metadata_from(deployment, {git_ref_type, git_ref_label}, triggerer) do
    [
      git_ref_type: git_ref_type_to_string(git_ref_type),
      deployment_name: deployment.name,
      deployment_id: deployment.id,
      label: git_ref_label,
      triggerer: triggerer
    ]
  end

  defp git_ref_type_to_string(type),
    do: type |> to_string() |> String.downcase()

  # Subject permission checks

  defp subject_rules_apply?(subject_rules, subject, opts) do
    any_rules = Enum.filter(subject_rules, &(&1.type == :ANY))
    auto_rules = Enum.filter(subject_rules, &(&1.type == :AUTO))
    user_rules = Enum.filter(subject_rules, &(&1.type == :USER))
    role_rules = Enum.filter(subject_rules, &(&1.type == :ROLE))

    any_rules_apply?(any_rules, subject, opts) or
      auto_rules_apply?(auto_rules, subject, opts) or
      user_rules_apply?(user_rules, subject, opts) or
      role_rules_apply?(role_rules, subject, opts)
  end

  defp any_rules_apply?(rules, _subject, _opts), do: not Enum.empty?(rules)

  defp auto_rules_apply?(rules, subject, _opts),
    do: not Enum.empty?(rules) and subject.triggerer == "Pipeline Done request"

  defp user_rules_apply?(rules, subject, _opts),
    do: Enum.any?(rules, &(&1.subject_id == subject.triggerer))

  defp role_rules_apply?(rules, subject, opts) do
    role_ids = Enum.map(rules, & &1.subject_id)

    case RBAC.check_roles(subject, role_ids, opts) do
      {:ok, assignments} -> Enum.any?(assignments, &elem(&1, 1))
      {:error, _reason} -> false
    end
  end

  # Object permission checks

  defp object_rules_apply?(object_rules, switch = %Switch{}, opts),
    do: object_rules_apply?(object_rules, {switch.git_ref_type, switch.label}, opts)

  defp object_rules_apply?(object_rules, object = {_git_ref_type, _git_ref_label}, _opts),
    do: Enum.any?(object_rules, &object_rule_applies?(&1, object))

  alias Deployment.ObjectRule

  defp object_rule_applies?(rule = %ObjectRule{type: :BRANCH}, {"branch", label}),
    do: object_rule_applies?(rule.match_mode, rule.pattern, label)

  defp object_rule_applies?(rule = %ObjectRule{type: :BRANCH}, {:BRANCH, label}),
    do: object_rule_applies?(rule.match_mode, rule.pattern, label)

  defp object_rule_applies?(rule = %ObjectRule{type: :TAG}, {"tag", label}),
    do: object_rule_applies?(rule.match_mode, rule.pattern, label)

  defp object_rule_applies?(rule = %ObjectRule{type: :TAG}, {:TAG, label}),
    do: object_rule_applies?(rule.match_mode, rule.pattern, label)

  defp object_rule_applies?(rule = %ObjectRule{type: :PR}, {"pr", label}),
    do: object_rule_applies?(rule.match_mode, rule.pattern, label)

  defp object_rule_applies?(rule = %ObjectRule{type: :PR}, {:PR, label}),
    do: object_rule_applies?(rule.match_mode, rule.pattern, label)

  defp object_rule_applies?(_rule, {_git_ref_type, _label}),
    do: false

  defp object_rule_applies?(:ALL, _pattern, _label), do: true

  defp object_rule_applies?(:EXACT, pattern, label), do: label == pattern

  defp object_rule_applies?(:REGEX, pattern, label) do
    case Regex.compile(pattern) do
      {:ok, regex} -> Regex.match?(regex, label)
      {:error, _reason} -> false
    end
  end
end
