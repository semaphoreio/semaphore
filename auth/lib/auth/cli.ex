defmodule Auth.Cli do
  @doc """
  Helpers for verifying and rejecting calls if the CLI client is deprecated.

  Example usage:

    if call_from_deprecated_cli?(conn) do
      reject_cli_client(conn)
    end
  """

  @min_cli_version %{
    major: 0,
    minor: 30,
    patch: 0
  }

  # sobelow_skip ["XSS.SendResp"]
  def reject_cli_client(conn) do
    upgrade = "curl https://storage.googleapis.com/sem-cli-releases/get.sh | bash"

    msg =
      Enum.join(
        [
          "Call rejected because the client is outdated.",
          "To continue, upgrade Semaphore CLI with '#{upgrade}'."
        ],
        " "
      )

    Plug.Conn.send_resp(conn, 400, Jason.encode!(%{message: msg}))
  end

  def call_from_deprecated_cli?(conn) do
    #
    # If the call is coming from a recent cli, version >= 0.16,
    # it will include the SemaphoreCLI user agent. We can use the info
    # from the user-agent to determine if version is still ok.
    #
    case sem_cli_version(conn) do
      {:ok, version} ->
        version_deprecated?(version)

      _ ->
        false
    end
  end

  def sem_cli?(conn) do
    case sem_cli_version(conn) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp sem_cli_version(conn) do
    user_agent =
      case Plug.Conn.get_req_header(conn, "user-agent") do
        [ua | _] -> ua
        _ -> ""
      end

    if user_agent =~ ~r/^SemaphoreCLI.*/ do
      case parse_user_agent(user_agent) do
        {:ok, version} -> {:ok, version}
        _ -> {:error, :not_sem_cli}
      end
    else
      {:error, :not_sem_cli}
    end
  end

  def version_deprecated?("dev"), do: false

  def version_deprecated?(version) do
    case parse_semantic_version(version) do
      {:ok, [major, minor, patch]} ->
        major < @min_cli_version.major ||
          minor < @min_cli_version.minor ||
          patch < @min_cli_version.patch

      _ ->
        false
    end
  end

  def parse_user_agent(user_agent) do
    case Regex.scan(~r/^SemaphoreCLI\/(.*) \(.*\)/, user_agent) do
      [[_, version]] ->
        {:ok, version}

      _ ->
        {:error, "Unknown format"}
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
end
