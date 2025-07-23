defmodule InternalApi.Billing.AcknowledgeTrialEndRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Billing.AcknowledgeTrialEndResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Billing.CanSetupOrganizationRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          owner_id: String.t()
        }
  defstruct [:owner_id]

  field(:owner_id, 1, type: :string)
end

defmodule InternalApi.Billing.CanSetupOrganizationResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          allowed: boolean,
          errors: [String.t()]
        }
  defstruct [:allowed, :errors]

  field(:allowed, 1, type: :bool)
  field(:errors, 2, repeated: true, type: :string)
end

defmodule InternalApi.Billing.CanUpgradePlanRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          plan_slug: String.t()
        }
  defstruct [:org_id, :plan_slug]

  field(:org_id, 1, type: :string)
  field(:plan_slug, 2, type: :string)
end

defmodule InternalApi.Billing.CanUpgradePlanResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          allowed: boolean,
          errors: [String.t()]
        }
  defstruct [:allowed, :errors]

  field(:allowed, 1, type: :bool)
  field(:errors, 2, repeated: true, type: :string)
end

defmodule InternalApi.Billing.ListProjectsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          from_date: Google.Protobuf.Timestamp.t(),
          to_date: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :from_date, :to_date]

  field(:org_id, 1, type: :string)
  field(:from_date, 2, type: Google.Protobuf.Timestamp)
  field(:to_date, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.ListProjectsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          projects: [InternalApi.Billing.Project.t()]
        }
  defstruct [:projects]

  field(:projects, 1, repeated: true, type: InternalApi.Billing.Project)
end

defmodule InternalApi.Billing.DescribeProjectRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          from_date: Google.Protobuf.Timestamp.t(),
          to_date: Google.Protobuf.Timestamp.t()
        }
  defstruct [:project_id, :from_date, :to_date]

  field(:project_id, 1, type: :string)
  field(:from_date, 2, type: Google.Protobuf.Timestamp)
  field(:to_date, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.DescribeProjectResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project: InternalApi.Billing.Project.t(),
          costs: [InternalApi.Billing.ProjectCost.t()]
        }
  defstruct [:project, :costs]

  field(:project, 1, type: InternalApi.Billing.Project)
  field(:costs, 2, repeated: true, type: InternalApi.Billing.ProjectCost)
end

defmodule InternalApi.Billing.Project do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          cost: InternalApi.Billing.ProjectCost.t()
        }
  defstruct [:id, :name, :cost]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:cost, 3, type: InternalApi.Billing.ProjectCost)
end

defmodule InternalApi.Billing.ProjectCost do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          from_date: Google.Protobuf.Timestamp.t(),
          to_date: Google.Protobuf.Timestamp.t(),
          total_price: String.t(),
          workflow_count: integer,
          spending_groups: [InternalApi.Billing.SpendingGroup.t()],
          workflow_trends: [InternalApi.Billing.SpendingTrend.t()]
        }
  defstruct [
    :from_date,
    :to_date,
    :total_price,
    :workflow_count,
    :spending_groups,
    :workflow_trends
  ]

  field(:from_date, 1, type: Google.Protobuf.Timestamp)
  field(:to_date, 2, type: Google.Protobuf.Timestamp)
  field(:total_price, 3, type: :string)
  field(:workflow_count, 4, type: :int32)
  field(:spending_groups, 5, repeated: true, type: InternalApi.Billing.SpendingGroup)
  field(:workflow_trends, 6, repeated: true, type: InternalApi.Billing.SpendingTrend)
end

defmodule InternalApi.Billing.SetupOrganizationRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_username: String.t(),
          organization_owner_id: String.t(),
          plan: integer,
          force_creation: boolean,
          plan_type_slug: String.t()
        }
  defstruct [
    :organization_username,
    :organization_owner_id,
    :plan,
    :force_creation,
    :plan_type_slug
  ]

  field(:organization_username, 1, type: :string)
  field(:organization_owner_id, 2, type: :string)
  field(:plan, 3, type: InternalApi.Billing.PlanType, enum: true)
  field(:force_creation, 4, type: :bool)
  field(:plan_type_slug, 5, type: :string)
end

defmodule InternalApi.Billing.SetupOrganizationResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t()
        }
  defstruct [:organization_id]

  field(:organization_id, 1, type: :string)
end

