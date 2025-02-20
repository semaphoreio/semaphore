defmodule Gofer.DeploymentTrigger.Model.DeploymentTriggerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Gofer.DeploymentTrigger.Model.DeploymentTrigger, as: Trigger
  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Switch.Model.Switch
  alias Gofer.EctoRepo

  setup_all [:setup_deployment, :setup_switch, :setup_params]
  setup [:truncate_database]

  @required_fields ~w(
    deployment_id triggered_by triggered_at switch_id
    switch_trigger_id target_name switch_trigger_params
  )a

  describe "changeset/2" do
    test "casts default fields", %{params: params} do
      assert changeset = %Ecto.Changeset{valid?: true} = Trigger.changeset(%Trigger{}, params)
      assert trigger = %Trigger{} = Ecto.Changeset.apply_changes(changeset)

      assert Map.take(trigger, Map.keys(params)) == params
      assert %Trigger{state: :INITIALIZING, result: nil, reason: nil} = trigger
    end

    test "validates required fields", %{params: params} do
      assert %Ecto.Changeset{valid?: true} = Trigger.changeset(%Trigger{}, params)

      for field <- @required_fields do
        assert %Ecto.Changeset{valid?: false, errors: [{^field, {"can't be blank", _}}]} =
                 Trigger.changeset(%Trigger{}, Map.put(params, field, ""))
      end
    end

    test "validates if deployment exists", %{params: params} do
      assert %Ecto.Changeset{valid?: false, errors: [deployment_id: {"can't be blank", _}]} =
               Trigger.changeset(%Trigger{}, %{params | deployment_id: nil})

      assert {:error,
              %Ecto.Changeset{valid?: false, errors: [deployment_id: {"does not exist", _}]}} =
               EctoRepo.insert(
                 Trigger.changeset(%Trigger{}, %{params | deployment_id: UUID.uuid4()})
               )
    end

    test "validates if switch exists", %{params: params} do
      assert %Ecto.Changeset{valid?: false, errors: [switch_id: {"can't be blank", _}]} =
               Trigger.changeset(%Trigger{}, %{params | switch_id: nil})

      assert {:error, %Ecto.Changeset{valid?: false, errors: [switch_id: {"does not exist", _}]}} =
               EctoRepo.insert(Trigger.changeset(%Trigger{}, %{params | switch_id: UUID.uuid4()}))
    end

    test "validates if request token is unique", %{params: params} do
      assert %Ecto.Changeset{valid?: false, errors: [request_token: {"can't be blank", _}]} =
               Trigger.changeset(%Trigger{}, %{params | request_token: nil})

      assert {:ok, _trigger} = EctoRepo.insert(Trigger.changeset(%Trigger{}, params))

      assert {:error,
              %Ecto.Changeset{
                valid?: false,
                errors: [request_token: {"has already been taken", _}]
              }} = EctoRepo.insert(Trigger.changeset(%Trigger{}, %{params | target_name: "foo"}))
    end
  end

  defp truncate_database(_context) do
    {:ok, %Postgrex.Result{}} = EctoRepo.query("TRUNCATE TABLE deployment_triggers CASCADE;")
    :ok
  end

  defp setup_deployment(_context) do
    {:ok,
     deployment:
       EctoRepo.insert!(%Deployment{
         id: Ecto.UUID.generate(),
         name: "Deployment",
         description: "Deployment target",
         organization_id: UUID.uuid4(),
         project_id: UUID.uuid4(),
         unique_token: UUID.uuid4(),
         created_by: UUID.uuid4(),
         updated_by: UUID.uuid4(),
         state: :FINISHED,
         result: :SUCCESS,
         encrypted_secret: nil,
         secret_id: UUID.uuid4(),
         secret_name: "Secret name",
         subject_rules: [
           %Deployment.SubjectRule{
             type: :USER,
             subject_id: UUID.uuid4()
           }
         ],
         object_rules: [
           %Deployment.ObjectRule{
             type: :BRANCH,
             match_mode: :EXACT,
             pattern: "master"
           }
         ]
       })}
  end

  defp setup_switch(_context) do
    switch =
      %Switch{}
      |> Switch.changeset(%{
        id: UUID.uuid4(),
        ppl_id: UUID.uuid4(),
        prev_ppl_artefact_ids: [UUID.uuid4()],
        branch_name: "master",
        label: "master",
        git_ref_type: "branch"
      })
      |> EctoRepo.insert!()

    {:ok, switch: switch}
  end

  defp setup_params(context) do
    {:ok,
     params: %{
       deployment_id: context.deployment.id,
       switch_id: context.switch.id,
       git_ref_type: context.switch.git_ref_type,
       git_ref_label: context.switch.label,
       triggered_by: UUID.uuid4(),
       triggered_at: DateTime.utc_now(),
       switch_trigger_id: UUID.uuid4(),
       target_name: "target_name",
       request_token: UUID.uuid4(),
       switch_trigger_params: %{
         "id" => UUID.uuid4()
       }
     }}
  end
end
