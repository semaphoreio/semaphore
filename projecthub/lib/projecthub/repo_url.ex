defmodule Projecthub.RepoUrl do
  defstruct [:protocol, :username, :host, :owner, :repo, :ssh_git_url]

  def supported_git_formats do
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    ~r/(?<protocol>(http:\/\/|https:\/\/|git:\/\/|ssh:\/\/))?(?<username>[^@ ]+@)?(?<host>[^\/: ]+)[\/:]*(?<owner>[^\/ ]+)\/(?<repo>[^\/ ]+)/
  end

  def validate(url) do
    case validate_format(url) do
      {url_parts, nil} ->
        validate_provider(url_parts)

      {nil, errors} ->
        {:error, errors}
    end
  end

  def equal?(current_url, new_url) do
    case validate(new_url) do
      {:error, errors} ->
        {:error, errors}

      {:ok, url_parts} ->
        {:ok, url_parts.ssh_git_url == current_url}
    end
  end

  defp validate_format(url) do
    url_with_no_trailing_git = url |> String.replace(~r/\.git$/, "")

    captures =
      Regex.named_captures(
        supported_git_formats(),
        url_with_no_trailing_git
      )

    if captures do
      {construct(captures), nil}
    else
      {nil, ["Unrecognized Git remote format '#{url}'"]}
    end
  end

  defp validate_provider(url_parts) do
    cond do
      String.downcase(url_parts.host) == "github.com" ->
        {:ok, url_parts}

      String.downcase(url_parts.host) == "bitbucket.org" ->
        {:ok, url_parts}

      true ->
        {:error, ["Repository host must be GitHub.com or Bitbucket.org"]}
    end
  end

  defp construct(url_parts) do
    host = url_parts["host"]
    owner = url_parts["owner"]
    repo = url_parts["repo"]

    %__MODULE__{
      protocol: url_parts["protocol"],
      username: url_parts["username"],
      host: host,
      owner: owner,
      repo: repo,
      ssh_git_url: "git@#{host}:#{owner}/#{repo}.git"
    }
  end
end