defmodule InternalApi.Billing.PlanStatusRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          org_username: String.t()
        }
  defstruct [:org_id, :org_username]

  field(:org_id, 1, type: :string)
  field(:org_username, 2, type: :string)
end

defmodule InternalApi.Billing.PlanStatusResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t(),
          for_owner: String.t(),
          for_owner_mobile: String.t(),
          for_member: String.t(),
          for_member_mobile: String.t()
        }
  defstruct [:status, :for_owner, :for_owner_mobile, :for_member, :for_member_mobile]

  field(:status, 1, type: Google.Rpc.Status)
  field(:for_owner, 2, type: :string)
  field(:for_owner_mobile, 3, type: :string)
  field(:for_member, 4, type: :string)
  field(:for_member_mobile, 5, type: :string)
end

defmodule InternalApi.Billing.PlanStateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          org_username: String.t()
        }
  defstruct [:org_id, :org_username]

  field(:org_id, 1, type: :string)
  field(:org_username, 2, type: :string)
end

defmodule InternalApi.Billing.PlanStateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          plan_type: integer,
          plan_badge: String.t(),
          actionable_header: String.t(),
          non_actionable_header: String.t(),
          plan_type_slug: String.t(),
          segment: String.t()
        }
  defstruct [
    :plan_type,
    :plan_badge,
    :actionable_header,
    :non_actionable_header,
    :plan_type_slug,
    :segment
  ]

  field(:plan_type, 1, type: InternalApi.Billing.PlanType, enum: true)
  field(:plan_badge, 2, type: :string)
  field(:actionable_header, 3, type: :string)
  field(:non_actionable_header, 4, type: :string)
  field(:plan_type_slug, 5, type: :string)
  field(:segment, 6, type: :string)
end

defmodule InternalApi.Billing.OrganizationStatusRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Billing.OrganizationStatusResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          plan: integer,
          last_charge_without_tax_amount_in_cents: integer,
          plan_type_slug: String.t()
        }
  defstruct [:plan, :last_charge_without_tax_amount_in_cents, :plan_type_slug]

  field(:plan, 1, type: InternalApi.Billing.PlanType, enum: true)
  field(:last_charge_without_tax_amount_in_cents, 2, type: :int32)
  field(:plan_type_slug, 3, type: :string)
end

defmodule InternalApi.Billing.ListPlansRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Billing.ListPlansResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          plans: [InternalApi.Billing.Plan.t()]
        }
  defstruct [:plans]

  field(:plans, 1, repeated: true, type: InternalApi.Billing.Plan)
end

defmodule InternalApi.Billing.Plan do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          price: integer,
          credits: integer,
          charge: boolean,
          block: boolean,
          created_at: Google.Protobuf.Timestamp.t(),
          updated_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:id, :name, :price, :credits, :charge, :block, :created_at, :updated_at]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:price, 3, type: :int32)
  field(:credits, 4, type: :int32)
  field(:charge, 5, type: :bool)
  field(:block, 6, type: :bool)
  field(:created_at, 7, type: Google.Protobuf.Timestamp)
  field(:updated_at, 8, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.ListFeaturesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target: InternalApi.Billing.FeatureTarget.t()
        }
  defstruct [:target]

  field(:target, 1, type: InternalApi.Billing.FeatureTarget)
end

defmodule InternalApi.Billing.ListFeaturesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          features: [InternalApi.Billing.FeatureWithValues.t()]
        }
  defstruct [:features]

  field(:features, 1, repeated: true, type: InternalApi.Billing.FeatureWithValues)
end

defmodule InternalApi.Billing.FeatureWithValues do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          feature: InternalApi.Billing.Feature.t(),
          fallback_value: InternalApi.Billing.FeatureValue.t(),
          value: InternalApi.Billing.FeatureValue.t()
        }
  defstruct [:feature, :fallback_value, :value]

  field(:feature, 1, type: InternalApi.Billing.Feature)
  field(:fallback_value, 2, type: InternalApi.Billing.FeatureValue)
  field(:value, 3, type: InternalApi.Billing.FeatureValue)
end

defmodule InternalApi.Billing.Feature do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: String.t(),
          name: String.t(),
          description: String.t()
        }
  defstruct [:type, :name, :description]

  field(:type, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
end

defmodule InternalApi.Billing.FeatureValue do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          availability: InternalApi.Feature.Availability.t()
        }
  defstruct [:availability]

  field(:availability, 1, type: InternalApi.Feature.Availability)
end

