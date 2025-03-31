defmodule RepositoryHub.Model.DeployKeys do
  @moduledoc """
  Deploy keys used to authenticate with a remote repository.
  """

  use RepositoryHub.Repo

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "deploy_keys" do
    field(:public_key, :string)
    field(:private_key_enc, :binary)
    field(:deployed, :boolean, default: false)
    field(:remote_id, :integer)
    field(:project_id, :binary_id)

    field(:repository_id, :binary_id, virtual: true)

    timestamps(inserted_at_source: :created_at, type: :utc_datetime)
  end

  @fields ~w(public_key private_key_enc deployed remote_id project_id repository_id)a
  @required_fields @fields -- [:repository_id]

  def changeset(key, params \\ %{}) do
    key
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end

  def generate_private_public_key_pair do
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

    {private_key, String.trim(public_key)}
  end

  def fingerprint(model) do
    key = model.public_key |> String.replace_prefix("ssh-rsa", "") |> String.trim()
    fingerprint = :crypto.hash(:sha256, Base.decode64!(key)) |> Base.encode64(padding: false)

    "SHA256:#{fingerprint}"
  end
end
