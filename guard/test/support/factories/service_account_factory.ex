defmodule Support.Factories.ServiceAccountFactory do
  alias Ecto.UUID
  alias Guard.FrontRepo
  alias Guard.FrontRepo.{User, ServiceAccount}

  @doc """
  Insert a service account with associated user record.

  Options:
  - :id - Service account ID (defaults to random UUID, same as user ID)
  - :name - Service account name (defaults to random string)
  - :description - Service account description (defaults to empty string)
  - :org_id - Organization ID (defaults to random UUID)
  - :creator_id - Creator user ID (defaults to random UUID)
  """
  def insert(options \\ []) do
    # With new schema, service account ID is the same as user ID
    user_id = get_id(options[:id])
    org_id = get_org_id(options[:org_id])
    name = get_name(options[:name])
    description = get_description(options[:description])
    creator_id = get_creator_id_with_user(options[:creator_id])

    # Create the user record first
    user_params = %{
      id: user_id,
      email: generate_synthetic_email(name, org_id),
      name: name,
      company: "",
      org_id: org_id,
      single_org_user: true,
      creation_source: :service_account,
      deactivated: false,
      authentication_token: generate_token_hash()
    }

    {:ok, user} = User.changeset(%User{}, user_params) |> FrontRepo.insert()

    # Create the service account record with the same ID as the user
    service_account_params = %{
      id: user.id,
      description: description,
      creator_id: creator_id,
      user: user
    }

    {:ok, service_account} =
      ServiceAccount.changeset(%ServiceAccount{}, service_account_params) |> FrontRepo.insert()

    service_account = FrontRepo.preload(service_account, :user)

    {:ok, %{service_account: service_account, user: user}}
  end

  @doc """
  Create service account parameters for testing without inserting to database.
  """
  def build_params(options \\ []) do
    %{
      org_id: get_org_id(options[:org_id]),
      name: get_name(options[:name]),
      description: get_description(options[:description]),
      creator_id: get_creator_id(options[:creator_id]),
      role_id: get_role_id(options[:role_id])
    }
  end

  @doc """
  Create service account parameters with a real creator user for integration tests.
  This creates a real user in the database and returns params with that user's ID.
  """
  def build_params_with_creator(options \\ []) do
    {:ok, creator_user} = Support.Factories.FrontUser.insert()

    %{
      org_id: get_org_id(options[:org_id]),
      name: get_name(options[:name]),
      description: get_description(options[:description]),
      creator_id: creator_user.id,
      role_id: get_role_id(options[:role_id])
    }
  end

  defp get_id(nil), do: UUID.generate()
  defp get_id(id), do: id

  defp get_org_id(nil), do: UUID.generate()
  defp get_org_id(org_id), do: org_id

  defp get_creator_id(nil), do: UUID.generate()
  defp get_creator_id(creator_id), do: creator_id

  defp get_creator_id_with_user(nil) do
    # Create a real user to use as creator to satisfy foreign key constraint
    {:ok, creator_user} = Support.Factories.FrontUser.insert()
    creator_user.id
  end

  defp get_creator_id_with_user(creator_id), do: creator_id

  defp get_name(nil) do
    "test-service-account-" <> for(_ <- 1..8, into: "", do: <<Enum.random('abcdefghijk')>>)
  end

  defp get_name(name), do: name

  defp get_description(nil), do: ""
  defp get_description(description), do: description

  defp generate_synthetic_email(name, _org_id) do
    sanitized_name = String.downcase(name) |> String.replace(~r/[^a-z0-9\-]/, "-")
    "#{sanitized_name}@service-accounts.test-org.#{Application.fetch_env!(:guard, :base_domain)}"
  end

  defp get_role_id(nil), do: UUID.generate()
  defp get_role_id(role_id), do: role_id

  defp generate_token_hash do
    # Generate a simple hash for testing
    :crypto.hash(:sha256, UUID.generate()) |> Base.encode64()
  end
end