defmodule InternalApi.Billing.ListMachinesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target: InternalApi.Billing.FeatureTarget.t()
        }
  defstruct [:target]

  field(:target, 1, type: InternalApi.Billing.FeatureTarget)
end

defmodule InternalApi.Billing.ListMachinesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          machines: [InternalApi.Billing.MachineWithValues.t()]
        }
  defstruct [:machines]

  field(:machines, 1, repeated: true, type: InternalApi.Billing.MachineWithValues)
end

defmodule InternalApi.Billing.MachineWithValues do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          machine: InternalApi.Billing.Machine.t(),
          fallback_value: InternalApi.Billing.MachineValue.t(),
          value: InternalApi.Billing.MachineValue.t()
        }
  defstruct [:machine, :fallback_value, :value]

  field(:machine, 1, type: InternalApi.Billing.Machine)
  field(:fallback_value, 2, type: InternalApi.Billing.MachineValue)
  field(:value, 3, type: InternalApi.Billing.MachineValue)
end

defmodule InternalApi.Billing.Machine do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: String.t(),
          platform: integer,
          vcpu: String.t(),
          ram: String.t(),
          disk: String.t()
        }
  defstruct [:type, :platform, :vcpu, :ram, :disk]

  field(:type, 1, type: :string)
  field(:platform, 3, type: InternalApi.Feature.Machine.Platform, enum: true)
  field(:vcpu, 4, type: :string)
  field(:ram, 5, type: :string)
  field(:disk, 6, type: :string)
end

defmodule InternalApi.Billing.MachineValue do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          availability: InternalApi.Feature.Availability.t(),
          default_os_image: String.t(),
          os_images: [String.t()]
        }
  defstruct [:availability, :default_os_image, :os_images]

  field(:availability, 1, type: InternalApi.Feature.Availability)
  field(:default_os_image, 2, type: :string)
  field(:os_images, 3, repeated: true, type: :string)
end

defmodule InternalApi.Billing.UpdateFeaturesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target: InternalApi.Billing.FeatureTarget.t(),
          requester_id: String.t(),
          updates: [InternalApi.Billing.FeatureWithValues.t()],
          removes: [InternalApi.Billing.Feature.t()]
        }
  defstruct [:target, :requester_id, :updates, :removes]

  field(:target, 1, type: InternalApi.Billing.FeatureTarget)
  field(:requester_id, 2, type: :string)
  field(:updates, 3, repeated: true, type: InternalApi.Billing.FeatureWithValues)
  field(:removes, 4, repeated: true, type: InternalApi.Billing.Feature)
end

defmodule InternalApi.Billing.UpdateFeaturesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Billing.UpdateMachinesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target: InternalApi.Billing.FeatureTarget.t(),
          requester_id: String.t(),
          updates: [InternalApi.Billing.MachineWithValues.t()],
          removes: [InternalApi.Billing.Machine.t()]
        }
  defstruct [:target, :requester_id, :updates, :removes]

  field(:target, 1, type: InternalApi.Billing.FeatureTarget)
  field(:requester_id, 2, type: :string)
  field(:updates, 3, repeated: true, type: InternalApi.Billing.MachineWithValues)
  field(:removes, 4, repeated: true, type: InternalApi.Billing.Machine)
end

defmodule InternalApi.Billing.UpdateMachinesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Billing.FeatureTarget do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          plan_id: String.t()
        }
  defstruct [:org_id, :plan_id]

  field(:org_id, 1, type: :string)
  field(:plan_id, 2, type: :string)
end

defmodule InternalApi.Billing.CreditCardAdded do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          for_plan: integer,
          plan_type_slug: String.t()
        }
  defstruct [:org_id, :timestamp, :for_plan, :plan_type_slug]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:for_plan, 3, type: InternalApi.Billing.PlanType, enum: true)
  field(:plan_type_slug, 4, type: :string)
end

