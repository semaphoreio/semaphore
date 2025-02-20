defmodule HooksReceiver.Hook.GitlabFilter do
  @moduledoc """
  Checks if GitLab hook type of the delievered payload is supported
  """

  require Logger

  @event_header "x-gitlab-event"
  @webhooks_version "user-agent"

  @supported_triggers [
    "Push Hook",
    "Tag Push Hook",
    "Merge Request Hook"
  ]

  def supported?(req_headers) do
    log_gitlab_version(req_headers)

    Enum.member?(@supported_triggers, get_header(req_headers, @event_header))
  end

  defp log_gitlab_version(req_headers) do
    req_headers
    |> get_header(@webhooks_version)
    |> tap(fn version -> Logger.debug("GitLab webhook version: #{inspect(version)}") end)
  end

  defp get_header(req_headers, header) do
    req_headers
    |> Enum.into(%{})
    |> Map.get(header)
  end
end
