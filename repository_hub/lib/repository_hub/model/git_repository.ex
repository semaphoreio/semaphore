defmodule RepositoryHub.Model.GitRepository do
  @allowed_hosts [
    "github.com",
    "bitbucket.org",
    "gitlab.com"
  ]

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
    |> Validator.validate(
      chain: [
        {:from!, :host},
        &host_allowed?/1
      ]
    )
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
    end
  end

  defp host_allowed?(host) when host in @allowed_hosts do
    host
  end

  defp host_allowed?(_) do
    error("Only #{@allowed_hosts |> Enum.join(" and ")} hosts are supported")
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

  defmodule Type do
    alias RepositoryHub.Model.GitRepository
    use Ecto.Type

    def type, do: :map

    def cast(url) when is_bitstring(url), do: GitRepository.new(url)

    def cast(%GitRepository{} = git_repository), do: git_repository

    def cast(_), do: {:error, message: "Is not a github repository"}

    def load(url) when is_bitstring(url) do
      GitRepository.new(url)
    end

    def dump(%GitRepository{ssh_git_url: url}), do: {:ok, url}
    def dump(_), do: :error
  end
end