defmodule InternalApi.Billing.CreditCardReconnected do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :timestamp]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.SpendingUpdated do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          current_billing_cycle: String.t(),
          current_spending_in_cents: integer,
          total_spending_in_cents: integer,
          timestamp: Google.Protobuf.Timestamp.t(),
          previous_spending_in_cents: integer,
          last_charge_amount_in_cents: integer,
          last_charge_without_tax_amount_in_cents: integer,
          last_charge_date: String.t(),
          total_charge_amount_in_cents: integer,
          current_discount_in_cents: integer,
          current_mac_spending_in_cents: integer,
          total_mac_spending_in_cents: integer,
          current_linux_spending_in_cents: integer,
          total_linux_spending_in_cents: integer,
          second_last_charge_amount_in_cents: integer,
          second_last_charge_without_tax_amount_in_cents: integer,
          second_last_charge_date: String.t(),
          monthly_budget_in_cents: String.t(),
          charge_history: [InternalApi.Billing.MonthlyCharge.t()],
          payment_method: String.t()
        }
  defstruct [
    :org_id,
    :current_billing_cycle,
    :current_spending_in_cents,
    :total_spending_in_cents,
    :timestamp,
    :previous_spending_in_cents,
    :last_charge_amount_in_cents,
    :last_charge_without_tax_amount_in_cents,
    :last_charge_date,
    :total_charge_amount_in_cents,
    :current_discount_in_cents,
    :current_mac_spending_in_cents,
    :total_mac_spending_in_cents,
    :current_linux_spending_in_cents,
    :total_linux_spending_in_cents,
    :second_last_charge_amount_in_cents,
    :second_last_charge_without_tax_amount_in_cents,
    :second_last_charge_date,
    :monthly_budget_in_cents,
    :charge_history,
    :payment_method
  ]

  field(:org_id, 1, type: :string)
  field(:current_billing_cycle, 2, type: :string)
  field(:current_spending_in_cents, 3, type: :int32)
  field(:total_spending_in_cents, 4, type: :int32)
  field(:timestamp, 5, type: Google.Protobuf.Timestamp)
  field(:previous_spending_in_cents, 6, type: :int32)
  field(:last_charge_amount_in_cents, 7, type: :int32)
  field(:last_charge_without_tax_amount_in_cents, 17, type: :int32)
  field(:last_charge_date, 8, type: :string)
  field(:total_charge_amount_in_cents, 9, type: :int32)
  field(:current_discount_in_cents, 10, type: :int32)
  field(:current_mac_spending_in_cents, 11, type: :int32)
  field(:total_mac_spending_in_cents, 12, type: :int32)
  field(:current_linux_spending_in_cents, 13, type: :int32)
  field(:total_linux_spending_in_cents, 14, type: :int32)
  field(:second_last_charge_amount_in_cents, 15, type: :int32)
  field(:second_last_charge_without_tax_amount_in_cents, 18, type: :int32)
  field(:second_last_charge_date, 16, type: :string)
  field(:monthly_budget_in_cents, 19, type: :string)
  field(:charge_history, 20, repeated: true, type: InternalApi.Billing.MonthlyCharge)
  field(:payment_method, 21, type: :string)
end

defmodule InternalApi.Billing.MonthlyCharge do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          month_name: String.t(),
          charge_in_cents: integer
        }
  defstruct [:month_name, :charge_in_cents]

  field(:month_name, 1, type: :string)
  field(:charge_in_cents, 2, type: :int32)
end

defmodule InternalApi.Billing.ChargeSuccess do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          amount_charged_in_cents: integer
        }
  defstruct [:org_id, :timestamp, :amount_charged_in_cents]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:amount_charged_in_cents, 3, type: :int32)
end

defmodule InternalApi.Billing.FirstChargeSuccess do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          amount_charged_in_cents: integer,
          without_tax_amount_charged_in_cents: integer
        }
  defstruct [:org_id, :timestamp, :amount_charged_in_cents, :without_tax_amount_charged_in_cents]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:amount_charged_in_cents, 3, type: :int32)
  field(:without_tax_amount_charged_in_cents, 4, type: :int32)
end

defmodule InternalApi.Billing.ChargeFailure do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          amount_charged_in_cents: integer
        }
  defstruct [:org_id, :timestamp, :amount_charged_in_cents]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:amount_charged_in_cents, 3, type: :int32)
end

defmodule InternalApi.Billing.PaymentSuccess do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          amount_charged_in_cents: integer,
          reason: String.t(),
          method: integer
        }
  defstruct [:org_id, :timestamp, :amount_charged_in_cents, :reason, :method]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:amount_charged_in_cents, 3, type: :int32)
  field(:reason, 4, type: :string)
  field(:method, 5, type: InternalApi.Billing.PaymentMethod, enum: true)
end

