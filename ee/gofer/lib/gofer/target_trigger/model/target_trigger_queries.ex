defmodule Gofer.TargetTrigger.Model.TargetTriggerQueries do
  @moduledoc """
  Queries on TargetTrigger type
  """
  import Ecto.Query

  alias Gofer.TargetTrigger.Model.TargetTrigger
  alias Gofer.SwitchTrigger.Model.SwitchTrigger
  alias Gofer.EctoRepo, as: Repo
  alias LogTee, as: LT
  alias Util.ToTuple

  def insert(params) do
    params_for_log = Map.take(params, ["switch_trigger_id", "target_name"])

    params = %{"schedule_request_token" => UUID.uuid4()} |> Map.merge(params)

    try do
      %TargetTrigger{}
      |> TargetTrigger.changeset(params)
      |> Repo.insert()
      |> process_response(params_for_log)
    rescue
      e -> {:error, e}
    catch
      a, b -> {:error, [a, b]}
    end
  end

  defp process_response(
         {:error,
          %Ecto.Changeset{errors: [one_target_trigger_per_tartget_per_switch_trigger: _message]}},
         params_for_log
       ) do
    params_for_log
    |> LT.info("TargetTrigger.insert() - There is already target_trigger for given data: ")

    # Return {:ok, target_trigger} because of idempotency requirement
    %{"switch_trigger_id" => id, "target_name" => name} = params_for_log
    get_by_id_and_name(id, name)
  end

  defp process_response({:ok, target_trigger}, params_for_log) do
    target_trigger
    |> LT.info("Persisted target_trigger with given data: #{inspect(params_for_log)} ")
    |> ToTuple.ok()
  end

  def update(target_trigger, params) do
    try do
      target_trigger
      |> TargetTrigger.changeset(params)
      |> Repo.update()
      |> LT.info(
        "Target_trigger for id #{target_trigger.switch_trigger_id} and name #{target_trigger.target_name} marked as processed."
      )
    rescue
      e -> {:error, e}
    catch
      a, b -> {:error, [a, b]}
    end
  end

  @doc """
  Returns n last target_triggers for target with given name from given switch.
  """
  def get_last_n_triggers_for_target(switch_id, target_name, n_last) do
    join_tabels()
    |> where([tt], tt.switch_id == ^switch_id)
    |> where([tt], tt.target_name == ^target_name)
    |> order_by([_tt, st], desc: st.triggered_at)
    |> limit(^n_last)
    |> select_target_trigger_details()
    |> Repo.all()
    |> ToTuple.ok()
  rescue
    e -> {:error, e}
  end

  defp join_tabels() do
    from(tt in TargetTrigger, join: st in SwitchTrigger, on: st.id == tt.switch_trigger_id)
  end

  def select_target_trigger_details(query) do
    query
    |> select(
      [tt, st],
      %{
        target_name: tt.target_name,
        triggered_at: st.triggered_at,
        auto_triggered: st.auto_triggered,
        triggered_by: st.triggered_by,
        override: st.override,
        processed: tt.processed,
        processing_result: fragment("coalesce(nullif(?, ''), '')", tt.processing_result),
        scheduled_at: tt.scheduled_at,
        scheduled_pipeline_id: fragment("coalesce(nullif(?, ''), '')", tt.scheduled_ppl_id),
        error_response: fragment("coalesce(nullif(?, ''), '')", tt.error_response),
        env_variables: fragment("?->?", st.env_vars_for_target, tt.target_name)
      }
    )
  end

  @doc """
  Returns paginated target_triggers for target with given name from given switch.
  """
  def list_triggers_for_target(switch_id, target_name, page, page_size) do
    join_tabels()
    |> where([tt], tt.switch_id == ^switch_id)
    |> filter_by_target_name(target_name)
    |> order_by([_tt, st], desc: st.triggered_at)
    |> select_target_trigger_details()
    |> Repo.paginate(page: page, page_size: page_size)
    |> ToTuple.ok()
  rescue
    e -> {:error, e}
  end

  defp filter_by_target_name(query, :skip), do: query

  defp filter_by_target_name(query, target_name),
    do: query |> where([tt], tt.target_name == ^target_name)

  @doc """
  Returns batch_no in order batch with unprocessed target_triggers that are older than timestamp.
  """
  def get_older_unprocessed(timestamp, batch_no) do
    TargetTrigger
    |> where(processed: false)
    |> where([tt], tt.inserted_at < ^timestamp)
    |> limit(100)
    |> offset(^calc_offset(batch_no))
    |> Repo.all()
    |> ToTuple.ok()
  rescue
    e -> {:error, e}
  end

  defp calc_offset(batch_no), do: batch_no * 100

  @doc """
  Returns count of unprocessed triggers for same target as given target_trigger
  which are older than it.
  """
  def get_older_unprocessed_triggers_count(target_trigger) do
    from(st in SwitchTrigger,
      left_join: tt in TargetTrigger,
      on: tt.switch_trigger_id == st.id,
      join: given in SwitchTrigger,
      on: given.id == ^target_trigger.switch_trigger_id,
      # only count switch triggers for same switch
      where: st.switch_id == ^target_trigger.switch_id,
      # only older switch_triggers than one to which given target_trigger belongs
      where: st.inserted_at < given.inserted_at,
      # only count rows if they have target_triggers for same target or if the
      # switch_trigger is unprocessed (in that case target name will be checked later)
      where: tt.target_name == ^target_trigger.target_name or is_nil(tt.target_name),
      # count either unprocessed target_triggers if switch_trigger is processed
      # or unprocessed switch_triggers for same target
      where:
        (st.processed == true and tt.processed == false) or
          (st.processed == false and ^target_trigger.target_name in st.target_names)
    )
    |> select([st], count(st.id))
    |> Repo.one()
    |> ToTuple.ok()
  rescue
    e -> {:error, e}
  end

  @doc """
  Returns count of unprocessed trigger requests for target in given switch.
  """
  def get_unprocessed_triggers_count(switch_id, target_name) do
    from(st in SwitchTrigger,
      left_join: tt in TargetTrigger,
      on: tt.switch_trigger_id == st.id and tt.target_name == ^target_name,
      where: st.switch_id == ^switch_id,
      where:
        (st.processed == true and tt.processed == false) or
          (st.processed == false and ^target_name in st.target_names)
    )
    |> select([st], count(st.id))
    |> Repo.one()
    |> ToTuple.ok()
  rescue
    e -> {:error, e}
  end

  @doc """
  Returns TargetTrigger with given switch_trigger_id and target_name
  """
  def get_by_id_and_name(id, name) do
    TargetTrigger
    |> where(switch_trigger_id: ^id)
    |> where(target_name: ^name)
    |> Repo.one()
    |> return_tuple("TargetTrigger #{name} from switch_trigger: #{id} not found")
  rescue
    e -> {:error, e}
  end

  defp return_tuple(nil, nil_msg), do: ToTuple.error(nil_msg)
  defp return_tuple(value, _), do: ToTuple.ok(value)
end
