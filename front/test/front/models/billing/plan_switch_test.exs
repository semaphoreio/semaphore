defmodule Front.Models.Billing.PlanSwitchTest do
  use ExUnit.Case
  doctest Front.Models.Billing.PlanSwitch
  alias Front.Models.Billing.PlanSwitch

  setup do
    :ok
  end

  describe "list_plans/1" do
    setup do
      stub_billing_check()

      %{
        org_id: Ecto.UUID.generate()
      }
    end

    test "lists all possible plans to switch for the organization when billing sllows for a switch",
         %{
           org_id: org_id
         } do
      available_plans = PlanSwitch.list_plans(org_id)

      assert length(available_plans) == 3
    end

    test "does not list any plans when billing does not allow for a switch",
         %{
           org_id: org_id
         } do
      stub_billing_check(["error"])

      available_plans = PlanSwitch.list_plans(org_id)

      assert available_plans == []
    end
  end

  describe "current_plan_type/1" do
    test "returns the plan type for the provided plan" do
      assertions = [
        {Support.Stubs.Billing.stub_plan(:startup_hybrid), :startup_hybrid},
        {Support.Stubs.Billing.stub_plan(:startup_hybrid_prepaid), :startup_hybrid},
        {Support.Stubs.Billing.stub_plan(:free), :free},
        {Support.Stubs.Billing.stub_plan(:open_source), :open_source},
        {Support.Stubs.Billing.stub_plan(:grandfathered), :unknown},
        {Support.Stubs.Billing.stub_plan(:classic_flat_4), :unknown},
        {Support.Stubs.Billing.stub_plan(:scaleup_cloud), :scaleup},
        {Support.Stubs.Billing.stub_plan(:scaleup_hybrid), :scaleup}
      ]

      for {grpc_plan_summary, expected_plan_type} <- assertions do
        plan = Front.Models.Billing.Plan.from_grpc(grpc_plan_summary)

        assert PlanSwitch.current_plan_type(plan) == expected_plan_type,
               "Expected #{expected_plan_type} for #{plan.display_name}, got #{PlanSwitch.current_plan_type(plan)}"
      end
    end
  end

  describe "plan_type_to_slug/1" do
    test "returns the plan slug for the provided plan type" do
      assert PlanSwitch.plan_type_to_slug(:startup_cloud) == "paid"
      assert PlanSwitch.plan_type_to_slug(:startup_hybrid) == "startup_hybrid"
      assert PlanSwitch.plan_type_to_slug(:free) == "free"
      assert PlanSwitch.plan_type_to_slug(:open_source) == ""
      assert PlanSwitch.plan_type_to_slug("startup_cloud") == "paid"
      assert PlanSwitch.plan_type_to_slug("startup_hybrid") == "startup_hybrid"
      assert PlanSwitch.plan_type_to_slug("free") == "free"
      assert PlanSwitch.plan_type_to_slug("open_source") == ""
    end
  end

  describe "validate_plan_change/2" do
    setup do
      stub_user_count(1)
      stub_agent_count(0)
      stub_billing_check()

      [
        org_id: Ecto.UUID.generate()
      ]
    end

    test "succeedes", %{org_id: org_id} do
      stub_user_count(5)
      stub_agent_count(5)

      assert :ok = PlanSwitch.validate_plan_change(org_id, :free)
    end

    test "fails when user limit is exceeded", %{org_id: org_id} do
      stub_user_count(6)

      assert {:error, [users: _]} = PlanSwitch.validate_plan_change(org_id, :free)
    end

    test "fails when agent limit is exceeded", %{org_id: org_id} do
      stub_agent_count(6)

      assert {:error, [agents: _]} = PlanSwitch.validate_plan_change(org_id, :free)
    end

    test "fails when billing does not allow organization to switch plans", %{org_id: org_id} do
      stub_billing_check(["too many orgs", "too many trials"])

      assert {:error, [plan: "too many orgs", plan: "too many trials"]} =
               PlanSwitch.validate_plan_change(org_id, :free)
    end
  end

  defp stub_user_count(count) do
    members =
      for _ <- 1..count do
        InternalApi.RBAC.ListMembersResponse.Member.new(subject: InternalApi.RBAC.Subject.new())
      end

    GrpcMock.stub(
      RBACMock,
      :list_members,
      InternalApi.RBAC.ListMembersResponse.new(members: members)
    )
  end

  def stub_agent_count(count) do
    agents =
      for _ <- 1..count do
        InternalApi.SelfHosted.Agent.new()
      end

    GrpcMock.stub(
      SelfHostedAgentsMock,
      :list_agents,
      InternalApi.SelfHosted.ListAgentsResponse.new(total_count: count, agents: agents)
    )
  end

  @spec stub_billing_check([error :: String.t()]) :: :ok
  def stub_billing_check(errors \\ []) do
    GrpcMock.stub(
      BillingMock,
      :can_upgrade_plan,
      fn %{plan_slug: ""}, _ ->
        InternalApi.Billing.CanUpgradePlanResponse.new(allowed: errors == [], errors: errors)
      end
    )
  end
end