defmodule InternalApi.Billing.PaymentFailure do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          amount_charged_in_cents: integer,
          reason: String.t(),
          method: integer
        }
  defstruct [:org_id, :timestamp, :amount_charged_in_cents, :reason, :method]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:amount_charged_in_cents, 3, type: :int32)
  field(:reason, 4, type: :string)
  field(:method, 5, type: InternalApi.Billing.PaymentMethod, enum: true)
end

defmodule InternalApi.Billing.SubscriptionCanceled do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          subscription_on_fastspring: String.t(),
          for_plan: integer,
          plan_type_slug: String.t()
        }
  defstruct [:org_id, :timestamp, :subscription_on_fastspring, :for_plan, :plan_type_slug]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:subscription_on_fastspring, 3, type: :string)
  field(:for_plan, 4, type: InternalApi.Billing.PlanType, enum: true)
  field(:plan_type_slug, 5, type: :string)
end

defmodule InternalApi.Billing.PlanChanged do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          new_plan: String.t()
        }
  defstruct [:org_id, :timestamp, :new_plan]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:new_plan, 3, type: :string)
end

defmodule InternalApi.Billing.SegmentChanged do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          new_segment: String.t()
        }
  defstruct [:org_id, :timestamp, :new_segment]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:new_segment, 3, type: :string)
end

defmodule InternalApi.Billing.TrialStarted do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          days_left_in_trial: integer
        }
  defstruct [:org_id, :timestamp, :days_left_in_trial]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:days_left_in_trial, 3, type: :int32)
end

defmodule InternalApi.Billing.TrialStatusUpdate do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          days_left_in_trial: integer
        }
  defstruct [:org_id, :timestamp, :days_left_in_trial]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:days_left_in_trial, 3, type: :int32)
end

defmodule InternalApi.Billing.TrialExpired do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :timestamp]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.TrialAbandoned do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :timestamp]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.NoteChanged do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          note: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :note, :timestamp]

  field(:org_id, 1, type: :string)
  field(:note, 2, type: :string)
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.BudgetAlert do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          spending_amount: String.t(),
          spending_limit: String.t(),
          email: String.t(),
          percentage_threshold: integer,
          from_date: Google.Protobuf.Timestamp.t(),
          to_date: Google.Protobuf.Timestamp.t()
        }
  defstruct [
    :org_id,
    :spending_amount,
    :spending_limit,
    :email,
    :percentage_threshold,
    :from_date,
    :to_date
  ]

  field(:org_id, 1, type: :string)
  field(:spending_amount, 2, type: :string)
  field(:spending_limit, 3, type: :string)
  field(:email, 4, type: :string)
  field(:percentage_threshold, 5, type: :int32)
  field(:from_date, 6, type: Google.Protobuf.Timestamp)
  field(:to_date, 7, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.TrialOwnerOnboarded do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          position_in_company: String.t(),
          company_team_size: String.t(),
          company_previous_tool: String.t(),
          company_ci_goal: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          user_name: String.t(),
          company_name: String.t(),
          learned_from: String.t()
        }
  defstruct [
    :user_id,
    :position_in_company,
    :company_team_size,
    :company_previous_tool,
    :company_ci_goal,
    :timestamp,
    :user_name,
    :company_name,
    :learned_from
  ]

  field(:user_id, 1, type: :string)
  field(:position_in_company, 2, type: :string)
  field(:company_team_size, 3, type: :string)
  field(:company_previous_tool, 4, type: :string)
  field(:company_ci_goal, 5, type: :string)
  field(:timestamp, 6, type: Google.Protobuf.Timestamp)
  field(:user_name, 7, type: :string)
  field(:company_name, 8, type: :string)
  field(:learned_from, 9, type: :string)
end

defmodule InternalApi.Billing.PaidOwnerOnboarded do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          feedback: String.t(),
          requested_concierge_onboarding: boolean,
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:user_id, :feedback, :requested_concierge_onboarding, :timestamp]

  field(:user_id, 1, type: :string)
  field(:feedback, 2, type: :string)
  field(:requested_concierge_onboarding, 3, type: :bool)
  field(:timestamp, 4, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.CreditsChanged do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :timestamp]

  field(:org_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.ListSpendingsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Billing.ListSpendingsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          spendings: [InternalApi.Billing.Spending.t()]
        }
  defstruct [:spendings]

  field(:spendings, 1, repeated: true, type: InternalApi.Billing.Spending)
end

defmodule InternalApi.Billing.CurrentSpendingRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Billing.CurrentSpendingResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          spending: InternalApi.Billing.Spending.t()
        }
  defstruct [:spending]

  field(:spending, 1, type: InternalApi.Billing.Spending)
