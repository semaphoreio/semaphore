defmodule InternalApi.Billing.PlanType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:FREE, 0)
  field(:PAID, 1)
  field(:TRIAL, 2)
  field(:OPEN_SOURCE, 3)
  field(:GRANDFATHERED_CLASSIC, 4)
  field(:PREPAID, 5)
  field(:FLAT_ANNUAL, 6)
  field(:GRANDFATHERED_CLASSIC_TRIAL, 7)
end

defmodule InternalApi.Billing.PaymentMethod do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:CREDIT_CARD, 0)
  field(:WIRE, 1)
end

defmodule InternalApi.Billing.SubscriptionFlag do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:SUBSCRIPTION_FLAG_UNSPECIFIED, 0)
  field(:SUBSCRIPTION_FLAG_TRIAL, 1)
  field(:SUBSCRIPTION_FLAG_TRANSFERABLE_CREDITS, 2)
  field(:SUBSCRIPTION_FLAG_ELIGIBLE_FOR_TRIAL, 3)
  field(:SUBSCRIPTION_FLAG_ELIGIBLE_FOR_ADDONS, 4)
  field(:SUBSCRIPTION_FLAG_NOT_CHARGED, 5)
  field(:SUBSCRIPTION_FLAG_FREE, 6)
  field(:SUBSCRIPTION_FLAG_TRIAL_END_NACK, 7)
end

defmodule InternalApi.Billing.SubscriptionSuspension do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:SUBSCRIPTION_SUSPENSION_UNSPECIFIED, 0)
  field(:SUBSCRIPTION_SUSPENSION_NO_PAYMENT_METHOD, 1)
  field(:SUBSCRIPTION_SUSPENSION_MINER, 2)
  field(:SUBSCRIPTION_SUSPENSION_NO_CREDITS, 3)
  field(:SUBSCRIPTION_SUSPENSION_PAYMENT_FAILED, 4)
  field(:SUBSCRIPTION_SUSPENSION_TERMS_OF_SERVICE, 5)
  field(:SUBSCRIPTION_SUSPENSION_ACCOUNT_AT_RISK, 6)
  field(:SUBSCRIPTION_SUSPENSION_PIPELINE_BLOCK, 7)
end

defmodule InternalApi.Billing.ChargingType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:CHARGING_TYPE_UNSPECIFIED, 0)
  field(:CHARGING_TYPE_NONE, 1)
  field(:CHARGING_TYPE_PREPAID, 2)
  field(:CHARGING_TYPE_POSTPAID, 3)
  field(:CHARGING_TYPE_FLATRATE, 4)
  field(:CHARGING_TYPE_GRANDFATHERED, 5)
end

defmodule InternalApi.Billing.SpendingType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:SPENDING_TYPE_UNSPECIFIED, 0)
  field(:SPENDING_TYPE_MACHINE_TIME, 1)
  field(:SPENDING_TYPE_SEAT, 2)
  field(:SPENDING_TYPE_STORAGE, 3)
  field(:SPENDING_TYPE_ADDON, 4)
  field(:SPENDING_TYPE_MACHINE_CAPACITY, 5)
end

defmodule InternalApi.Billing.CreditType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:CREDIT_TYPE_UNSPECIFIED, 0)
  field(:CREDIT_TYPE_PREPAID, 1)
  field(:CREDIT_TYPE_GIFT, 2)
  field(:CREDIT_TYPE_SUBSCRIPTION, 3)
  field(:CREDIT_TYPE_EDUCATIONAL, 4)
end

defmodule InternalApi.Billing.CreditBalanceType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:CREDIT_BALANCE_TYPE_UNSPECIFIED, 0)
  field(:CREDIT_BALANCE_TYPE_CHARGE, 1)
  field(:CREDIT_BALANCE_TYPE_DEPOSIT, 2)
end

defmodule InternalApi.Billing.AcknowledgeTrialEndRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
end

defmodule InternalApi.Billing.AcknowledgeTrialEndResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Billing.CanSetupOrganizationRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:owner_id, 1, type: :string, json_name: "ownerId")
end

defmodule InternalApi.Billing.CanSetupOrganizationResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:allowed, 1, type: :bool)
  field(:errors, 2, repeated: true, type: :string)
end

