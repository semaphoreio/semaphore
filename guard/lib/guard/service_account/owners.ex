defmodule Guard.ServiceAccount.Owners do
  @moduledoc """
  Who a service account acts for.

  A service account borrows its owner's access to repositories, so an owner has to be
  a person who is still an active member of the account's organization. `owner_id`
  records the intent and survives; whether it currently holds is asked here, at the
  moment it matters.
  """

  import Ecto.Query

  alias Guard.FrontRepo
  alias Guard.FrontRepo.User
  alias Guard.Repo
  alias Guard.Repo.SubjectRoleBinding

  @doc """
  True when the user can act as an owner of a service account in `org_id`.
  """
  @spec active?(String.t() | nil, String.t() | nil) :: boolean()
  def active?(user_id, org_id) do
    user_id
    |> List.wrap()
    |> active_ids(org_id)
    |> MapSet.member?(user_id)
  end

  @doc """
  Of the given user ids, those that can act as an owner of a service account in `org_id`.
  """
  @spec active_ids([String.t() | nil], String.t() | nil) :: MapSet.t()
  def active_ids(user_ids, org_id) do
    ids = user_ids |> Enum.filter(&valid_id?/1) |> Enum.uniq()

    if ids == [] or not valid_id?(org_id) do
      MapSet.new()
    else
      ids
      |> people()
      |> members(org_id)
      |> MapSet.new()
    end
  end

  # A service account is an organization member in its own right, so it is excluded
  # here: only a person can stand behind one.
  defp people(ids) do
    User
    |> where([u], u.id in ^ids)
    |> where([u], is_nil(u.creation_source) or u.creation_source != :service_account)
    |> where([u], is_nil(u.blocked_at))
    |> where([u], is_nil(u.deactivated) or u.deactivated == false)
    |> select([u], u.id)
    |> FrontRepo.all()
  end

  defp members([], _org_id), do: []

  defp members(ids, org_id) do
    SubjectRoleBinding
    |> where([srb], srb.subject_id in ^ids and srb.org_id == ^org_id)
    |> where([srb], is_nil(srb.project_id))
    |> select([srb], srb.subject_id)
    |> distinct(true)
    |> Repo.all()
  end

  defp valid_id?(id) when is_binary(id), do: Guard.Utils.valid_uuid?(id)
  defp valid_id?(_), do: false
end
