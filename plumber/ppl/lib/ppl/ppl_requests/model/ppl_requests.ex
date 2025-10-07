defmodule Ppl.PplRequests.Model.PplRequests do
  @moduledoc """
  Pipeline Requests type
  Each pipeline schedule request is represented with 'pipeline request' object (database row).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "pipeline_requests" do

    field :definition, :map
    field :request_args, :map
    field :request_token, :string
    field :block_count, :integer, read_after_writes: true
    field :top_level, :boolean, read_after_writes: true
    field :initial_request, :boolean, read_after_writes: true
    field :switch_id, :string
    field :prev_ppl_artefact_ids, {:array, :string}
    field :ppl_artefact_id, :string
    field :wf_id, :string
    field :source_args, :map
    field :pre_flight_checks, :map

    timestamps(type: :naive_datetime_usec)
  end

  @required_fields_definition ~w(definition)a
  @optional_fields_definition ~w(switch_id)a
  @required_fields_source ~w(source_args)a
  @required_fields_request ~w(request_args request_token top_level initial_request
                              prev_ppl_artefact_ids ppl_artefact_id id wf_id)a

  @doc ~S"""
  ## Examples:

      iex> alias Ppl.PplRequests.Model.PplRequests
      iex> PplRequests.changeset_source(%PplRequests{}) |> Map.get(:valid?)
      false

      iex> alias Ppl.PplRequests.Model.PplRequests
      iex> src = %{head_commit_sha: UUID.uuid4(), notify_commit_sha: UUID.uuid4(),
      ...>   commit_message: "Merge pull request #123", repo_host_url: "git.com"}
      iex> params = %{source_args: src}
      iex> PplRequests.changeset_source(%PplRequests{}, params) |> Map.get(:valid?)
      true
  """
  def changeset_source(ppl_req, params \\ %{}) do
    ppl_req
    |> cast(params, @required_fields_source)
    |> validate_required(@required_fields_source)
  end

  @doc ~S"""
  ## Examples:

      iex> alias Ppl.PplRequests.Model.PplRequests
      iex> PplRequests.changeset_conception(%PplRequests{}) |> Map.get(:valid?)
      false

      iex> alias Ppl.PplRequests.Model.PplRequests
      iex> params = %{request_args: %{"hook_id" => UUID.uuid1(), "branch_id" => UUID.uuid4(),
      ...>   "owner" => "owner", "repo_name" => "repo_name", "repository_id" => UUID.uuid4(),
      ...>   "branch_name" => "branch_name", "commit_sha" => UUID.uuid4()}}
      iex> PplRequests.changeset_conception(%PplRequests{}, params) |> Map.get(:valid?)
      true
  """
  def changeset_conception(ppl_req, params \\ %{}) do
    ppl_req
    |> cast(params, [:request_args])
    |> validate_required([:request_args])
    |> validate_conception_request_arg("hook_id")
    |> validate_conception_request_arg("branch_id")
    |> validate_conception_request_arg("owner")
    |> validate_conception_request_arg("repo_name")
    |> validate_conception_request_arg("branch_name")
    |> validate_conception_request_arg("commit_sha")
    |> validate_conception_request_arg("repository_id")
  end

  defp validate_conception_request_arg(changeset, argument_name) do
    validate_change(changeset, :request_args, fn _, request_args ->
      request_args |> Map.get("service") |> field_required_and_present_in_conception?(request_args, argument_name)
    end)
  end

  defp field_required_and_present_in_conception?(service, _, "repository_id") when service in ["local", "snapshot"],
    do: []

  defp field_required_and_present_in_conception?(_, request_args, argument_name),
    do: request_args |> Map.get(argument_name) |> field_required(argument_name)

  @doc ~S"""
  ## Examples:

      iex> alias Ppl.PplRequests.Model.PplRequests
      iex> PplRequests.changeset_compilation(%PplRequests{}) |> Map.get(:valid?)
      false

      iex> alias Ppl.PplRequests.Model.PplRequests
      iex> params = %{request_args: %{"artifact_store_id" => UUID.uuid1()}}
      iex> PplRequests.changeset_compilation(%PplRequests{}, params) |> Map.get(:valid?)
      true
  """
  def changeset_compilation(ppl_req, params \\ %{}) do
    ppl_req
    |> cast(params, [:request_args, :pre_flight_checks])
    |> validate_required([:request_args])
    |> validate_change(:request_args, &request_args_field_validator__artifact_store_id/2)
    |> validate_change(:pre_flight_checks, &pre_flight_checks_validator/2)
  end

  def pre_flight_checks_validator(:pre_flight_checks, pfcs) do
    validate_pfc_container(pfcs, [
      &pfcs_have_at_least_one_pfc?/1,
      &pfcs_have_valid_org_pfc?/1,
      &pfcs_have_valid_prj_pfc?/1
    ])
    |> Enum.into([], &{:pre_flight_checks, &1})
  end

  defp pfcs_have_at_least_one_pfc?(pfcs) do
    if System.get_env("SKIP_PFC") == "true" || Map.get(pfcs, "organization_pfc") || Map.get(pfcs, "project_pfc"),
      do: [],
      else: ["must contain at least one pre-flight check"]
  end

  defp pfcs_have_valid_org_pfc?(pfcs) do
    org_pfc = Map.get(pfcs, "organization_pfc")
    prefix = "organization_pfc"

    if is_nil(org_pfc),
      do: [],
      else:
        validate_pfc_container(org_pfc, [
          &validate_pfc(&1, prefix),
          &validate_pfc_commands(&1, prefix),
          &validate_pfc_secrets(&1, prefix)
        ])
  end

  defp pfcs_have_valid_prj_pfc?(pfcs) do
    prj_pfc = Map.get(pfcs, "project_pfc")
    prefix = "project_pfc"

    if is_nil(prj_pfc),
      do: [],
      else:
        validate_pfc_container(prj_pfc, [
          &validate_pfc(&1, prefix),
          &validate_pfc_commands(&1, prefix),
          &validate_pfc_secrets(&1, prefix),
          &validate_pfc_agent(&1, prefix)
        ])
  end

  def validate_pfc_container(container, validators) do
    validators
    |> Enum.reduce([], &(&2 ++ &1.(container)))
  end

  defp validate_pfc(pfc, prefix) do
    if is_nil(pfc) or is_map(pfc), do: [], else: ["#{prefix} must be nil or proper map"]
  end

  defp validate_pfc_commands(pfc, prefix) do
    cond do
      not Map.has_key?(pfc, "commands") ->
        ["#{prefix}/commands are not defined"]

      not is_list(pfc["commands"]) ->
        ["#{prefix}/commands are not a list"]

      not Enum.all?(pfc["commands"], &is_binary/1) ->
        ["#{prefix}/commands are not a list of strings"]

      not (length(pfc["commands"]) > 0) ->
        ["#{prefix}/commands cannot be an empty list"]

      true ->
        []
    end
  end

  defp validate_pfc_secrets(pfc, prefix) do
    cond do
      not Map.has_key?(pfc, "secrets") ->
        ["#{prefix}/secrets are not defined"]

      not is_list(pfc["secrets"]) ->
        ["#{prefix}/secrets are not a list"]

      not Enum.all?(pfc["secrets"], &is_binary/1) ->
        ["#{prefix}/secrets are not a list of strings"]

      true ->
        []
    end
  end

  defp validate_pfc_agent(pfc, prefix) do
    agent = pfc["agent"]
    machine_type = agent && agent["machine_type"]

    cond do
      not (is_map(agent) or is_nil(agent)) ->
        ["#{prefix}/agent must be a map or nil"]

      not (is_nil(agent) or (is_binary(machine_type) && String.length(machine_type) > 0)) ->
        ["#{prefix}/agent/machine_type must be a non-empty string"]

      true ->
        []
    end
  end

  @doc ~S"""
  ## Examples:

      iex> alias Ppl.PplRequests.Model.PplRequests
      iex> PplRequests.changeset_request(%PplRequests{}) |> Map.get(:valid?)
      false

      iex> alias Ppl.PplRequests.Model.PplRequests
      iex> params = %{request_args: %{"service" => "local"}, request_token: UUID.uuid1,
      ...>           top_level: false, initial_request: false, prev_ppl_artefact_ids: [],
      ...>           ppl_artefact_id: UUID.uuid1(), id: UUID.uuid1(), wf_id: UUID.uuid4()}
      iex> PplRequests.changeset_request(%PplRequests{}, params) |> Map.get(:valid?)
      true

      iex> alias Ppl.PplRequests.Model.PplRequests
      iex> args = %{"service" => "git_hub", "repo_name" => "test", "access_token" => "token",
      ...>          "branch_name"=> "master", "commit_sha" => "sha", "client_id" => "id",
      ...>          "client_secret" => "secret", "owner" => "user", "hook_id" => UUID.uuid4(),
      ...>          "branch_id" => UUID.uuid4(), "requester_id" => UUID.uuid4()}
      iex> params = %{request_args: args, request_token: UUID.uuid1, prev_ppl_artefact_ids: [],
      ...>            ppl_artefact_id: UUID.uuid1, top_level: false, initial_request: false,
      ...>            id: UUID.uuid1(), wf_id: UUID.uuid4()}
      iex> PplRequests.changeset_request(%PplRequests{}, params) |> Map.get(:valid?)
      true
  """
  def changeset_request(ppl_req, params \\ %{}, start_in_conceived? \\ false) do
    ppl_req
    |> cast(params, @required_fields_request)
    |> validate_required(@required_fields_request)
    |> validate_hook_related_fields(!start_in_conceived?)
    |> validate_change(:request_args, &request_args_field_validator__branch_name/2)
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:unique_request_token_for_ppl_requests,
      name: :unique_request_token_for_ppl_requests
    )
  end

  defp validate_hook_related_fields(changeset, false), do: changeset

  defp validate_hook_related_fields(changeset, true) do
    changeset
    |> validate_change(:request_args, &request_args_field_validator__hook_id/2)
    |> validate_change(:request_args, &request_args_field_validator__branch_id/2)
    |> validate_change(:request_args, &request_args_field_validator__commit_sha/2)
    |> validate_change(:request_args, &request_args_field_validator__repo_name/2)
    |> validate_change(:request_args, &request_args_field_validator__owner/2)
  end

  defp request_args_field_validator__hook_id(_, value), do: validate(value, "hook_id")
  defp request_args_field_validator__repo_name(_, value), do: validate(value, "repo_name")
  defp request_args_field_validator__owner(_, value), do: validate(value, "owner")
  defp request_args_field_validator__branch_name(_, value), do: validate(value, "branch_name")
  defp request_args_field_validator__branch_id(_, value), do: validate(value, "branch_id")
  defp request_args_field_validator__commit_sha(_, value), do: validate(value, "commit_sha")
  defp request_args_field_validator__artifact_store_id(_, value), do: validate(value, "artifact_store_id")

  defp validate(value, field) do
    value |> Map.get("service") |> field_required_and_present?(value, field)
  end

  defp field_required_and_present?("git", _, field_name) when field_name in ["repo_name", "owner"],
    do: []

  defp field_required_and_present?(service, request_args, field_name) when service in ["git_hub", "bitbucket", "git", "gitlab"],
    do: request_args |> Map.get(field_name) |> field_required(field_name)

  defp field_required_and_present?(_, _, _), do: []

  defp field_required(nil, field_name), do: [request_args: "Missing field '#{field_name}'"]
  defp field_required("", field_name), do: [request_args: "Field '#{field_name}' can not be empty string"]
  defp field_required(_, _), do: []


  @doc ~S"""
  ## Examples:

      iex> alias Ppl.PplRequests.Model.PplRequests
      iex> PplRequests.changeset_definition(%PplRequests{}) |> Map.get(:valid?)
      false

      iex> alias Ppl.PplRequests.Model.PplRequests
      iex> blocks = [%{"build" => %{"jobs" => ["echp foo"]}}]
      iex> agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
      iex> definition = %{"version" => "v1.0", "agent" => agent, "blocks" => blocks}
      iex> params = %{definition: definition, switch_id: "id"}
      iex> PplRequests.changeset_definition(%PplRequests{}, params) |> Map.get(:valid?)
      true
  """
  def changeset_definition(ppl_req, params \\ %{}) do
    ppl_req
    |> cast(params, @required_fields_definition ++ @optional_fields_definition)
    |> validate_required(@required_fields_definition)
    |> validate_change(:definition, &definition_field_validator__version/2)
    |> validate_change(:definition, &definition_field_validator__blocks/2)
    |> force_change(:block_count, get_block_count(params))
  end

  defp definition_field_validator__version(_, value) do
    value |> Map.get("version") |> definition_version_()
  end

  defp definition_version_(nil), do: [definition: "Missing field 'version'"]
  defp definition_version_(_),   do: []

  defp definition_field_validator__blocks(_, value) do
    value |> Map.get("version")
    |> definition_field_validator__blocks_(value |> Map.get("blocks"))
  end

  defp definition_field_validator__blocks_(_, nil), do:
    [definition: "Missing field 'blocks'"]
  defp definition_field_validator__blocks_(v, blocks) when is_list(blocks), do:
    definition_field_validator__blocks_count(v, blocks |> length())
  defp definition_field_validator__blocks_(_, _), do:
    [definition: "Field 'blocks' must be list"]

  defp definition_field_validator__blocks_count(_version, c) when c < 1, do:
    [definition: "There has to be at least 1 block"]
  defp definition_field_validator__blocks_count(_, _), do: []

  defp get_block_count(params),
    do: Map.get(params, :definition, %{}) |> Map.get("blocks", []) |> length()
end
