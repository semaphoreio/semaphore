defmodule Guard.FrontRepo.Organization do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "organizations" do
    field(:name, :string)
    field(:username, :string)
    field(:creator_id, :binary_id)
    field(:suspended, :boolean)
    field(:open_source, :boolean)
    field(:verified, :boolean)
    field(:restricted, :boolean)
    field(:ip_allow_list, :string)
    field(:allowed_id_providers, :string)
    field(:deny_member_workflows, :boolean)
    field(:deny_non_member_workflows, :boolean)
    field(:settings, :map)

    has_many(:contacts, Guard.FrontRepo.OrganizationContact, on_delete: :delete_all)
    has_many(:suspensions, Guard.FrontRepo.OrganizationSuspension, on_delete: :delete_all)

    has_many(:active_suspensions, Guard.FrontRepo.OrganizationSuspension, where: [deleted_at: nil])

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime_usec)
  end

  @username_regexp ~r/\A(?!-)[a-z0-9\-]{3,}\z/

  @doc false
  def changeset(organization, attrs) do
    organization
    |> Ecto.Changeset.cast(
      attrs,
      [
        :id,
        :name,
        :username,
        :creator_id,
        :suspended,
        :open_source,
        :verified,
        :restricted,
        :ip_allow_list,
        :allowed_id_providers,
        :deny_member_workflows,
        :deny_non_member_workflows,
        :settings,
        :created_at
      ],
      empty_values: []
    )
    |> Ecto.Changeset.validate_required([:name, :username, :creator_id],
      message: "Cannot be empty"
    )
    |> Ecto.Changeset.validate_length(:name, max: 62, message: "Too long")
    |> Ecto.Changeset.validate_length(:username, max: 62, message: "Too long")
    |> Ecto.Changeset.validate_format(:username, @username_regexp,
      message:
        "Use min. 3 characters, only lowercase letters a-z, numbers 0-9 and dash, no spaces."
    )
    |> validate_restricted_username()
    |> Ecto.Changeset.unsafe_validate_unique([:username], Guard.FrontRepo,
      message: "Already taken"
    )
    |> Ecto.Changeset.unique_constraint(:username,
      name: :index_organizations_on_username,
      message: "Already taken"
    )
    |> validate_ip_allow_list()
  end

  defp validate_restricted_username(changeset) do
    username = Ecto.Changeset.get_field(changeset, :username)

    if username && MapSet.member?(restricted_org_usernames(), username) do
      Ecto.Changeset.add_error(changeset, :username, "Already taken")
    else
      changeset
    end
  end

  defp restricted_org_usernames do
    Application.get_env(:guard, :restricted_org_usernames, "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> MapSet.new()
  end

  defp validate_ip_allow_list(changeset) do
    case Ecto.Changeset.get_field(changeset, :ip_allow_list) do
      nil ->
        changeset

      "" ->
        changeset

      ip_list ->
        case validate_ip_list(String.split(ip_list, ",", trim: true)) do
          :ok ->
            changeset

          :error ->
            Ecto.Changeset.add_error(
              changeset,
              :ip_allow_list,
              "IP Allow List should be a comma-separated list of IPs or CIDRs"
            )
        end
    end
  end

  defp validate_ip_list([]), do: :ok

  defp validate_ip_list([ip | rest]) do
    case validate_ip_or_cidr(String.trim(ip)) do
      :ok -> validate_ip_list(rest)
      :error -> :error
    end
  end

  defp validate_ip_or_cidr(ip_or_cidr) do
    case :inet.parse_strict_address(to_charlist(ip_or_cidr)) do
      {:ok, _} ->
        :ok

      {:error, _} ->
        # Try CIDR format if it's not a plain IP
        case String.split(ip_or_cidr, "/") do
          [ip, mask] ->
            with {:ok, _} <- :inet.parse_address(to_charlist(ip)),
                 {mask_int, ""} <- Integer.parse(mask),
                 true <- mask_int in 0..32 do
              :ok
            else
              _ -> :error
            end

          _ ->
            :error
        end
    end
  end
end
