defmodule Front.DebugSessionsDescription do
  @translations %{
    "allow_attach_default_branch" => "default branch",
    "allow_attach_forked_pr" => "forked pull requests",
    "allow_attach_non_default_branch" => "non default branches",
    "allow_attach_pr" => "pull requests",
    "allow_attach_tag" => "tags",
    "allow_debug_default_branch" => "default branch",
    "allow_debug_empty_session" => "empty sessions",
    "allow_debug_forked_pr" => "forked pull requests",
    "allow_debug_non_default_branch" => "non default branches",
    "allow_debug_pr" => "pull requests",
    "allow_debug_tag" => "tags"
  }

  def description(params = %{"custom_permissions" => "true"}) do
    debugs = params |> selected() |> by_action("allow_debug") |> mapped_keys()
    attaches = params |> selected() |> by_action("allow_attach") |> mapped_keys()

    debug_description(debugs, attaches)
  end

  def description(%{"custom_permissions" => "false"}),
    do: "Debug sessions are set to follow organization defaults."

  def description(_), do: "Debug session restrictions did not change."

  defp debug_description([], []), do: "Changed debug session restrictions. Everything is blocked."

  defp debug_description(debugs, []) do
    "Changed debug session restrictions. It can be used to debug the #{sentence(debugs)}."
  end

  defp debug_description([], attaches) do
    "Changed debug session restrictions. It can be used to attach to the #{sentence(attaches)}."
  end

  defp debug_description(debugs, attaches) do
    "Changed debug session restrictions. It can be used to debug the #{sentence(debugs)}. And attach to the #{sentence(attaches)}."
  end

  defp selected(params) do
    Enum.filter(params, fn {_, v} -> v == "true" end)
  end

  defp by_action(params, action) do
    Enum.filter(params, fn {k, _} -> String.starts_with?(k, action) end)
  end

  defp mapped_keys(params) do
    Enum.map(params, fn {k, _} -> @translations[k] end)
  end

  defp sentence(list) do
    [h | t] = list
    do_sentence(t, h)
  end

  defp do_sentence([], acc) do
    acc
  end

  defp do_sentence([h | t], acc) when t == [] do
    result = "#{acc} and #{h}"
    do_sentence(t, result)
  end

  defp do_sentence([h | t], acc) do
    result = "#{acc}, #{h}"
    do_sentence(t, result)
  end
end
