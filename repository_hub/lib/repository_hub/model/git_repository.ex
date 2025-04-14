defmodule RepositoryHub.Model.GitRepository do
  alias RepositoryHub.Validator
  alias RepositoryHub.Toolkit
  alias __MODULE__

  import Toolkit

  defstruct [:protocol, :username, :host, :owner, :repo, :ssh_git_url]

  @type t :: %GitRepository{}

  def supported_git_formats do
    # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
    ~r/(?<protocol>(http:\/\/|https:\/\/|git:\/\/|ssh:\/\/))?(?<username>[^@ ]+@)?(?<host>[^\/: ]+)[\/:]*(?<owner>[^\/ ]+)\/(?<repo>[^\/ ]+)/
  end

  @doc """
  Validates the git url string and returns a struct with some data about the repository.
  """
  @spec new(String.t()) :: Toolkit.tupled_result(t(), String.t())
  def new(url) do
    dissect(url)
  end

  def from_github(url) do
    url
    |> Validator.validate([:is_github_url])
    |> unwrap(&new/1)
  end

  def from_gitlab(url) do
    url
    |> Validator.validate([:is_gitlab_url])
    |> unwrap(&new/1)
  end

  def from_bitbucket(url) do
    url
    |> Validator.validate([:is_bitbucket_url])
    |> unwrap(&new/1)
  end

  @doc """
  Creates a slug from the git url.
  """
  def slug(git_repository) do
    "#{git_repository.owner}/#{git_repository.repo}"
  end

  @spec equal?(any, binary) :: Toolkit.tupled_result(boolean())
  def equal?(git_repository, new_url) do
    new_url
    |> new()
    |> unwrap(fn new_git_repository ->
      (git_repository.ssh_git_url == new_git_repository.ssh_git_url)
      |> wrap()
    end)
  end

  @spec did_host_change?(any, binary) :: Toolkit.tupled_result(boolean())
  def did_host_change?(git_repository, new_url) do
    new_url
    |> new()
    |> unwrap(fn new_git_repository ->
      (git_repository.host != new_git_repository.host)
      |> wrap()
    end)
  end

  defp dissect(url) do
    url_with_no_trailing_git = url |> String.replace(~r/\.git$/, "")

    supported_git_formats()
    |> Regex.named_captures(url_with_no_trailing_git)
    |> case do
      nil ->
        error("Unrecognized Git remote format '#{url}'")

      captures ->
        construct(captures)
        |> wrap()
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
