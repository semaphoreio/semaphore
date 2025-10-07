defmodule Front.Models.Pipeline.Triggerer do
  alias __MODULE__
  alias InternalApi.Plumber.Pipeline.Result, as: PplResult
  alias InternalApi.Plumber.TriggeredBy, as: PplTriggeredBy
  alias InternalApi.PlumberWF.TriggeredBy, as: WfTriggeredBy

  @type triggered_by ::
          {:hook, hook_id :: String.t()}
          | {:workflow, workflow_id :: String.t()}
          | {:pipeline, pipeline_id :: String.t()}
          | {:task, {task_id :: String.t(), task_name :: String.t()}}
          | :none

  @type user ::
          {:name, git_user_name :: String.t()}
          | {:user, {user_id :: String.t(), user_name :: String.t()}}
          | :none

  @type trigger_type ::
          :INITIAL_WORKFLOW
          | :WORKFLOW_RERUN
          | :API
          | :SCHEDULED_RUN
          | :SCHEDULED_MANUAL_RUN
          | :PIPELINE_PARTIAL_RERUN
          | :MANUAL_PROMOTION
          | :AUTO_PROMOTION

  @type t :: %Triggerer{
          trigger_type: trigger_type(),
          triggered_by: triggered_by(),
          is_terminated?: boolean(),
          terminated_by: user(),
          git_user: String.t(),
          git_avatar_url: String.t(),
          owner: user()
        }

  defstruct [
    :trigger_type,
    :triggered_by,
    :is_terminated?,
    :terminated_by,
    :git_user,
    :git_avatar_url,
    :owner
  ]

  @spec construct(InternalApi.Plumber.Pipeline.t()) :: t()
  def construct(pipeline) do
    {trigger_type, triggered_by} = detect_trigger(pipeline)
    {is_terminated?, terminated_by} = detect_termination(pipeline)
    {git_user, git_avatar_url} = detect_git_user(pipeline)
    owner = detect_owner(pipeline, trigger_type)

    %Triggerer{
      trigger_type: trigger_type,
      triggered_by: triggered_by,
      is_terminated?: is_terminated?,
      terminated_by: terminated_by,
      git_user: git_user,
      git_avatar_url: git_avatar_url,
      owner: owner
    }
  end

  @spec users_to_preload(t()) :: [user()]
  def users_to_preload(triggerer) do
    [
      triggerer.owner,
      triggerer.terminated_by
    ]
    |> Enum.filter(fn
      {:user, {_, name}} when name == "" -> true
      _ -> false
    end)
  end

  @spec preload_users(t(), [user()]) :: t()
  def preload_users(triggerer, users) do
    triggerer
    |> preload_user(:owner, users)
    |> preload_user(:terminated_by, users)
  end

  @spec preload_user(t(), atom, [user()]) :: t()
  defp preload_user(triggerer, field, users) do
    field_data =
      Map.get(triggerer, field)
      |> case do
        {:user, {user_id, _}} = user_to_preload ->
          users
          |> Enum.find(fn
            {:user, {^user_id, _}} -> true
            _ -> false
          end)
          |> case do
            {:user, _} = preloaded_user -> preloaded_user
            _ -> user_to_preload
          end

        other ->
          other
      end

    Map.put(triggerer, field, field_data)
  end

  @spec detect_owner(InternalApi.Plumber.Pipeline.t(), trigger_type()) :: user()
  defp detect_owner(pipeline, trigger_type) do
    triggerer = pipeline.triggerer

    case trigger_type do
      :INITIAL_WORKFLOW ->
        {:name, triggerer.wf_triggerer_provider_login}

      :API ->
        {:user, {triggerer.wf_triggerer_user_id, ""}}

      :SCHEDULED_RUN ->
        detect_scheduled_run_owner(triggerer)

      :SCHEDULED_MANUAL_RUN ->
        {:user, {triggerer.wf_triggerer_user_id, ""}}

      :PIPELINE_PARTIAL_RERUN ->
        {:user, {triggerer.ppl_triggerer_user_id, ""}}

      :MANUAL_PROMOTION ->
        {:user, {triggerer.ppl_triggerer_user_id, ""}}

      :AUTO_PROMOTION ->
        :none

      :WORKFLOW_RERUN ->
        {:user, {triggerer.ppl_triggerer_user_id, ""}}
    end
  end

  defp detect_scheduled_run_owner(triggerer) do
    PplTriggeredBy.key(triggerer.ppl_triggered_by)
    |> case do
      :PROMOTION ->
        {:user, {triggerer.ppl_triggerer_user_id, ""}}

      _ ->
        :none
    end
  end

  @spec detect_trigger(InternalApi.Plumber.Pipeline.t()) :: {trigger_type(), triggered_by()}
  # # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp detect_trigger(pipeline) do
    triggerer = pipeline.triggerer
    wf_triggered_by = WfTriggeredBy.key(triggerer.wf_triggered_by)
    ppl_triggered_by = PplTriggeredBy.key(triggerer.ppl_triggered_by)

    cond do
      ppl_triggered_by == :PARTIAL_RE_RUN ->
        {:PIPELINE_PARTIAL_RERUN, {:pipeline, triggerer.ppl_triggerer_id}}

      ppl_triggered_by == :PROMOTION ->
        {:MANUAL_PROMOTION, :none}

      ppl_triggered_by == :AUTO_PROMOTION ->
        {:AUTO_PROMOTION, :none}

      triggerer.workflow_rerun_of != "" ->
        {:WORKFLOW_RERUN, {:workflow, triggerer.workflow_rerun_of}}

      wf_triggered_by == :API ->
        {:API, :none}

      wf_triggered_by == :SCHEDULE ->
        {:SCHEDULED_RUN, {:task, {triggerer.wf_triggerer_id, ""}}}

      wf_triggered_by == :MANUAL_RUN ->
        {:SCHEDULED_MANUAL_RUN, {:task, {triggerer.wf_triggerer_id, ""}}}

      wf_triggered_by == :HOOK && ppl_triggered_by == :WORKFLOW ->
        {:INITIAL_WORKFLOW, {:hook, triggerer.wf_triggerer_id}}

      true ->
        {:INITIAL_WORKFLOW, {:hook, triggerer.wf_triggerer_id}}
    end
  end

  @spec detect_termination(InternalApi.Plumber.Pipeline.t()) :: {boolean(), user()}
  defp detect_termination(pipeline) do
    terminated_by = pipeline.terminated_by
    pipeline_result = PplResult.key(pipeline.result)

    cond do
      terminated_by == "admin" or terminated_by == "branch deletion" ->
        {true, {:name, terminated_by}}

      is_uuid?(terminated_by) ->
        {true, {:user, {terminated_by, ""}}}

      terminated_by != "" ->
        {true, :none}

      pipeline_result == :STOPPED ->
        {true, :none}

      pipeline_result == :CANCELED ->
        {true, :none}

      true ->
        {false, :none}
    end
  end

  @spec detect_git_user(InternalApi.Plumber.Pipeline.t()) :: {String.t(), String.t()}
  defp detect_git_user(pipeline) do
    git_user = pipeline.triggerer.wf_triggerer_provider_login
    git_avatar_url = pipeline.triggerer.wf_triggerer_provider_avatar

    {git_user, git_avatar_url}
  end

  @spec is_uuid?(String.t()) :: boolean()
  defp is_uuid?(value) do
    UUID.info(value)
    |> case do
      {:ok, _} -> true
      _ -> false
    end
  end
end
