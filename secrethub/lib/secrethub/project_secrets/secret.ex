defmodule Secrethub.ProjectSecrets.Secret do
  use Ecto.Schema

  alias Secrethub.Model.Checkout
  alias Secrethub.Model.Content

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts type: :naive_datetime_usec
  schema "project_level_secrets" do
    field :name, :string
    field :description, :string, default: ""
    field :project_id, :binary_id
    field :org_id, :binary_id

    field :created_by, :string
    field :updated_by, :string
    field :used_at, :utc_datetime

    embeds_one :used_by, Checkout, on_replace: :delete

    # This is a virtual field, because it is not persistent into the DB.
    # This is a field which is computed from the `content_encrypted` one.
    field(:content, :map, virtual: true)
    field(:content_encrypted, :binary, default: nil)

    timestamps()
  end

  @fields ~w(name description project_id content org_id created_by updated_by)a
  @required ~w(name project_id org_id content created_by updated_by)a

  def changeset(secret, params) do
    if Map.has_key?(params, :content) do
      content = Map.get(params, :content)

      case Ecto.Changeset.apply_action(Content.changeset(%Content{}, content), :update) do
        {:ok, content_validated} ->
          params = Map.put(params, :content, content_validated)

          secret
          |> Ecto.Changeset.cast(params, @fields)
          |> Ecto.Changeset.validate_required(@required)
          |> Ecto.Changeset.unique_constraint(:name,
            name: :unique_names_in_project,
            message: "name must be unique in project"
          )
          |> Ecto.Changeset.validate_length(:description, min: 0, max: 255)
          |> Secrethub.Encryptor.encrypt_changeset(params, :content)

        {:error, changeset} ->
          Ecto.Changeset.change(%__MODULE__{})
          |> Ecto.Changeset.add_error(:content, Content.consolidate_changeset_errors(changeset))
      end
    else
      Ecto.Changeset.change(%__MODULE__{})
      |> Ecto.Changeset.add_error(:content, "can't be blank")
    end
  end

  def checkout_changeset(secret, params) do
    secret
    |> Ecto.Changeset.cast(params, [:used_at])
    |> Ecto.Changeset.cast_embed(:used_by, required: true)
    |> Ecto.Changeset.validate_required([:used_at])
  end
end