defmodule InternalApi.Billing.CanUpgradePlanRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:plan_slug, 2, type: :string, json_name: "planSlug")
end

defmodule InternalApi.Billing.CanUpgradePlanResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:allowed, 1, type: :bool)
  field(:errors, 2, repeated: true, type: :string)
end

defmodule InternalApi.Billing.ListProjectsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:from_date, 2, type: Google.Protobuf.Timestamp, json_name: "fromDate")
  field(:to_date, 3, type: Google.Protobuf.Timestamp, json_name: "toDate")
end

defmodule InternalApi.Billing.ListProjectsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:projects, 1, repeated: true, type: InternalApi.Billing.Project)
end

defmodule InternalApi.Billing.DescribeProjectRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:from_date, 2, type: Google.Protobuf.Timestamp, json_name: "fromDate")
  field(:to_date, 3, type: Google.Protobuf.Timestamp, json_name: "toDate")
end

defmodule InternalApi.Billing.DescribeProjectResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project, 1, type: InternalApi.Billing.Project)
  field(:costs, 2, repeated: true, type: InternalApi.Billing.ProjectCost)
end

defmodule InternalApi.Billing.Project do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:cost, 3, type: InternalApi.Billing.ProjectCost)
end

defmodule InternalApi.Billing.ProjectCost do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:from_date, 1, type: Google.Protobuf.Timestamp, json_name: "fromDate")
  field(:to_date, 2, type: Google.Protobuf.Timestamp, json_name: "toDate")
  field(:total_price, 3, type: :string, json_name: "totalPrice")
  field(:workflow_count, 4, type: :int32, json_name: "workflowCount")

  field(:spending_groups, 5,
    repeated: true,
    type: InternalApi.Billing.SpendingGroup,
    json_name: "spendingGroups"
  )

  field(:workflow_trends, 6,
    repeated: true,
    type: InternalApi.Billing.SpendingTrend,
    json_name: "workflowTrends"
  )
end

defmodule InternalApi.Billing.SetupOrganizationRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:organization_username, 1, type: :string, json_name: "organizationUsername")
  field(:organization_owner_id, 2, type: :string, json_name: "organizationOwnerId")
  field(:plan, 3, type: InternalApi.Billing.PlanType, enum: true)
  field(:force_creation, 4, type: :bool, json_name: "forceCreation")
  field(:plan_type_slug, 5, type: :string, json_name: "planTypeSlug")
end

defmodule InternalApi.Billing.SetupOrganizationResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
end

defmodule InternalApi.Billing.PlanStatusRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:org_username, 2, type: :string, json_name: "orgUsername")
end

defmodule InternalApi.Billing.PlanStatusResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:status, 1, type: Google.Rpc.Status)
  field(:for_owner, 2, type: :string, json_name: "forOwner")
  field(:for_owner_mobile, 3, type: :string, json_name: "forOwnerMobile")
  field(:for_member, 4, type: :string, json_name: "forMember")
  field(:for_member_mobile, 5, type: :string, json_name: "forMemberMobile")
end

defmodule InternalApi.Billing.PlanStateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:org_username, 2, type: :string, json_name: "orgUsername")
end

defmodule InternalApi.Billing.PlanStateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:plan_type, 1, type: InternalApi.Billing.PlanType, json_name: "planType", enum: true)
  field(:plan_badge, 2, type: :string, json_name: "planBadge")
  field(:actionable_header, 3, type: :string, json_name: "actionableHeader")
  field(:non_actionable_header, 4, type: :string, json_name: "nonActionableHeader")
  field(:plan_type_slug, 5, type: :string, json_name: "planTypeSlug")
  field(:segment, 6, type: :string)
end

defmodule InternalApi.Billing.OrganizationStatusRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
end

defmodule InternalApi.Billing.OrganizationStatusResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:plan, 1, type: InternalApi.Billing.PlanType, enum: true)

  field(:last_charge_without_tax_amount_in_cents, 2,
    type: :int32,
    json_name: "lastChargeWithoutTaxAmountInCents"
  )

  field(:plan_type_slug, 3, type: :string, json_name: "planTypeSlug")
end

defmodule InternalApi.Billing.ListPlansRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Billing.ListPlansResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:plans, 1, repeated: true, type: InternalApi.Billing.Plan)
end

