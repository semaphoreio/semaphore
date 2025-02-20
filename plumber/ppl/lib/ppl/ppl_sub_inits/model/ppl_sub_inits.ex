defmodule Ppl.PplSubInits.Model.PplSubInits do
  @moduledoc """
  PplSubInit models substate FSM for initilaizing state of Ppls FSM.
  """

  use Ecto.Schema

  import Ecto.Changeset
  alias Ppl.PplRequests.Model.PplRequests

  schema "pipeline_sub_inits" do
    belongs_to :pipeline_requests, PplRequests, [type: Ecto.UUID, foreign_key: :ppl_id]
    field :init_type, :string
    field :state, :string
    field :result, :string
    field :result_reason, :string
    field :in_scheduling, :boolean, read_after_writes: true
    field :error_description, :string
    field :recovery_count, :integer, read_after_writes: true
    field :terminate_request, :string
    field :terminate_request_desc, :string
    field :compile_task_id, :string

    timestamps(type: :naive_datetime_usec)
  end


  @required_fields ~w(ppl_id state in_scheduling init_type)a
  @optional_fields ~w(result result_reason error_description recovery_count
                      terminate_request terminate_request_desc compile_task_id)a
  @valid_init_types ~w(regular rebuild)
  @valid_states    ~w(conceived created fetching compilation stopping regular_init done)
  @valid_results   ~w(passed failed stopped canceled)
  @valid_failed_result_reasons ~w(malformed stuck)
  @valid_terminated_result_reasons ~w(user internal strategy fast_failing)
  @valid_terminate_requests  ~w(cancel stop)

  @doc ~S"""
  ## Examples:

      iex> alias PplSubInits.Ppls.Model.PplSubInits
      iex> PplSubInits.changeset(%PplSubInits{}) |> Map.get(:valid?)
      false

      iex> alias Ppl.PplSubInits.Model.PplSubInits
      iex> params = %{ppl_id: UUID.uuid1, state: "created", in_scheduling: false}
      iex> PplSubInits.changeset(%PplSubInits{}, params) |> Map.get(:valid?)
      true

  """
  def changeset(psi, params \\ %{}) do
    psi
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:init_type, @valid_init_types)
    |> validate_inclusion(:state, @valid_states)
    |> validate_inclusion(:result, @valid_results)
    |> validate_result_reason_field()
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:one_ppl_sub_init_per_ppl_request, name: :one_ppl_sub_init_per_ppl_request)
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
