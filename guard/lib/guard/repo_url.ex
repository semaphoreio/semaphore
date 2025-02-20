# TMP solution, we will need to fetch this info from RepositoryHub
defmodule Guard.RepoUrl do
  def map_provider(url) do
    url_with_no_trailing_git = url |> String.replace(~r/\.git$/, "")

    captures =
      Regex.named_captures(
        supported_git_formats(),
        url_with_no_trailing_git
      )

    if captures do
      cond do
        String.contains?(captures["host"], "github.com") -> "github"
        String.contains?(captures["host"], "bitbucket.org") -> "bitbucket"
        String.contains?(captures["host"], "gitlab.com") -> "gitlab"
        true -> "github"
      end
    else
      "github"
    end
  end

  defp supported_git_formats do
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    ~r/(?<protocol>(http:\/\/|https:\/\/|git:\/\/|ssh:\/\/))?(?<username>[^@ ]+@)?(?<host>[^\/: ]+)[\/:]*(?<owner>[^\/ ]+)\/(?<repo>[^\/ ]+)/
  end
end