defmodule InternalApi.Billing.Plan do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:price, 3, type: :int32)
  field(:credits, 4, type: :int32)
  field(:charge, 5, type: :bool)
  field(:block, 6, type: :bool)
  field(:created_at, 7, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:updated_at, 8, type: Google.Protobuf.Timestamp, json_name: "updatedAt")
end

defmodule InternalApi.Billing.ListFeaturesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:target, 1, type: InternalApi.Billing.FeatureTarget)
end

defmodule InternalApi.Billing.ListFeaturesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:features, 1, repeated: true, type: InternalApi.Billing.FeatureWithValues)
end

defmodule InternalApi.Billing.FeatureWithValues do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:feature, 1, type: InternalApi.Billing.Feature)
  field(:fallback_value, 2, type: InternalApi.Billing.FeatureValue, json_name: "fallbackValue")
  field(:value, 3, type: InternalApi.Billing.FeatureValue)
end

defmodule InternalApi.Billing.Feature do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:type, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
end

defmodule InternalApi.Billing.FeatureValue do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:availability, 1, type: InternalApi.Feature.Availability)
end

defmodule InternalApi.Billing.ListMachinesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:target, 1, type: InternalApi.Billing.FeatureTarget)
end

defmodule InternalApi.Billing.ListMachinesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:machines, 1, repeated: true, type: InternalApi.Billing.MachineWithValues)
end

defmodule InternalApi.Billing.MachineWithValues do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:machine, 1, type: InternalApi.Billing.Machine)
  field(:fallback_value, 2, type: InternalApi.Billing.MachineValue, json_name: "fallbackValue")
  field(:value, 3, type: InternalApi.Billing.MachineValue)
end

defmodule InternalApi.Billing.Machine do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:type, 1, type: :string)
  field(:platform, 3, type: InternalApi.Feature.Machine.Platform, enum: true)
  field(:vcpu, 4, type: :string)
  field(:ram, 5, type: :string)
  field(:disk, 6, type: :string)
end

defmodule InternalApi.Billing.MachineValue do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:availability, 1, type: InternalApi.Feature.Availability)
  field(:default_os_image, 2, type: :string, json_name: "defaultOsImage")
  field(:os_images, 3, repeated: true, type: :string, json_name: "osImages")
end

defmodule InternalApi.Billing.UpdateFeaturesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:target, 1, type: InternalApi.Billing.FeatureTarget)
  field(:requester_id, 2, type: :string, json_name: "requesterId")
  field(:updates, 3, repeated: true, type: InternalApi.Billing.FeatureWithValues)
  field(:removes, 4, repeated: true, type: InternalApi.Billing.Feature)
end

defmodule InternalApi.Billing.UpdateFeaturesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Billing.UpdateMachinesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:target, 1, type: InternalApi.Billing.FeatureTarget)
  field(:requester_id, 2, type: :string, json_name: "requesterId")
  field(:updates, 3, repeated: true, type: InternalApi.Billing.MachineWithValues)
  field(:removes, 4, repeated: true, type: InternalApi.Billing.Machine)
end

defmodule InternalApi.Billing.UpdateMachinesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Billing.FeatureTarget do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:plan_id, 2, type: :string, json_name: "planId")
end

defmodule InternalApi.Billing.CreditCardAdded do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:for_plan, 3, type: InternalApi.Billing.PlanType, json_name: "forPlan", enum: true)
  field(:plan_type_slug, 4, type: :string, json_name: "planTypeSlug")
end

