defmodule Front.MemoryCookie do
  def values(nil) do
    defaults()
  end

  def values(cookie) do
    case Base.decode64(cookie) do
      {:ok, data} ->
        Map.merge(defaults(), Poison.decode!(data))

      _ ->
        defaults()
    end
  end

  defp defaults do
    %{
      "rootSidebar" => false,
      "rootRequester" => true,
      "projectType" => "",
      "projectListing" => "all_pipelines",
      "projectRequester" => "false",
      "logDark" => false,
      "logWrap" => true,
      "logLive" => true,
      "logSticky" => true,
      "logTimestamps" => true
    }
  end
end