end

defmodule InternalApi.Billing.Spending do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          display_name: String.t(),
          from_date: Google.Protobuf.Timestamp.t(),
          to_date: Google.Protobuf.Timestamp.t(),
          summary: InternalApi.Billing.SpendingSummary.t(),
          plan_summary: InternalApi.Billing.PlanSummary.t(),
          groups: [InternalApi.Billing.SpendingGroup.t()]
        }
  defstruct [:id, :display_name, :from_date, :to_date, :summary, :plan_summary, :groups]

  field(:id, 1, type: :string)
  field(:display_name, 2, type: :string)
  field(:from_date, 3, type: Google.Protobuf.Timestamp)
  field(:to_date, 4, type: Google.Protobuf.Timestamp)
  field(:summary, 5, type: InternalApi.Billing.SpendingSummary)
  field(:plan_summary, 6, type: InternalApi.Billing.PlanSummary)
  field(:groups, 7, repeated: true, type: InternalApi.Billing.SpendingGroup)
end

defmodule InternalApi.Billing.SpendingSummary do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          total_bill: String.t(),
          subscription_total: String.t(),
          usage_total: String.t(),
          usage_used: String.t(),
          credits_total: String.t(),
          credits_used: String.t(),
          credits_starting: String.t(),
          discount: String.t(),
          discount_amount: String.t()
        }
  defstruct [
    :total_bill,
    :subscription_total,
    :usage_total,
    :usage_used,
    :credits_total,
    :credits_used,
    :credits_starting,
    :discount,
    :discount_amount
  ]

  field(:total_bill, 1, type: :string)
  field(:subscription_total, 2, type: :string)
  field(:usage_total, 3, type: :string)
  field(:usage_used, 4, type: :string)
  field(:credits_total, 5, type: :string)
  field(:credits_used, 6, type: :string)
  field(:credits_starting, 7, type: :string)
  field(:discount, 8, type: :string)
  field(:discount_amount, 9, type: :string)
end

defmodule InternalApi.Billing.PlanSummary do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          details: [InternalApi.Billing.PlanSummary.Detail.t()],
          charging_type: integer,
          subscription_starts_on: Google.Protobuf.Timestamp.t(),
          subscription_ends_on: Google.Protobuf.Timestamp.t(),
          suspensions: [integer],
          flags: [integer],
          payment_method_url: String.t(),
          slug: String.t()
        }
  defstruct [
    :id,
    :name,
    :details,
    :charging_type,
    :subscription_starts_on,
    :subscription_ends_on,
    :suspensions,
    :flags,
    :payment_method_url,
    :slug
  ]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:details, 3, repeated: true, type: InternalApi.Billing.PlanSummary.Detail)
  field(:charging_type, 4, type: InternalApi.Billing.ChargingType, enum: true)
  field(:subscription_starts_on, 5, type: Google.Protobuf.Timestamp)
  field(:subscription_ends_on, 6, type: Google.Protobuf.Timestamp)

  field(:suspensions, 7,
    repeated: true,
    type: InternalApi.Billing.SubscriptionSuspension,
    enum: true
  )

  field(:flags, 8, repeated: true, type: InternalApi.Billing.SubscriptionFlag, enum: true)
  field(:payment_method_url, 9, type: :string)
  field(:slug, 10, type: :string)
end

defmodule InternalApi.Billing.PlanSummary.Detail do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          display_name: String.t(),
          display_description: String.t(),
          display_value: String.t()
        }
  defstruct [:id, :display_name, :display_description, :display_value]

  field(:id, 1, type: :string)
  field(:display_name, 2, type: :string)
  field(:display_description, 3, type: :string)
  field(:display_value, 4, type: :string)
end

defmodule InternalApi.Billing.DescribeSpendingRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          spending_id: String.t()
        }
  defstruct [:spending_id]

  field(:spending_id, 1, type: :string)
end

defmodule InternalApi.Billing.DescribeSpendingResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          spending: InternalApi.Billing.Spending.t()
        }
  defstruct [:spending]

  field(:spending, 1, type: InternalApi.Billing.Spending)
end

