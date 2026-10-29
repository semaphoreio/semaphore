defmodule HooksProcessor.Hooks.GitUrl do
  @moduledoc """
  Derives the browsable (web) URL of a repository from the git remote of a
  generic git project. Generic git projects have no repository integration, so
  the remote is the only thing known about the repository:

      ssh://git@git.example.com:2222/team/app.git -> https://git.example.com/team/app
      git@git.example.com:team/app.git            -> https://git.example.com/team/app
      https://git.example.com/team/app.git        -> https://git.example.com/team/app

  The result follows the convention shared by Forgejo, Gitea, Gogs, GitLab and
  GitHub, which all serve the repository at https://<host>/<path>.
  """

  @schemes ["ssh", "git", "http", "https"]
  @scp_like ~r{\A(?:[^@/\s]+@)?(?<host>[^:/\s]+):(?<path>\S+)\z}

  @spec web_url(String.t() | nil) :: String.t() | nil
  def web_url(remote) when is_binary(remote) do
    remote = String.trim(remote)

    case URI.parse(remote) do
      %URI{scheme: scheme, host: host, port: port, path: path}
      when scheme in @schemes and is_binary(host) and host != "" ->
        build(web_scheme(scheme), authority(scheme, host, port), path)

      _ ->
        case Regex.named_captures(@scp_like, remote) do
          %{"host" => host, "path" => path} -> build("https", host, path)
          nil -> nil
        end
    end
  end

  def web_url(_), do: nil

  defp web_scheme("http"), do: "http"
  defp web_scheme(_), do: "https"

  # Only an http(s) remote tells us the port of the web server; the port of an
  # ssh remote is the port of sshd and says nothing about the web UI.
  defp authority(scheme, host, port) when scheme in ["http", "https"] and is_integer(port) do
    if port == URI.default_port(scheme), do: host, else: "#{host}:#{port}"
  end

  defp authority(_scheme, host, _port), do: host

  defp build(scheme, authority, path) do
    segments =
      path
      |> to_string()
      |> String.trim_trailing("/")
      |> String.replace_suffix(".git", "")
      |> String.split("/", trim: true)

    if length(segments) >= 2 do
      "#{scheme}://#{authority}/#{Enum.join(segments, "/")}"
    end
  end
end
