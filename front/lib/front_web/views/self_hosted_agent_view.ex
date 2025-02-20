defmodule FrontWeb.SelfHostedAgentView do
  use FrontWeb, :view

  @latest %{
    major: 2,
    minor: 2,
    patch: 13
  }

  def latest_agent_version, do: "#{@latest.major}.#{@latest.minor}.#{@latest.patch}"

  # We use >= here due to on-premise installations,
  # and new agent versions might be released before the on-premise code is updated.
  def is_latest?(version) do
    case parse_semantic_version(version) do
      {:ok, [major, minor, patch]} ->
        cond do
          major < @latest.major ->
            false

          minor < @latest.minor ->
            major > @latest.major

          patch < @latest.patch ->
            major > @latest.major || minor > @latest.minor

          true ->
            true
        end

      _ ->
        false
    end
  end

  def parse_semantic_version(version) do
    with [[_, major_str, minor_str, patch_str]] <- Regex.scan(~r/^v(.*)\.(.*)\.(.*)/, version),
         {major, _} <- Integer.parse(major_str),
         {minor, _} <- Integer.parse(minor_str),
         {patch, _} <- Integer.parse(patch_str) do
      {:ok, [major, minor, patch]}
    else
      _ -> {:error, "failed to parse version"}
    end
  end

  def new_agent_type_button(conn, no_agent_types) do
    title =
      if no_agent_types do
        "Add your first self-hosted agent"
      else
        "Add a self-hosted agent type"
      end

    if conn.assigns.permissions["organization.self_hosted_agents.manage"] do
      link(title, to: self_hosted_agent_path(conn, :new), class: "btn btn-primary")
    else
      # Dummy disabled button
      """
      <button disabled="true", class="btn btn-primary">#{title}</button>
      """
      |> raw
    end
  end

  def agent_type_submit_button(action) do
    if action == :new do
      "Looks good. Register"
    else
      "Looks good. Update"
    end
  end

  def agent_name_origin(agent_type) do
    alias InternalApi.SelfHosted.AgentNameSettings.AssignmentOrigin

    if agent_type.agent_name_settings.assignment_origin ==
         AssignmentOrigin.value(:ASSIGNMENT_ORIGIN_AGENT) do
      "name is directly chosen by agent when registering."
    else
      info = agent_type.agent_name_settings.aws
      "AWS STS · #{info.account_id} · #{info.role_name_patterns}"
    end
  end

  def agent_release_info(agent_type) do
    if agent_type.agent_name_settings.release_after > 0 do
      "name is available for re-use after #{agent_type.agent_name_settings.release_after} seconds from agent disconnecting."
    else
      "name is available for re-use immediately after agent disconnects."
    end
  end

  def agent_state_color(instance) do
    alias InternalApi.SelfHosted.Agent.State

    cond do
      State.value(:WAITING_FOR_JOB) == instance.state ->
        "bg-washed-green"

      State.value(:RUNNING_JOB) == instance.state ->
        "bg-white"

      true ->
        raise "unknown agent state #{inspect(instance.state)}"
    end
  end
end