defmodule InternalApi.Billing.SpendingGroup do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: integer,
          items: [InternalApi.Billing.SpendingItem.t()],
          total_price: String.t(),
          trends: [InternalApi.Billing.SpendingTrend.t()]
        }
  defstruct [:type, :items, :total_price, :trends]

  field(:type, 1, type: InternalApi.Billing.SpendingType, enum: true)
  field(:items, 2, repeated: true, type: InternalApi.Billing.SpendingItem)
  field(:total_price, 3, type: :string)
  field(:trends, 4, repeated: true, type: InternalApi.Billing.SpendingTrend)
end

defmodule InternalApi.Billing.SpendingItem do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          display_name: String.t(),
          display_description: String.t(),
          units: integer,
          unit_price: String.t(),
          total_price: String.t(),
          name: String.t(),
          trends: [InternalApi.Billing.SpendingTrend.t()],
          enabled: boolean
        }
  defstruct [
    :display_name,
    :display_description,
    :units,
    :unit_price,
    :total_price,
    :name,
    :trends,
    :enabled
  ]

  field(:display_name, 1, type: :string)
  field(:display_description, 2, type: :string)
  field(:units, 3, type: :int64)
  field(:unit_price, 4, type: :string)
  field(:total_price, 5, type: :string)
  field(:name, 6, type: :string)
  field(:trends, 7, repeated: true, type: InternalApi.Billing.SpendingTrend)
  field(:enabled, 8, type: :bool)
end

defmodule InternalApi.Billing.SpendingTrend do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          units: integer,
          price: String.t()
        }
  defstruct [:name, :units, :price]

  field(:name, 1, type: :string)
  field(:units, 2, type: :int64)
  field(:price, 3, type: :string)
end

defmodule InternalApi.Billing.ListDailyCostsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          spending_id: String.t()
        }
  defstruct [:spending_id]

  field(:spending_id, 1, type: :string)
end

defmodule InternalApi.Billing.ListDailyCostsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          costs: [InternalApi.Billing.DailyCost.t()]
        }
  defstruct [:costs]

  field(:costs, 1, repeated: true, type: InternalApi.Billing.DailyCost)
end

defmodule InternalApi.Billing.DailyCost do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: integer,
          price_for_the_day: String.t(),
          price_up_to_the_day: String.t(),
          day: Google.Protobuf.Timestamp.t(),
          prediction: boolean,
          items: [InternalApi.Billing.SpendingItem.t()]
        }
  defstruct [:type, :price_for_the_day, :price_up_to_the_day, :day, :prediction, :items]

  field(:type, 1, type: InternalApi.Billing.SpendingType, enum: true)
  field(:price_for_the_day, 2, type: :string)
  field(:price_up_to_the_day, 3, type: :string)
  field(:day, 4, type: Google.Protobuf.Timestamp)
  field(:prediction, 5, type: :bool)
  field(:items, 6, repeated: true, type: InternalApi.Billing.SpendingItem)
end

defmodule InternalApi.Billing.ListSpendingSeatsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          spending_id: String.t()
        }
  defstruct [:spending_id]

  field(:spending_id, 1, type: :string)
end

defmodule InternalApi.Billing.ListSpendingSeatsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          seats: [InternalApi.Usage.Seat.t()]
        }
  defstruct [:seats]

  field(:seats, 1, repeated: true, type: InternalApi.Usage.Seat)
end

defmodule InternalApi.Billing.ListInvoicesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Billing.ListInvoicesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          invoices: [InternalApi.Billing.Invoice.t()]
        }
  defstruct [:invoices]

  field(:invoices, 1, repeated: true, type: InternalApi.Billing.Invoice)
end

defmodule InternalApi.Billing.Invoice do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          display_name: String.t(),
          total_bill: String.t(),
          total_bill_no_tax: String.t(),
          pdf_download_url: String.t()
        }
  defstruct [:display_name, :total_bill, :total_bill_no_tax, :pdf_download_url]

  field(:display_name, 1, type: :string)
  field(:total_bill, 2, type: :string)
  field(:total_bill_no_tax, 3, type: :string)
  field(:pdf_download_url, 4, type: :string)
end

defmodule InternalApi.Billing.GetBudgetRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Billing.GetBudgetResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          budget: InternalApi.Billing.Budget.t()
        }
  defstruct [:budget]

  field(:budget, 1, type: InternalApi.Billing.Budget)
end

defmodule InternalApi.Billing.SetBudgetRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          budget: InternalApi.Billing.Budget.t()
        }
  defstruct [:org_id, :budget]

  field(:org_id, 1, type: :string)
  field(:budget, 2, type: InternalApi.Billing.Budget)