defmodule InternalApi.Billing.CreditCardReconnected do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.SpendingUpdated do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:current_billing_cycle, 2, type: :string, json_name: "currentBillingCycle")
  field(:current_spending_in_cents, 3, type: :int32, json_name: "currentSpendingInCents")
  field(:total_spending_in_cents, 4, type: :int32, json_name: "totalSpendingInCents")
  field(:timestamp, 5, type: Google.Protobuf.Timestamp)
  field(:previous_spending_in_cents, 6, type: :int32, json_name: "previousSpendingInCents")
  field(:last_charge_amount_in_cents, 7, type: :int32, json_name: "lastChargeAmountInCents")

  field(:last_charge_without_tax_amount_in_cents, 17,
    type: :int32,
    json_name: "lastChargeWithoutTaxAmountInCents"
  )

  field(:last_charge_date, 8, type: :string, json_name: "lastChargeDate")
  field(:total_charge_amount_in_cents, 9, type: :int32, json_name: "totalChargeAmountInCents")
  field(:current_discount_in_cents, 10, type: :int32, json_name: "currentDiscountInCents")
  field(:current_mac_spending_in_cents, 11, type: :int32, json_name: "currentMacSpendingInCents")
  field(:total_mac_spending_in_cents, 12, type: :int32, json_name: "totalMacSpendingInCents")

  field(:current_linux_spending_in_cents, 13,
    type: :int32,
    json_name: "currentLinuxSpendingInCents"
  )

  field(:total_linux_spending_in_cents, 14, type: :int32, json_name: "totalLinuxSpendingInCents")

  field(:second_last_charge_amount_in_cents, 15,
    type: :int32,
    json_name: "secondLastChargeAmountInCents"
  )

  field(:second_last_charge_without_tax_amount_in_cents, 18,
    type: :int32,
    json_name: "secondLastChargeWithoutTaxAmountInCents"
  )

  field(:second_last_charge_date, 16, type: :string, json_name: "secondLastChargeDate")
  field(:monthly_budget_in_cents, 19, type: :string, json_name: "monthlyBudgetInCents")

  field(:charge_history, 20,
    repeated: true,
    type: InternalApi.Billing.MonthlyCharge,
    json_name: "chargeHistory"
  )

  field(:payment_method, 21, type: :string, json_name: "paymentMethod")
end

defmodule InternalApi.Billing.MonthlyCharge do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:month_name, 1, type: :string, json_name: "monthName")
  field(:charge_in_cents, 2, type: :int32, json_name: "chargeInCents")
end

defmodule InternalApi.Billing.ChargeSuccess do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:amount_charged_in_cents, 3, type: :int32, json_name: "amountChargedInCents")
end

defmodule InternalApi.Billing.FirstChargeSuccess do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:amount_charged_in_cents, 3, type: :int32, json_name: "amountChargedInCents")

  field(:without_tax_amount_charged_in_cents, 4,
    type: :int32,
    json_name: "withoutTaxAmountChargedInCents"
  )
end

defmodule InternalApi.Billing.ChargeFailure do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:amount_charged_in_cents, 3, type: :int32, json_name: "amountChargedInCents")
end

defmodule InternalApi.Billing.PaymentSuccess do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:amount_charged_in_cents, 3, type: :int32, json_name: "amountChargedInCents")
  field(:reason, 4, type: :string)
  field(:method, 5, type: InternalApi.Billing.PaymentMethod, enum: true)
end

defmodule InternalApi.Billing.PaymentFailure do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:amount_charged_in_cents, 3, type: :int32, json_name: "amountChargedInCents")
  field(:reason, 4, type: :string)
  field(:method, 5, type: InternalApi.Billing.PaymentMethod, enum: true)
end

defmodule InternalApi.Billing.SubscriptionCanceled do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:subscription_on_fastspring, 3, type: :string, json_name: "subscriptionOnFastspring")
  field(:for_plan, 4, type: InternalApi.Billing.PlanType, json_name: "forPlan", enum: true)
  field(:plan_type_slug, 5, type: :string, json_name: "planTypeSlug")
end

defmodule InternalApi.Billing.PlanChanged do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:new_plan, 3, type: :string, json_name: "newPlan")
end

defmodule InternalApi.Billing.SegmentChanged do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:new_segment, 3, type: :string, json_name: "newSegment")
end

defmodule InternalApi.Billing.TrialStarted do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:days_left_in_trial, 3, type: :int32, json_name: "daysLeftInTrial")
end

defmodule InternalApi.Billing.TrialStatusUpdate do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:days_left_in_trial, 3, type: :int32, json_name: "daysLeftInTrial")
end

