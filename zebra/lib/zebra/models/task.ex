defmodule Zebra.Models.Task do
  use Ecto.Schema
  import Ecto.Changeset

  require Ecto.Query
  alias Ecto.Query, as: Q

  @result_passed "passed"
  @result_failed "failed"
  @result_stopped "stopped"

  @results [nil, @result_passed, @result_failed, @result_stopped]

  @fail_fast_none nil
  @fail_fast_stop "stop"
  @fail_fast_cancel "cancel"

  @fail_fast_strategies [@fail_fast_none, @fail_fast_stop, @fail_fast_cancel]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "builds" do
    has_many(:jobs, Zebra.Models.Job, foreign_key: :build_id)

    field(:version, :string)
    field(:request, :map)
    field(:hook_id, :binary_id)
    field(:workflow_id, :binary_id)
    field(:build_request_id, :binary_id)
    field(:ppl_id, :binary_id)
    field(:branch_id, :binary_id)
    field(:result, :string)
    field(:fail_fast_strategy, :string)

    field(:created_at, :utc_datetime)
    field(:updated_at, :utc_datetime)
  end

  def running?(task) do
    task.result == nil
  end

  def finished?(task) do
    task.result != nil
  end

  def create(params) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    params = params |> Map.new() |> Map.merge(%{created_at: now, updated_at: now})

    changeset(%__MODULE__{}, params) |> Zebra.LegacyRepo.insert()
  end

  def update(task, params \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    params = params |> Map.merge(%{updated_at: now})

    changeset(task, params) |> Zebra.LegacyRepo.update()
  end

  ## Assocs

  def jobs(task) do
    task |> Ecto.assoc(:jobs) |> Zebra.LegacyRepo.all()
  end

  ## Scopes

  def running(query \\ __MODULE__) do
    query |> Q.where([b], is_nil(b.result))
  end

  def finished(query \\ __MODULE__) do
    query |> Q.where([b], not is_nil(b.result))
  end

  ##
  ## Transitions
  ##

  def finish(task, result) do
    if result == nil do
      {:error, :result_cant_be_nil}
    else
      update(task, %{result: result})
    end
  end

  ##
  ## Lookup
  ##

  def find(id) do
    case Zebra.LegacyRepo.get(__MODULE__, id) do
      nil -> {:error, :not_found}
      task -> {:ok, task}
    end
  end

  def find_by_request_token(token) do
    task = __MODULE__ |> Q.where(build_request_id: ^token) |> Zebra.LegacyRepo.one()

    if task do
      {:ok, task}
    else
      {:error, :not_found}
    end
  end

  def find_many(ids) do
    tasks = __MODULE__ |> Q.where([t], t.id in ^ids) |> Zebra.LegacyRepo.all()

    {:ok, tasks}
  end

  def find_by_id_or_request_token(id) do
    case find(id) do
      {:ok, t} -> {:ok, t}
      {:error, :not_found} -> find_by_request_token(id)
    end
  end

  def find_many_by_id_or_request_token(ids) do
    tasks =
      __MODULE__
      |> Q.where([t], t.id in ^ids or t.build_request_id in ^ids)
      |> Zebra.LegacyRepo.all()

    {:ok, tasks}
  end

  def finished_at(task) do
    Zebra.LegacyRepo.preload(task, [:jobs])
    |> Map.get(:jobs)
    |> Enum.map(fn job -> job.finished_at |> DateTime.to_unix() end)
    |> Enum.max()
    |> DateTime.from_unix()
    |> elem(1)
  end

  #
  # Helpers
  #

  def changeset(task, params \\ %{}) do
    task
    |> cast(params, [
      :version,
      :request,
      :hook_id,
      :workflow_id,
      :ppl_id,
      :build_request_id,
      :branch_id,
      :result,
      :created_at,
      :updated_at,
      :fail_fast_strategy
    ])
    |> validate_inclusion(:result, @results)
    |> validate_inclusion(:fail_fast_strategy, @fail_fast_strategies)
  end

  def encode_request(request) do
    request |> Poison.encode!() |> Poison.decode!()
  end
end
