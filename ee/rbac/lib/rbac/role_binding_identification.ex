defmodule Rbac.RoleBindingIdentification do
  @moduledoc """
    This module encapsulates the structure used to identify role bindings.

    Since this triplet of user_id, org_id and project_id is used by different
    functions within the Rbac (cache, queries...), extracting it in this struct
    resulted in cleaner code and easier to enforce datatypes.
  """
  require Logger

  @type t :: %__MODULE__{
          user_id: String.t(),
          org_id: String.t(),
          project_id: String.t()
        }

  defstruct [:user_id, :org_id, :project_id]

  @doc """
    Input:
    :user_id - mandatory string representation of uuidv4
    :org_id - optional string representation of uuidv4 (can be empty string or * as well)
    :project_id - optional string representation of uuidv4 (can be empty string or * as well)
    These parameters can be passed as keyword list od keyword map

    Returns:
    - {:ok, rbi} where rbi is an instance of RoleBindingIdentification struct that can
    be used for modifying/querying rbac cache and working with SubjectRoleBindings
    - {:error, error_msg} when one of the values given to RBI.new() function isn't a valid
    string representation of uuidv4.
  """
  def new(options \\ [])

  def new(map) when is_map(map) do
    keyword_list = Enum.map(map, fn {key, value} -> {key, value} end)
    new(keyword_list)
  end

  def new(options) when is_list(options) do
    options =
      Enum.map(options, fn
        {key, ""} -> {key, nil}
        {key, "*"} -> {key, nil}
        other -> other
      end)

    default_options = [user_id: nil, org_id: nil, project_id: nil]
    options = Keyword.merge(default_options, options)

    if [options[:user_id], options[:org_id], options[:project_id]] |> valid_uuid?() do
      {:ok, convert_to_struct(options[:user_id], options[:org_id], options[:project_id])}
    else
      {:error,
       "Some of the fields given to the RBI.new function are not valid uuids. #{inspect(options)}"}
    end
  end

  @doc """
    Returnes Identification for non-existant user.
  """
  def new_nil_identifier do
    new(user_id: Rbac.Utils.Common.nil_uuid())
  end

  @doc """
    Used when you want to read someting from cache

    Cache key must contain user_id. If user_id is nil, then :error is returned. If org_id
    or project_id are nil, then they are replaced with '*' charecter in the key string
  """
  @spec generate_cache_key(Rbac.RoleBindingIdentification.t()) :: String.t() | :error
  def generate_cache_key(rbi) do
    if rbi[:user_id] == nil do
      :error
    else
      org_key = convert_field(rbi[:org_id])
      project_key = convert_field(rbi[:project_id])
      user_key = rbi[:user_id]
      "user:#{user_key}_org:#{org_key}_project:#{project_key}"
    end
  end

  @doc """
    Permission for a single RBI can be stored under 3 possible cache keys:
      1: Permission can be given to a specific user for one specific project. In thaty case cache key contains user_id,org_id and project_id
      2: Permission can be given to a specific user for all projects inside one org. In that case cache key contains user_id and org_id
      3: Permission can be given to a specific user for all projects and all orgs (super-user). In this case cache key contains only user_id
    This function generates those different cache keys from RBI struct

    Input:
    RoleBindingIdentification struct

    Return
      list(string) - List with three cache_keys (strings)
      :error - If RBI struct does not have user_id
  """
  @spec generate_all_possible_keys(Rbac.RoleBindingIdentification.t()) ::
          list(String.t()) | :error
  def generate_all_possible_keys(rbi) do
    if rbi[:user_id] == nil do
      :error
    else
      key1 = generate_cache_key(rbi)
      key2 = generate_cache_key(rbi |> struct(%{project_id: nil}))
      key3 = generate_cache_key(rbi |> struct(%{project_id: nil, org_id: nil}))
      Enum.uniq([key1, key2, key3])
    end
  end

  @regex_for_extracting_user_id_from_cache_key ~r/user:([^_]+)_org/
  def extract_user_id_from_cache_key(key) do
    [_, user_id | _] = Regex.run(@regex_for_extracting_user_id_from_cache_key, key)
    user_id
  end

  @doc """
    Throughout the codebase we work with maps which can be accessed via [:field_name]
    syntax, but that is not true for structs. In order to keep consisteny of accessing
    'objects' in the same way, whether they are maps or structs, fetch functions need
    to be implemented.
  """
  def fetch(struct, :user_id), do: {:ok, struct.user_id}
  def fetch(struct, :org_id), do: {:ok, struct.org_id}
  def fetch(struct, :project_id), do: {:ok, struct.project_id}
  def fetch(_, _), do: :error

  defp valid_uuid?(ids) when is_list(ids), do: Enum.all?(ids, &valid_uuid?/1)

  # empty (nil) values are valid uuid's in this scenario
  defp valid_uuid?(nil), do: true

  # TODO Better solution should be figured out for this. This is a quick patch for now:
  # projects_id: nil is ambiguous. Does it mean that we don't care for the value of project_id,
  # or do we specifically care for entities where project_id value is NULL, or IS NOT NULL? We
  # sometimes want to fetch all role assignments that one organization has, in that case we don't
  # care about the project id, whether it is NULL (org_level role) or it is not NULL (project level role).
  # But, in another example, we want to fetch (or remove) only org level role, or only ptoj level roles,
  # meaning project id has to be (or must not be) null. We don't have the same problem with org_id and user_id
  # as those two fields cant be null. For now, we are introducing :is_nil and :is_not_nil atoms to specifically
  # state if we want data where project id is null or isn't null. Again, a better solution should be implemented
  defp valid_uuid?(:is_nil), do: true
  defp valid_uuid?(:is_not_nil), do: true

  defp valid_uuid?(uuid), do: Rbac.Utils.Common.valid_uuid?(uuid)

  defp convert_to_struct(user_id, org_id, project_id) do
    converted_map = %{
      :user_id => user_id,
      :org_id => org_id,
      :project_id => project_id
    }

    struct(__MODULE__, converted_map)
  end

  @nil_uuid Rbac.Utils.Common.nil_uuid()
  defp convert_field(nil), do: "*"
  defp convert_field(:is_nil), do: "*"
  defp convert_field(@nil_uuid), do: "*"
  defp convert_field(value), do: value
end