defmodule InternalApi.Billing.TrialExpired do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.TrialAbandoned do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.NoteChanged do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:note, 2, type: :string)
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.TrialOwnerOnboarded do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:position_in_company, 2, type: :string, json_name: "positionInCompany")
  field(:company_team_size, 3, type: :string, json_name: "companyTeamSize")
  field(:company_previous_tool, 4, type: :string, json_name: "companyPreviousTool")
  field(:company_ci_goal, 5, type: :string, json_name: "companyCiGoal")
  field(:timestamp, 6, type: Google.Protobuf.Timestamp)
  field(:user_name, 7, type: :string, json_name: "userName")
  field(:company_name, 8, type: :string, json_name: "companyName")
  field(:learned_from, 9, type: :string, json_name: "learnedFrom")
end

defmodule InternalApi.Billing.PaidOwnerOnboarded do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:feedback, 2, type: :string)

  field(:requested_concierge_onboarding, 3, type: :bool, json_name: "requestedConciergeOnboarding")

  field(:timestamp, 4, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.CreditsChanged do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.ListSpendingsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
end

defmodule InternalApi.Billing.ListSpendingsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:spendings, 1, repeated: true, type: InternalApi.Billing.Spending)
end

defmodule InternalApi.Billing.CurrentSpendingRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
end

defmodule InternalApi.Billing.CurrentSpendingResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:spending, 1, type: InternalApi.Billing.Spending)
end

defmodule InternalApi.Billing.Spending do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:display_name, 2, type: :string, json_name: "displayName")
  field(:from_date, 3, type: Google.Protobuf.Timestamp, json_name: "fromDate")
  field(:to_date, 4, type: Google.Protobuf.Timestamp, json_name: "toDate")
  field(:summary, 5, type: InternalApi.Billing.SpendingSummary)
  field(:plan_summary, 6, type: InternalApi.Billing.PlanSummary, json_name: "planSummary")
  field(:groups, 7, repeated: true, type: InternalApi.Billing.SpendingGroup)
end

defmodule InternalApi.Billing.SpendingSummary do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:total_bill, 1, type: :string, json_name: "totalBill")
  field(:subscription_total, 2, type: :string, json_name: "subscriptionTotal")
  field(:usage_total, 3, type: :string, json_name: "usageTotal")
  field(:usage_used, 4, type: :string, json_name: "usageUsed")
  field(:credits_total, 5, type: :string, json_name: "creditsTotal")
  field(:credits_used, 6, type: :string, json_name: "creditsUsed")
  field(:credits_starting, 7, type: :string, json_name: "creditsStarting")
  field(:discount, 8, type: :string)
  field(:discount_amount, 9, type: :string, json_name: "discountAmount")
end

defmodule InternalApi.Billing.PlanSummary.Detail do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:display_name, 2, type: :string, json_name: "displayName")
  field(:display_description, 3, type: :string, json_name: "displayDescription")
  field(:display_value, 4, type: :string, json_name: "displayValue")
end

defmodule InternalApi.Billing.PlanSummary do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:details, 3, repeated: true, type: InternalApi.Billing.PlanSummary.Detail)

  field(:charging_type, 4,
    type: InternalApi.Billing.ChargingType,
    json_name: "chargingType",
    enum: true
  )

  field(:subscription_starts_on, 5,
    type: Google.Protobuf.Timestamp,
    json_name: "subscriptionStartsOn"
  )

  field(:subscription_ends_on, 6, type: Google.Protobuf.Timestamp, json_name: "subscriptionEndsOn")

  field(:suspensions, 7,
    repeated: true,
    type: InternalApi.Billing.SubscriptionSuspension,
    enum: true
  )

  field(:flags, 8, repeated: true, type: InternalApi.Billing.SubscriptionFlag, enum: true)
  field(:payment_method_url, 9, type: :string, json_name: "paymentMethodUrl")
  field(:slug, 10, type: :string)
end

defmodule InternalApi.Billing.DescribeSpendingRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:spending_id, 1, type: :string, json_name: "spendingId")
end

defmodule InternalApi.Billing.DescribeSpendingResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:spending, 1, type: InternalApi.Billing.Spending)
end

defmodule InternalApi.Billing.SpendingGroup do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:type, 1, type: InternalApi.Billing.SpendingType, enum: true)
  field(:items, 2, repeated: true, type: InternalApi.Billing.SpendingItem)
  field(:total_price, 3, type: :string, json_name: "totalPrice")
  field(:trends, 4, repeated: true, type: InternalApi.Billing.SpendingTrend)
end

