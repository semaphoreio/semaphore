defmodule Front.Models.Billing.PlanTest do
  use ExUnit.Case
  doctest Front.Models.Billing.Plan
  alias Front.Models.Billing.Plan
  alias InternalApi.Billing.PlanSummary, as: GrpcPlanSummary

  alias InternalApi.Billing.ChargingType, as: GrpcChargingType
  alias InternalApi.Billing.SubscriptionFlag, as: GrpcSubscriptionFlag
  alias InternalApi.Billing.SubscriptionSuspension, as: GrpcSubscriptionSuspension

  describe ".from_grpc" do
    test "parses correctly from a grpc struct" do
      # check that all combinations of flags, suspensions and charging types are parsed correctly
      flag_map = %{
        SUBSCRIPTION_FLAG_TRIAL: :trial,
        SUBSCRIPTION_FLAG_TRANSFERABLE_CREDITS: :transferable_credits,
        SUBSCRIPTION_FLAG_ELIGIBLE_FOR_TRIAL: :eligible_for_trial,
        SUBSCRIPTION_FLAG_ELIGIBLE_FOR_ADDONS: :eligible_for_addons
      }

      suspension_map = %{
        SUBSCRIPTION_SUSPENSION_NO_PAYMENT_METHOD: :no_payment_method,
        SUBSCRIPTION_SUSPENSION_MINER: :miner,
        SUBSCRIPTION_SUSPENSION_NO_CREDITS: :no_credits,
        SUBSCRIPTION_SUSPENSION_PAYMENT_FAILED: :payement_failed,
        SUBSCRIPTION_SUSPENSION_TERMS_OF_SERVICE: :terms_of_service,
        SUBSCRIPTION_SUSPENSION_ACCOUNT_AT_RISK: :account_at_risk
      }

      charging_type_map = %{
        CHARGING_TYPE_PREPAID: :prepaid,
        CHARGING_TYPE_POSTPAID: :postpaid,
        CHARGING_TYPE_FLATRATE: :flat,
        CHARGING_TYPE_GRANDFATHERED: :grandfathered
      }

      for {flag_key, flag_value} <- flag_map,
          {suspension_key, suspension_value} <- suspension_map,
          {charging_type_key, charging_type_value} <- charging_type_map do
        grpc_struct =
          new_plan_summary(
            flags: [GrpcSubscriptionFlag.value(flag_key)],
            suspensions: [GrpcSubscriptionSuspension.value(suspension_key)],
            charging_type: GrpcChargingType.value(charging_type_key)
          )

        assert Plan.from_grpc(grpc_struct) == %Plan{
                 display_name: "Plan Name",
                 details: [
                   %{
                     display_name: "Display Name",
                     display_description: "Display Description",
                     display_value: "Display Value"
                   }
                 ],
                 charging_type: charging_type_value,
                 subscription_ends_on: ~U[2020-01-01 00:00:00Z],
                 subscription_starts_on: ~U[2020-01-01 00:00:00Z],
                 flags: [flag_value],
                 suspensions: [suspension_value]
               }
      end
    end
  end

  defp new_plan_summary(params) do
    defaults = [
      name: "Plan Name",
      details: [
        GrpcPlanSummary.Detail.new(
          display_name: "Display Name",
          display_description: "Display Description",
          display_value: "Display Value"
        )
      ],
      subscription_ends_on: %{seconds: ~U[2020-01-01 00:00:00Z] |> DateTime.to_unix()},
      subscription_starts_on: %{seconds: ~U[2020-01-01 00:00:00Z] |> DateTime.to_unix()}
    ]

    defaults
    |> Keyword.merge(params)
    |> GrpcPlanSummary.new()
  end
end
