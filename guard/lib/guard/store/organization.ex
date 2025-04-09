defmodule Guard.Store.Organization do
  require Logger

  import Ecto.Query

  @spec get_by_id(String.t()) ::
          {:ok, FrontRepo.Organization.t()} | {:error, {:not_found, String.t()}}
  def get_by_id(id) when is_binary(id) and id != "" do
    Guard.FrontRepo.Organization
    |> where([o], o.id == ^id)
    |> where_undeleted()
    |> Guard.FrontRepo.one()
    |> case do
      nil -> Util.ToTuple.error("Organization '#{id}' not found.", :not_found)
      organization -> Util.ToTuple.ok(organization)
    end
  end

  @spec get_by_username(String.t()) ::
          {:ok, FrontRepo.Organization.t()} | {:error, {:not_found, String.t()}}
  def get_by_username(username) when is_binary(username) and username != "" do
    Guard.FrontRepo.Organization
    |> where([o], o.username == ^username)
    |> where_undeleted()
    |> Guard.FrontRepo.one()
    |> case do
      nil -> Util.ToTuple.error("Organization '#{username}' not found.", :not_found)
      organization -> Util.ToTuple.ok(organization)
    end
  end

  def exists?(org_id) do
    Guard.FrontRepo.Organization
    |> where([o], o.id == ^org_id)
    |> where_undeleted()
    |> Guard.FrontRepo.exists?()
  end

  @error_msg "You have exceeded the maximum number of members allowed in your organization."
  def can_add_new_member?(org_id) do
    max_people_limit = FeatureProvider.feature_quota(:max_people_in_org, param: org_id)

    if no_of_members(org_id) >= max_people_limit do
      Logger.info("[Role Management] Org_id #{inspect(org_id)}. #{@error_msg}")
      {:error, @error_msg}
    else
      {:ok, nil}
    end
  end

  def no_of_members(org_id), do: Guard.Api.Rbac.no_of_members(org_id)

  @doc """
  Creates a new organization.
  Returns {:ok, organization} if successful, or {:error, changeset} if validation fails.
  """
  @spec create(map()) :: {:ok, Guard.FrontRepo.Organization.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Guard.FrontRepo.Organization{}
    |> Guard.FrontRepo.Organization.changeset(attrs)
    |> Guard.FrontRepo.insert()
  end

  @spec update(FrontRepo.Organization.t(), map()) ::
          {:ok, FrontRepo.Organization.t()} | {:error, Ecto.Changeset.t()}
  def update(%Guard.FrontRepo.Organization{} = organization, attrs) do
    organization
    |> Guard.FrontRepo.Organization.changeset(attrs)
    |> Guard.FrontRepo.update()
  end

  @spec list(map(), map()) :: {[FrontRepo.Organization.t()], String.t() | nil}
  def list(params, keyset_params) do
    query =
      Guard.FrontRepo.Organization
      |> where_undeleted()
      |> filter_by_created_at_gt(params.created_at_gt)

    flop =
      case keyset_params.order do
        :BY_NAME_ASC -> %{order_by: [:name, :id], order_directions: [:asc, :asc]}
        :BY_CREATION_TIME_ASC -> %{order_by: [:created_at, :id], order_directions: [:asc, :asc]}
      end
      |> Map.merge(%{first: keyset_params.page_size, after: keyset_params.page_token})

    {:ok, {organizations, meta}} = query |> Flop.validate_and_run(flop, repo: Guard.FrontRepo)
    {:ok, %{organizations: organizations, next_page_token: meta.end_cursor || ""}}
  end

  @spec list_by_ids([String.t()]) :: [FrontRepo.Organization.t()]
  def list_by_ids(ids) when is_list(ids) do
    Guard.FrontRepo.Organization
    |> where([o], o.id in ^ids)
    |> where_undeleted()
    |> Guard.FrontRepo.all()
  end

  defp filter_by_created_at_gt(query, :skip), do: query

  defp filter_by_created_at_gt(query, created_at),
    do: query |> where([o], o.created_at > ^created_at)

  @doc """
  Validates organization attributes without persisting to database.
  Returns :ok if valid, or {:error, errors} with JSON encoded error messages if invalid.
  """
  @spec validate(%{name: String.t(), username: String.t(), creator_id: String.t()}) ::
          :ok | {:error, String.t()}
  def validate(attrs) do
    changeset =
      %Guard.FrontRepo.Organization{}
      |> Guard.FrontRepo.Organization.changeset(%{
        name: attrs.name,
        username: attrs.username,
        creator_id: attrs.creator_id
      })

    if changeset.valid? do
      :ok
    else
      errors =
        Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
        |> Jason.encode!()

      {:error, errors}
    end
  end

  @doc """
  Function for creating, modifying and removing organization contacts.

  If all 3 fields (name, email, phone) are empty, it is assumed contact is being removed, otherwise new one is being created or
  existing one modified. It depends if the record for same type of contact already exists for this organization.
  """
  def modify_contact(%Guard.FrontRepo.Organization{} = organization, contact_params) do
    contact =
      Guard.FrontRepo.get_by(Guard.FrontRepo.OrganizationContact,
        organization_id: organization.id,
        contact_type: contact_params.contact_type
      )

    case all_fields_empty?(contact_params) do
      true when not is_nil(contact) ->
        Guard.FrontRepo.delete(contact)

      true ->
        {:ok, nil}

      false when is_nil(contact) ->
        %Guard.FrontRepo.OrganizationContact{}
        |> Guard.FrontRepo.OrganizationContact.changeset(
          Map.put(contact_params, :organization_id, organization.id)
        )
        |> Guard.FrontRepo.insert()
        |> case do
          {:ok, contact} -> {:ok, contact}
          {:error, changeset} -> {:error, {:invalid_params, changeset}}
        end

      false ->
        contact
        |> Guard.FrontRepo.OrganizationContact.changeset(contact_params)
        |> Guard.FrontRepo.update()
        |> case do
          {:ok, contact} -> {:ok, contact}
          {:error, changeset} -> {:error, {:invalid_params, changeset}}
        end
    end
  end

  defp all_fields_empty?(%{name: name, email: email, phone: phone}) do
    empty?(name) and empty?(email) and empty?(phone)
  end

  defp empty?(nil), do: true
  defp empty?(""), do: true
  defp empty?(_), do: false

  @doc """
  Modifies organization settings by merging new settings with existing ones.
  If a setting value is empty string, it will be removed from settings.
  """
  def modify_settings(%Guard.FrontRepo.Organization{} = organization, settings) do
    new_settings =
      (organization.settings || %{})
      |> Map.merge(settings)
      |> Enum.reject(fn {_key, value} -> empty?(value) end)
      |> Map.new()

    organization
    |> Guard.FrontRepo.Organization.changeset(%{settings: new_settings})
    |> Guard.FrontRepo.update()
    |> case do
      {:ok, org} -> {:ok, org}
      {:error, changeset} -> {:error, {:invalid_params, changeset}}
    end
  end

  @spec add_suspension(FrontRepo.Organization.t(), map()) ::
          {:ok, FrontRepo.OrganizationSuspension.t()} | {:error, any()}
  def add_suspension(%Guard.FrontRepo.Organization{} = organization, %{reason: reason} = params) do
    case get_active_suspension(organization, reason) do
      nil ->
        suspension = %Guard.FrontRepo.OrganizationSuspension{
          organization_id: organization.id
        }

        Guard.FrontRepo.transaction(fn ->
          with {:ok, suspension} <-
                 suspension
                 |> Guard.FrontRepo.OrganizationSuspension.changeset(params)
                 |> Guard.FrontRepo.insert(),
               org_changes =
                 %{suspended: true}
                 |> maybe_add_unverify(reason),
               {:ok, _organization} <-
                 organization
                 |> Guard.FrontRepo.Organization.changeset(org_changes)
                 |> Guard.FrontRepo.update() do
            suspension
          end
        end)

      suspension ->
        {:ok, suspension}
    end
  end

  defp maybe_add_unverify(changes, :VIOLATION_OF_TOS), do: Map.put(changes, :verified, false)
  defp maybe_add_unverify(changes, _), do: changes

  @spec get_active_suspension(Guard.FrontRepo.Organization.t(), atom()) ::
          Guard.FrontRepo.OrganizationSuspension.t() | nil
  defp get_active_suspension(%Guard.FrontRepo.Organization{} = organization, reason) do
    from(s in Guard.FrontRepo.OrganizationSuspension,
      where:
        s.organization_id == ^organization.id and s.reason == ^reason and is_nil(s.deleted_at)
    )
    |> Guard.FrontRepo.one()
  end

  @spec count_active_suspensions(Guard.FrontRepo.Organization.t()) :: non_neg_integer()
  defp count_active_suspensions(%Guard.FrontRepo.Organization{} = organization) do
    from(s in Guard.FrontRepo.OrganizationSuspension,
      where: s.organization_id == ^organization.id and is_nil(s.deleted_at)
    )
    |> Guard.FrontRepo.aggregate(:count)
  end

  @doc """
  Removes a suspension with the given reason from an organization.
  If it was the last active suspension, marks the organization as not suspended.
  If the reason was VIOLATION_OF_TOS, marks the organization as verified.
  """
  @spec remove_suspension(Guard.FrontRepo.Organization.t(), atom()) ::
          {:ok, Guard.FrontRepo.OrganizationSuspension.t()} | {:error, Ecto.Changeset.t()}
  def remove_suspension(%Guard.FrontRepo.Organization{} = organization, reason) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case get_active_suspension(organization, reason) do
      nil ->
        {:error, :suspension_not_found}

      suspension ->
        Guard.FrontRepo.transaction(fn ->
          with {:ok, suspension} <-
                 suspension
                 |> Guard.FrontRepo.OrganizationSuspension.changeset(%{deleted_at: now})
                 |> Guard.FrontRepo.update(),
               active_suspensions_count <- count_active_suspensions(organization),
               org_changes <-
                 %{}
                 |> maybe_add_unsuspend(active_suspensions_count)
                 |> maybe_add_verify(reason),
               {:ok, _organization} <-
                 organization
                 |> Guard.FrontRepo.Organization.changeset(org_changes)
                 |> Guard.FrontRepo.update() do
            suspension
          end
        end)
    end
  end

  defp maybe_add_unsuspend(changes, 0), do: Map.put(changes, :suspended, false)
  defp maybe_add_unsuspend(changes, _), do: changes

  defp maybe_add_verify(changes, :VIOLATION_OF_TOS), do: Map.put(changes, :verified, true)
  defp maybe_add_verify(changes, _), do: changes

  @doc """
  Verifies an organization.
  Returns {:ok, organization} if successful, or {:error, changeset} if not.
  """
  @spec verify(Guard.FrontRepo.Organization.t()) ::
          {:ok, Guard.FrontRepo.Organization.t()} | {:error, Ecto.Changeset.t()}
  def verify(%Guard.FrontRepo.Organization{} = organization) do
    organization
    |> Guard.FrontRepo.Organization.changeset(%{verified: true})
    |> Guard.FrontRepo.update()
  end

  @doc """
  Soft deletes an organization.
  Returns {:ok, organization} if successful, or {:error, changeset} if not.
  """
  @spec soft_destroy(Guard.FrontRepo.Organization.t()) ::
          {:ok, Guard.FrontRepo.Organization.t()} | {:error, Ecto.Changeset.t()}
  def soft_destroy(%Guard.FrontRepo.Organization{} = organization) do
    organization
    |> Guard.FrontRepo.Organization.changeset(%{deleted_at: DateTime.utc_now()})
    |> Guard.FrontRepo.update()
  end

  @doc """
  Deletes an organization completely from the database.
  Returns {:ok, organization} if successful, or {:error, changeset} if not.
  """
  @spec hard_destroy(Guard.FrontRepo.Organization.t()) ::
          {:ok, Guard.FrontRepo.Organization.t()} | {:error, Ecto.Changeset.t()}
  def hard_destroy(%Guard.FrontRepo.Organization{} = organization) do
    Guard.FrontRepo.delete(organization)
  end

  defp where_undeleted(query) do
    query |> where([o], is_nil(o.deleted_at))
  end
end