defmodule InternalApi.Billing.SpendingItem do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:display_name, 1, type: :string, json_name: "displayName")
  field(:display_description, 2, type: :string, json_name: "displayDescription")
  field(:units, 3, type: :int64)
  field(:unit_price, 4, type: :string, json_name: "unitPrice")
  field(:total_price, 5, type: :string, json_name: "totalPrice")
  field(:name, 6, type: :string)
  field(:trends, 7, repeated: true, type: InternalApi.Billing.SpendingTrend)
  field(:enabled, 8, type: :bool)
end

defmodule InternalApi.Billing.SpendingTrend do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
  field(:units, 2, type: :int64)
  field(:price, 3, type: :string)
end

defmodule InternalApi.Billing.ListDailyCostsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:spending_id, 1, type: :string, json_name: "spendingId")
end

defmodule InternalApi.Billing.ListDailyCostsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:costs, 1, repeated: true, type: InternalApi.Billing.DailyCost)
end

defmodule InternalApi.Billing.DailyCost do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:type, 1, type: InternalApi.Billing.SpendingType, enum: true)
  field(:price_for_the_day, 2, type: :string, json_name: "priceForTheDay")
  field(:price_up_to_the_day, 3, type: :string, json_name: "priceUpToTheDay")
  field(:day, 4, type: Google.Protobuf.Timestamp)
  field(:prediction, 5, type: :bool)
  field(:items, 6, repeated: true, type: InternalApi.Billing.SpendingItem)
end

defmodule InternalApi.Billing.ListSpendingSeatsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:spending_id, 1, type: :string, json_name: "spendingId")
end

defmodule InternalApi.Billing.ListSpendingSeatsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:seats, 1, repeated: true, type: InternalApi.Usage.Seat)
end

defmodule InternalApi.Billing.ListInvoicesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
end

defmodule InternalApi.Billing.ListInvoicesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:invoices, 1, repeated: true, type: InternalApi.Billing.Invoice)
end

defmodule InternalApi.Billing.Invoice do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:display_name, 1, type: :string, json_name: "displayName")
  field(:total_bill, 2, type: :string, json_name: "totalBill")
  field(:total_bill_no_tax, 3, type: :string, json_name: "totalBillNoTax")
  field(:pdf_download_url, 4, type: :string, json_name: "pdfDownloadUrl")
end

defmodule InternalApi.Billing.GetBudgetRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
end

defmodule InternalApi.Billing.GetBudgetResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:budget, 1, type: InternalApi.Billing.Budget)
end

defmodule InternalApi.Billing.SetBudgetRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:budget, 2, type: InternalApi.Billing.Budget)
end

defmodule InternalApi.Billing.SetBudgetResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:budget, 1, type: InternalApi.Billing.Budget)
end

defmodule InternalApi.Billing.Budget do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:limit, 1, type: :string)
  field(:email, 2, type: :string)
end

defmodule InternalApi.Billing.CreditsUsageRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
end

defmodule InternalApi.Billing.CreditsUsageResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:credits_available, 1,
    repeated: true,
    type: InternalApi.Billing.CreditAvailable,
    json_name: "creditsAvailable"
  )

  field(:credits_balance, 2,
    repeated: true,
    type: InternalApi.Billing.CreditBalance,
    json_name: "creditsBalance"
  )
end

defmodule InternalApi.Billing.CreditBalance do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:type, 1, type: InternalApi.Billing.CreditBalanceType, enum: true)
  field(:description, 2, type: :string)
  field(:amount, 3, type: :string)
  field(:occured_at, 4, type: Google.Protobuf.Timestamp, json_name: "occuredAt")
end

defmodule InternalApi.Billing.CreditAvailable do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:type, 1, type: InternalApi.Billing.CreditType, enum: true)
  field(:amount, 2, type: :string)
  field(:given_at, 3, type: Google.Protobuf.Timestamp, json_name: "givenAt")
  field(:expires_at, 4, type: Google.Protobuf.Timestamp, json_name: "expiresAt")
end

defmodule InternalApi.Billing.UpgradePlanRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:plan_slug, 2, type: :string, json_name: "planSlug")
end

defmodule InternalApi.Billing.UpgradePlanResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:spending_id, 1, type: :string, json_name: "spendingId")
  field(:errors, 2, repeated: true, type: :string)
  field(:payment_method_url, 3, type: :string, json_name: "paymentMethodUrl")
