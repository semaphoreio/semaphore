defmodule Ppl.Ppls.Model.Ppls do
  @moduledoc """
  Pipelines type

  When pipeline schedule request is recieved, pipeline is created in 'initializing' state.

  When initialization is successful pipeline transitions from 'initializing' to 'pending',
  if it fails (fetching or validating.yml schema file failed) - it goes to 'done'(failed),
  and if it is terminated while in this state - it goes to 'done'(canceled).

  If there are no other pipelines from same repo and branch that are running, pipeline
  transitions from 'pending' to 'running', otherwise it transitions to 'queuing' state.
  If pipeline is terminated while in 'pending' state - it goes to 'done'(canceled).

  Pipelines form 'queuing' state transition to 'running' when there are no older
  pipelines from same repo and branch in 'pending', 'queuing' or 'running' state.
  If pipelineis terminated while in 'queuing' state - it goes to 'done'(canceled).

  From 'running' state pipeline transitions to 'done' when execution of all of
  it's blocks is done, or when one of them fails. If pipeline is terminated while
  in 'running' state - it goes to 'stopping'.

  From 'stopping' state pipeline transitions to 'done'(stopped) when all of it's
  blocks are terminated.

  Theese transitions are represented with 'pipeline' objects.
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias Ppl.PplRequests.Model.PplRequests

  schema "pipelines" do
    belongs_to :pipeline_requests, PplRequests, [type: Ecto.UUID, foreign_key: :ppl_id]
    field :owner, :string
    field :repo_name, :string
    field :branch_name, :string
    field :yml_file_path, :string
    field :commit_sha, :string
    field :project_id, :string
    field :state, :string
    field :result, :string
    field :result_reason, :string
    field :in_scheduling, :boolean, read_after_writes: true
    field :error_description, :string
    field :recovery_count, :integer, read_after_writes: true
    field :terminate_request, :string
    field :terminate_request_desc, :string
    field :terminated_by, :string
    field :name, :string
    field :partial_rebuild_of, :string
    field :deletion_requested, :boolean, read_after_writes: true
    field :fast_failing, :string
    field :exec_time_limit_min, :integer
    field :extension_of, :string
    field :label, :string
    field :auto_cancel, :string
    field :queue_id, :string
    field :wf_number, :integer
    field :priority, :integer
    field :parallel_run, :boolean
    field :compile_task_id, :string
    field :after_task_id, :string
    field :with_after_task, :boolean, default: false
    field :repository_id, :string
    field :scheduler_task_id, :string

    timestamps(type: :naive_datetime_usec)
  end

  def required_fields(_listener_proxy? = true, _with_repo_data?) do
    ~w(ppl_id state in_scheduling branch_name yml_file_path project_id)a
  end

  def required_fields(_listener_proxy? = false, _with_repo_data? = false) do
    ~w(ppl_id state in_scheduling branch_name yml_file_path project_id)a
  end

  # TMP - do not require owner and repo_name
  def required_fields(_listener_proxy? = false, _with_repo_data? = true) do
    ~w(ppl_id state in_scheduling branch_name yml_file_path project_id
      commit_sha)a
  end

  @optional_fields ~w(result result_reason error_description recovery_count
                      terminate_request fast_failing terminate_request_desc
                      terminated_by name partial_rebuild_of exec_time_limit_min
                      deletion_requested extension_of label auto_cancel queue_id
                      wf_number priority parallel_run compile_task_id
                      after_task_id with_after_task repository_id scheduler_task_id
                      owner repo_name)a
  @valid_states    ~w(initializing pending queuing running stopping done)
  @valid_results   ~w(passed failed stopped canceled)
  @valid_failed_result_reasons ~w(test malformed stuck)
  @valid_terminated_result_reasons ~w(user internal strategy fast_failing deleted)
  @valid_terminate_requests  ~w(cancel stop)

  @doc ~S"""
  ## Examples:

      iex> alias Ppl.Ppls.Model.Ppls
      iex> Ppls.changeset(%Ppls{}) |> Map.get(:valid?)
      false

      iex> alias Ppl.Ppls.Model.Ppls
      iex> params1 = %{ppl_id: UUID.uuid1, state: "initializing", repo_name: "test", project_id: "123"}
      iex> params2 = %{in_scheduling: false, owner: "rt", branch_name: "master",
      ...>             commit_sha: "sha1", yml_file_path: ".a.yml", queue: "prod-deploy"}
      iex> params  = Map.merge(params1, params2)
      iex> Ppls.changeset(%Ppls{}, params) |> Map.get(:valid?)
      true

  """
  def changeset(ppl, params \\ %{}, listener_proxy? \\ false, with_repo_data? \\ true) do
    ppl
    |> cast(params, required_fields(listener_proxy?, with_repo_data?) ++ @optional_fields)
    |> validate_required(required_fields(listener_proxy?, with_repo_data?))
    |> validate_inclusion(:state, @valid_states)
    |> validate_inclusion(:result, @valid_results)
    |> validate_result_reason_field()
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:one_ppl_per_ppl_request, name: :one_ppl_per_ppl_request)
    |> validate_terminate_request_field()
  end

  defp validate_result_reason_field(changeset) do
    changeset
    |> get_field(:result)
    |> validate_result_reason_field_(changeset)
  end

  defp validate_result_reason_field_("failed", changeset) do
    validate_inclusion(changeset, :result_reason, @valid_failed_result_reasons)
  end
  defp validate_result_reason_field_(state, changeset) when state in ["stopped", "canceled"] do
    validate_inclusion(changeset, :result_reason, @valid_terminated_result_reasons)
  end
  defp validate_result_reason_field_(_other, changeset), do: changeset

  defp validate_terminate_request_field(changeset) do
    changeset
    |> get_field(:terminate_request)
    |> validate_terminate_request_field_(changeset)
  end

  defp validate_terminate_request_field_(nil, changeset), do: changeset
  defp validate_terminate_request_field_(_value, changeset) do
    validate_inclusion(changeset, :terminate_request, @valid_terminate_requests)
  end
end
