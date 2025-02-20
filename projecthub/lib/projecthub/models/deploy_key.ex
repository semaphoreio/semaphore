defmodule Projecthub.Models.DeployKey do
  use Ecto.Schema

  require Logger
  import Ecto.Changeset
  alias Projecthub.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "deploy_keys" do
    belongs_to(:project, Projecthub.Models.Project)

    field(:private_key, :string)
    field(:public_key, :string)
    field(:deployed, :boolean)
    field(:remote_id, :integer)
    field(:created_at, :utc_datetime)
    field(:updated_at, :utc_datetime)
  end

  def create(project) do
    {private_key, public_key} = generate_private_public_key_pair()

    changeset =
      changeset(%__MODULE__{}, %{
        project_id: project.id,
        private_key: private_key,
        public_key: public_key,
        deployed: false,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      })

    Repo.insert(changeset)
  end

  def update(deploy_key, params) do
    changeset =
      changeset(deploy_key, %{
        remote_id: params.remote_id,
        deployed: params.deployed,
        updated_at: DateTime.utc_now()
      })

    Repo.update(changeset)
  end

  def destroy(deploy_key, repo, token) do
    if deploy_key.deployed do
      remove_from_github(deploy_key, repo, token)
    end

    Repo.delete(deploy_key)
  end

  def fingerprint(key) do
    key = key |> String.replace_prefix("ssh-rsa", "") |> String.trim()
    fingerprint = :crypto.hash(:sha256, Base.decode64!(key)) |> Base.encode64(padding: false)

    "SHA256:#{fingerprint}"
  end

  # credo:disable-for-lines:31
  def get_from_github(deploy_key, repo, token) do
    client = Tentacat.Client.new(%{access_token: token})

    response =
      Tentacat.Repositories.DeployKeys.find(
        client,
        repo.owner,
        repo.name,
        deploy_key.remote_id
      )

    case response do
      {200, key, _} ->
        {:ok, %{title: key["title"]}}

      {401, _, _} ->
        {:error, :deploy_key_unauthorized}

      {404, _, %{headers: headers}} ->
        case List.keyfind(headers, "X-OAuth-Scopes", 0) do
          nil ->
            {:error, :deploy_key_no_scope}

          {_, scope} ->
            cond do
              String.starts_with?(scope, "repo") ->
                {:error, :deploy_key_not_found_private}

              String.starts_with?(scope, "public_repo") ->
                {:error, :deploy_key_not_found_public}

              true ->
                {:error, :deploy_key_not_found_non}
            end
        end

      {_, _, resp} ->
        Logger.error("Error while fetching deploy key #{deploy_key.id} on github: #{inspect(resp)}")

        {:error, :deploy_key_not_fetched}
    end
  end

  def remove_from_github(deploy_key, repo, token) do
    client = Tentacat.Client.new(%{access_token: token})

    response =
      Tentacat.Repositories.DeployKeys.remove(
        client,
        repo.owner,
        repo.name,
        deploy_key.remote_id
      )

    case response do
      {204, _, _} ->
        Logger.info("Successfully removed deploy key #{deploy_key.id}")

      {_, _, resp} ->
        Logger.error("Error while deleting deploy key #{deploy_key.id} on github: #{inspect(resp)}")
    end
  end

  def deploy_to_github(deploy_key, project, repo, token) do
    if deploy_key.deployed do
      {:error, "Deploy key already deployed"}
    else
      case post_to_github(deploy_key, project, repo, token) do
        {:ok, remote_id} ->
          __MODULE__.update(deploy_key, %{remote_id: remote_id, deployed: true})

        {:error, messages} ->
          {:error, messages}
      end
    end
  end

  def title(repo, project) do
    "semaphore-#{repo.owner}-#{project.name}"
  end

  defp post_to_github(deploy_key, project, repo, token) do
    client = Tentacat.Client.new(%{access_token: token})

    body = %{
      title: title(repo, project),
      key: deploy_key.public_key,
      read_only: true
    }

    response =
      Tentacat.Repositories.DeployKeys.create(
        client,
        repo.owner,
        repo.name,
        body
      )

    case response do
      {201, key_payload, _} ->
        Logger.info("Deploy key create project #{project.id} response #{inspect(response)}")

        {:ok, key_payload["id"]}

      {404, _, %{headers: headers} = resp} ->
        case List.keyfind(headers, "X-OAuth-Scopes", 0) do
          nil ->
            error(:deploy, deploy_key.id, resp)

          {_, scope} ->
            if String.contains?(scope, "repo") do
              error(:deploy, deploy_key.id, resp)
            else
              {:error,
               "It looks like you haven't authorized Semaphore with GitHub, please visit https://docs.semaphoreci.com/using-semaphore/connect-github#troubleshooting-guide to read more."}
            end
        end

      {_, _, resp} ->
        error(:deploy, deploy_key.id, resp)
    end
  end

  defp error(:deploy, deploy_key_id, resp) do
    Logger.error("Error while creating deploy key #{deploy_key_id} on github: #{inspect(resp)}")

    {:error, "Error while setting deploy key on GitHub. Please contact support."}
  end

  def find_for_project(project_id) do
    case Repo.get_by(__MODULE__, project_id: project_id) do
      nil -> {:error, :not_found}
      deploy_key -> {:ok, deploy_key}
    end
  end

  def changeset(deploy_key, params \\ %{}) do
    deploy_key
    |> cast(params, [
      :private_key,
      :public_key,
      :deployed,
      :remote_id,
      :project_id,
      :created_at,
      :updated_at
    ])
  end

  defp generate_private_public_key_pair do
    File.rm("ssh_key")
    File.rm("ssh_key.pub")

    # generate an ssh key pair, with no passphrase and no comment
    {_, 0} =
      System.cmd("ssh-keygen", [
        "-f",
        "ssh_key",
        "-t",
        "rsa",
        "-b",
        "2048",
        "-P",
        "#{""}",
        "-C",
        "#{""}"
      ])

    {:ok, private_key} = File.read("ssh_key")
    {:ok, public_key} = File.read("ssh_key.pub")

    File.rm!("ssh_key")
    File.rm!("ssh_key.pub")

    {private_key, public_key}
  end
end