end

defmodule InternalApi.Billing.BillingService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.Billing.BillingService",
    protoc_gen_elixir_version: "0.13.0"

  rpc(
    :CanSetupOrganization,
    InternalApi.Billing.CanSetupOrganizationRequest,
    InternalApi.Billing.CanSetupOrganizationResponse
  )

  rpc(
    :SetupOrganization,
    InternalApi.Billing.SetupOrganizationRequest,
    InternalApi.Billing.SetupOrganizationResponse
  )

  rpc(:PlanStatus, InternalApi.Billing.PlanStatusRequest, InternalApi.Billing.PlanStatusResponse)

  rpc(
    :OrganizationStatus,
    InternalApi.Billing.OrganizationStatusRequest,
    InternalApi.Billing.OrganizationStatusResponse
  )

  rpc(:PlanState, InternalApi.Billing.PlanStateRequest, InternalApi.Billing.PlanStateResponse)

  rpc(:ListPlans, InternalApi.Billing.ListPlansRequest, InternalApi.Billing.ListPlansResponse)

  rpc(
    :ListFeatures,
    InternalApi.Billing.ListFeaturesRequest,
    InternalApi.Billing.ListFeaturesResponse
  )

  rpc(
    :ListMachines,
    InternalApi.Billing.ListMachinesRequest,
    InternalApi.Billing.ListMachinesResponse
  )

  rpc(
    :UpdateFeatures,
    InternalApi.Billing.UpdateFeaturesRequest,
    InternalApi.Billing.UpdateFeaturesResponse
  )

  rpc(
    :UpdateMachines,
    InternalApi.Billing.UpdateMachinesRequest,
    InternalApi.Billing.UpdateMachinesResponse
  )

  rpc(
    :ListSpendings,
    InternalApi.Billing.ListSpendingsRequest,
    InternalApi.Billing.ListSpendingsResponse
  )

  rpc(
    :ListSpendingSeats,
    InternalApi.Billing.ListSpendingSeatsRequest,
    InternalApi.Billing.ListSpendingSeatsResponse
  )

  rpc(
    :DescribeSpending,
    InternalApi.Billing.DescribeSpendingRequest,
    InternalApi.Billing.DescribeSpendingResponse
  )

  rpc(
    :CurrentSpending,
    InternalApi.Billing.CurrentSpendingRequest,
    InternalApi.Billing.CurrentSpendingResponse
  )

  rpc(
    :ListInvoices,
    InternalApi.Billing.ListInvoicesRequest,
    InternalApi.Billing.ListInvoicesResponse
  )

  rpc(
    :ListDailyCosts,
    InternalApi.Billing.ListDailyCostsRequest,
    InternalApi.Billing.ListDailyCostsResponse
  )

  rpc(:SetBudget, InternalApi.Billing.SetBudgetRequest, InternalApi.Billing.SetBudgetResponse)

  rpc(:GetBudget, InternalApi.Billing.GetBudgetRequest, InternalApi.Billing.GetBudgetResponse)

  rpc(
    :CreditsUsage,
    InternalApi.Billing.CreditsUsageRequest,
    InternalApi.Billing.CreditsUsageResponse
  )

  rpc(
    :CanUpgradePlan,
    InternalApi.Billing.CanUpgradePlanRequest,
    InternalApi.Billing.CanUpgradePlanResponse
  )

  rpc(
    :UpgradePlan,
    InternalApi.Billing.UpgradePlanRequest,
    InternalApi.Billing.UpgradePlanResponse
  )

  rpc(
    :ListProjects,
    InternalApi.Billing.ListProjectsRequest,
    InternalApi.Billing.ListProjectsResponse
  )

  rpc(
    :DescribeProject,
    InternalApi.Billing.DescribeProjectRequest,
    InternalApi.Billing.DescribeProjectResponse
  )

  rpc(
    :AcknowledgeTrialEnd,
    InternalApi.Billing.AcknowledgeTrialEndRequest,
    InternalApi.Billing.AcknowledgeTrialEndResponse
  )
end

defmodule InternalApi.Billing.BillingService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Billing.BillingService.Service
end
