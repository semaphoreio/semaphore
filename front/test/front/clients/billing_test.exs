defmodule Front.Clients.BillingTest do
  use ExUnit.Case

  alias Front.Clients.Billing

  describe ".organization_status" do
    test "returns the formatted status from the api" do
      res = %InternalApi.Billing.OrganizationStatusResponse{
        plan: InternalApi.Billing.PlanType.value(:PAID),
        plan_type_slug: "paid",
        last_charge_without_tax_amount_in_cents: 0
      }

      GrpcMock.stub(BillingMock, :organization_status, res)

      result = Billing.organization_status("12")

      assert result == %{plan: "paid", last_charge_in_dollars: 0}
    end

    test "when the plan is flat_annual => returns the status" do
      res = %InternalApi.Billing.OrganizationStatusResponse{
        plan: InternalApi.Billing.PlanType.value(:FLAT_ANNUAL),
        plan_type_slug: "flat-annual",
        last_charge_without_tax_amount_in_cents: 0
      }

      GrpcMock.stub(BillingMock, :organization_status, res)

      result = Billing.organization_status("12")

      assert result == %{plan: "flat-annual", last_charge_in_dollars: 0.0}
    end
  end
end
