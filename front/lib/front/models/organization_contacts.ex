defmodule Front.Models.OrganizationContacts do
  require Logger
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:org_id, :string)
    field(:contact_type, :string)
    field(:name, :string)
    field(:email, :string)
    field(:phone, :string)
  end

  @fields ~w(org_id contact_type name email phone)a
  @valid_contact_types ~w(Security Main Finances)

  @doc """
    Returns a map with all existing contacts in a form of {contact_type => contact_changeset}.
    If organization does not have some of the contacts specified, empty changeset will be created
    in their place
    Example return value:
    %{
      "Main" => Changeset with info about main contact,
      "Finances" => Changeset with info about contact for finances,
      "Security" => Empty changeset
    }
  """
  def get_all(org_id) do
    case grpc_fetch(org_id) do
      {:ok, response} ->
        default_map = generate_default_contacts_map(org_id)

        contacts_map =
          response.org_contacts
          |> Enum.map(&construct_struct/1)
          |> Enum.map(&changeset/1)
          |> Enum.reduce(default_map, fn contact, map ->
            %{map | get_field(contact, :contact_type) => contact}
          end)

        {:ok, contacts_map}

      e ->
        Logger.error(
          "Error while fetching org contacts for org #{inspect(org_id)} Error: #{inspect(e)}"
        )
    end
  end

  def modify(params) do
    result =
      struct(__MODULE__)
      |> changeset(params)
      |> Ecto.Changeset.apply_action(:insert)

    case result do
      {:ok, model} -> grpc_modify(model)
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp changeset(schema, params \\ %{}) do
    schema
    |> cast(params, @fields)
    |> validate_required([
      :org_id,
      :contact_type
    ])
    |> validate_inclusion(:contact_type, @valid_contact_types)
  end

  ###
  ### Helper function
  ###

  def generate_default_contacts_map(org_id) do
    Enum.reduce(@valid_contact_types, %{}, fn contact_type, map ->
      Map.put(map, contact_type, default_changeset(org_id, contact_type))
    end)
  end

  defp default_changeset(org_id, type) do
    struct(__MODULE__, org_id: org_id, contact_type: type) |> changeset()
  end

  defp grpc_fetch(org_id) do
    alias InternalApi.Organization.FetchOrganizationContactsRequest
    alias InternalApi.Organization.OrganizationService.Stub

    endpoint = Application.fetch_env!(:front, :organization_api_grpc_endpoint)
    {:ok, channel} = GRPC.Stub.connect(endpoint)
    req = FetchOrganizationContactsRequest.new(org_id: org_id)

    Stub.fetch_organization_contacts(channel, req)
  end

  defp grpc_modify(model) do
    alias InternalApi.Organization.{ModifyOrganizationContactRequest, OrganizationContact}
    alias InternalApi.Organization.OrganizationService.Stub

    endpoint = Application.fetch_env!(:front, :organization_api_grpc_endpoint)
    {:ok, channel} = GRPC.Stub.connect(endpoint)

    req =
      ModifyOrganizationContactRequest.new(
        org_contact:
          OrganizationContact.new(
            org_id: model.org_id,
            type: get_enum_from_contact_type(model.contact_type),
            email: model.email || "",
            name: model.name || "",
            phone: model.phone || ""
          )
      )

    Stub.modify_organization_contact(channel, req)
  end

  defp construct_struct(raw) do
    struct!(__MODULE__,
      org_id: raw.org_id,
      contact_type: get_contact_type_from_enum(raw.type),
      name: raw.name,
      email: raw.email,
      phone: raw.phone
    )
  end

  defp get_contact_type_from_enum(enum) do
    alias InternalApi.Organization.OrganizationContact.ContactType

    ContactType.key(enum)
    |> Atom.to_string()
    |> String.trim_leading("CONTACT_TYPE_")
    |> String.capitalize()
  end

  defp get_enum_from_contact_type(contact_type) do
    alias InternalApi.Organization.OrganizationContact.ContactType

    ("CONTACT_TYPE_" <> contact_type)
    |> String.upcase()
    |> String.to_atom()
    |> ContactType.value()
  end
end
