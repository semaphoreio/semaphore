defmodule HooksReceiver.Hook.BitbucketFilter do
  @moduledoc """
  Checks if bitbucket hook type of the delievered payload is supported
  """

  require Logger

  @event_header "x-event-key"
  @webhooks_version "user-agent"

  @supported_triggers [
    "repo:push",
    "pullrequest:fulfilled",
    "pullrequest:created",
    "pullrequest:rejected",
    "pullrequest:comment_created"
  ]

  def supported?(req_headers) do
    log_bb_version(req_headers)

    Enum.member?(@supported_triggers, get_header(req_headers, @event_header))
  end

  defp log_bb_version(req_headers) do
    req_headers
    |> get_header(@webhooks_version)
    |> tap(fn version -> Logger.debug("Bitbucket webhook version: #{inspect(version)}") end)
  end

  defp get_header(req_headers, header) do
    req_headers
    |> Enum.into(%{})
    |> Map.get(header)
  end
end
