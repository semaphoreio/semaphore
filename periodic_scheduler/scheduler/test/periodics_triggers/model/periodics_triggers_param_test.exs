defmodule Scheduler.PeriodicsTriggers.Model.PeriodicsTriggersParamTest do
  use ExUnit.Case, async: true
  alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggersParam

  describe "changeset/2" do
    test "without name is invalid" do
      assert %Ecto.Changeset{valid?: false, errors: [name: {"can't be blank", _}]} =
               PeriodicsTriggersParam.changeset(%PeriodicsTriggersParam{}, %{
                 name: "",
                 value: "value"
               })
    end

    test "without value is valid" do
      assert changeset =
               %Ecto.Changeset{valid?: true, errors: []} =
               PeriodicsTriggersParam.changeset(%PeriodicsTriggersParam{}, %{
                 name: "name",
                 value: ""
               })

      assert %PeriodicsTriggersParam{name: "name", value: ""} =
               Ecto.Changeset.apply_changes(changeset)
    end

    test "with both name and value is valid" do
      assert changeset =
               %Ecto.Changeset{valid?: true, errors: []} =
               PeriodicsTriggersParam.changeset(%PeriodicsTriggersParam{}, %{
                 name: "name",
                 value: "value"
               })

      assert %PeriodicsTriggersParam{name: "name", value: "value"} =
               Ecto.Changeset.apply_changes(changeset)
    end
  end
end