end

defmodule InternalApi.Billing.SetBudgetResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          budget: InternalApi.Billing.Budget.t()
        }
  defstruct [:budget]

  field(:budget, 1, type: InternalApi.Billing.Budget)
end

defmodule InternalApi.Billing.Budget do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          limit: String.t(),
          email: String.t()
        }
  defstruct [:limit, :email]

  field(:limit, 1, type: :string)
  field(:email, 2, type: :string)
end

defmodule InternalApi.Billing.CreditsUsageRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Billing.CreditsUsageResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          credits_available: [InternalApi.Billing.CreditAvailable.t()],
          credits_balance: [InternalApi.Billing.CreditBalance.t()]
        }
  defstruct [:credits_available, :credits_balance]

  field(:credits_available, 1, repeated: true, type: InternalApi.Billing.CreditAvailable)
  field(:credits_balance, 2, repeated: true, type: InternalApi.Billing.CreditBalance)
end

defmodule InternalApi.Billing.CreditBalance do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: integer,
          description: String.t(),
          amount: String.t(),
          occured_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:type, :description, :amount, :occured_at]

  field(:type, 1, type: InternalApi.Billing.CreditBalanceType, enum: true)
  field(:description, 2, type: :string)
  field(:amount, 3, type: :string)
  field(:occured_at, 4, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.CreditAvailable do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: integer,
          amount: String.t(),
          given_at: Google.Protobuf.Timestamp.t(),
          expires_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:type, :amount, :given_at, :expires_at]

  field(:type, 1, type: InternalApi.Billing.CreditType, enum: true)
  field(:amount, 2, type: :string)
  field(:given_at, 3, type: Google.Protobuf.Timestamp)
  field(:expires_at, 4, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Billing.UpgradePlanRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          plan_slug: String.t()
        }
  defstruct [:org_id, :plan_slug]

  field(:org_id, 1, type: :string)
  field(:plan_slug, 2, type: :string)
end

defmodule InternalApi.Billing.UpgradePlanResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          spending_id: String.t(),
          errors: [String.t()],
          payment_method_url: String.t()
        }
  defstruct [:spending_id, :errors, :payment_method_url]

  field(:spending_id, 1, type: :string)
  field(:errors, 2, repeated: true, type: :string)
  field(:payment_method_url, 3, type: :string)
end

defmodule InternalApi.Billing.PlanType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

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
  use Protobuf, enum: true, syntax: :proto3

  field(:CREDIT_CARD, 0)
  field(:WIRE, 1)
end

defmodule InternalApi.Billing.SubscriptionFlag do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

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
  use Protobuf, enum: true, syntax: :proto3

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
  use Protobuf, enum: true, syntax: :proto3

  field(:CHARGING_TYPE_UNSPECIFIED, 0)
  field(:CHARGING_TYPE_NONE, 1)
  field(:CHARGING_TYPE_PREPAID, 2)
  field(:CHARGING_TYPE_POSTPAID, 3)
  field(:CHARGING_TYPE_FLATRATE, 4)
  field(:CHARGING_TYPE_GRANDFATHERED, 5)
end

defmodule InternalApi.Billing.SpendingType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:SPENDING_TYPE_UNSPECIFIED, 0)
  field(:SPENDING_TYPE_MACHINE_TIME, 1)
  field(:SPENDING_TYPE_SEAT, 2)
  field(:SPENDING_TYPE_STORAGE, 3)
  field(:SPENDING_TYPE_ADDON, 4)
  field(:SPENDING_TYPE_MACHINE_CAPACITY, 5)
end

defmodule InternalApi.Billing.CreditType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:CREDIT_TYPE_UNSPECIFIED, 0)
  field(:CREDIT_TYPE_PREPAID, 1)
  field(:CREDIT_TYPE_GIFT, 2)
  field(:CREDIT_TYPE_SUBSCRIPTION, 3)
  field(:CREDIT_TYPE_EDUCATIONAL, 4)
end

defmodule InternalApi.Billing.CreditBalanceType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:CREDIT_BALANCE_TYPE_UNSPECIFIED, 0)
  field(:CREDIT_BALANCE_TYPE_CHARGE, 1)
  field(:CREDIT_BALANCE_TYPE_DEPOSIT, 2)
end

defmodule InternalApi.Billing.BillingService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Billing.BillingService"

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
