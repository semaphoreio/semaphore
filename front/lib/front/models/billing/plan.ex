defmodule Front.Models.Billing.Plan do
  alias InternalApi.Billing.ChargingType, as: GrpcChargingType
  alias InternalApi.Billing.PlanSummary, as: GrpcPlanSummary
  alias InternalApi.Billing.PlanSummary.Detail, as: GrpcPlanDetail
  alias InternalApi.Billing.SubscriptionFlag, as: GrpcSubscriptionFlag
  alias InternalApi.Billing.SubscriptionSuspension, as: GrpcSubscriptionSuspension
  alias __MODULE__

  defstruct display_name: "",
            slug: "",
            details: [],
            flags: [],
            suspensions: [],
            charging_type: :undefined,
            subscription_ends_on: nil,
            subscription_starts_on: nil,
            payment_method_url: ""

  @type detail :: %{
          display_name: String.t(),
          display_description: String.t(),
          display_value: String.t()
        }

  @type t :: %Plan{
          display_name: String.t(),
          slug: String.t(),
          details: [detail()],
          flags: [flag()],
          suspensions: [suspension()],
          charging_type: charging_type(),
          subscription_starts_on: Date.t(),
          subscription_ends_on: Date.t() | nil,
          payment_method_url: String.t()
        }

  @type charging_type :: :undefined | :none | :prepaid | :postpaid | :grandfathered | :flat
  @type suspension ::
          :no_payment_method
          | :miner
          | :no_credits
          | :payement_failed
          | :terms_of_service
          | :account_at_risk
          | :pipeline_block

  @type flag ::
          :trial
          | :transferable_credits
          | :eligible_for_trial
          | :eligible_for_addons
          | :not_charged
          | :free
          | :trial_end_nack

  @spec new(Enum.t()) :: t()
  def new(params \\ %{}), do: struct(Plan, params)

  @spec zero() :: t()
  def zero, do: Plan.new()

  @spec from_grpc(GrpcPlanSummary.t()) :: t()
  def from_grpc(plan_summary = %GrpcPlanSummary{}) do
    new(
      display_name: plan_summary.name,
      slug: plan_summary.slug,
      details: Enum.map(plan_summary.details, &detail_from_grpc/1),
      charging_type: charging_type_from_grpc(plan_summary.charging_type),
      subscription_ends_on: optional_date(plan_summary.subscription_ends_on),
      subscription_starts_on: optional_date(plan_summary.subscription_starts_on),
      flags: flags_from_grpc(plan_summary.flags),
      suspensions: suspensions_from_grpc(plan_summary.suspensions),
      payment_method_url: plan_summary.payment_method_url
    )
  end

  def from_grpc(nil), do: new(display_name: "Unknown plan")

  @spec trial?(t()) :: boolean()
  def trial?(plan) do
    :trial in plan.flags
  end

  @spec trial_expired?(t()) :: boolean()
  def trial_expired?(plan) do
    trial?(plan) && subscription_days(plan) == 0
  end

  @spec eligible_for_trial?(t()) :: boolean()
  def eligible_for_trial?(plan) do
    :eligible_for_trial in plan.flags
  end

  @spec eligible_for_addons?(t()) :: boolean()
  def eligible_for_addons?(plan) do
    :eligible_for_addons in plan.flags
  end

  @spec pipelines_blocked?(t()) :: boolean()
  def pipelines_blocked?(plan) do
    :pipeline_block in plan.suspensions
  end

  @spec on_free_plan?(t()) :: boolean()
  def on_free_plan?(plan) do
    :free in plan.flags
  end

  @spec on_opensource_plan?(t()) :: boolean()
  def on_opensource_plan?(plan) do
    plan.display_name == "Open Source"
  end

  @spec subscription_days(t()) :: integer()
  def subscription_days(plan) do
    now = Timex.now() |> Timex.beginning_of_day()

    if plan.subscription_ends_on do
      Timex.diff(plan.subscription_ends_on, now, :days)
      |> case do
        days when days <= 0 -> 0
        days -> days
      end
    else
      0
    end
  end

  defp optional_date(%{seconds: timestamp}) do
    Timex.from_unix(timestamp)
  end

  defp optional_date(_), do: nil

  @spec detail_from_grpc(GrpcPlanDetail.t()) :: detail()
  defp detail_from_grpc(detail = %GrpcPlanDetail{}) do
    %{
      display_name: detail.display_name,
      display_description: detail.display_description,
      display_value: detail.display_value
    }
  end

  @spec charging_type_from_grpc(GrpcChargingType.t()) :: charging_type()
  defp charging_type_from_grpc(value) do
    value
    |> GrpcChargingType.key()
    |> case do
      :CHARGING_TYPE_PREPAID -> :prepaid
      :CHARGING_TYPE_POSTPAID -> :postpaid
      :CHARGING_TYPE_FLATRATE -> :flat
      :CHARGING_TYPE_GRANDFATHERED -> :grandfathered
      :CHARGING_TYPE_NONE -> :none
      _ -> :undefined
    end
  rescue
    _ -> :undefined
  end

  @spec flags_from_grpc([GrpcSubscriptionFlag.t()]) :: [flag()]
  defp flags_from_grpc(flags) do
    flags
    |> Enum.map(&flag_from_grpc/1)
    |> Enum.filter(& &1)
  end

  @spec flag_from_grpc(GrpcSubscriptionFlag.t()) :: flag() | nil
  defp flag_from_grpc(flag) do
    flag
    |> GrpcSubscriptionFlag.key()
    |> case do
      :SUBSCRIPTION_FLAG_TRIAL -> :trial
      :SUBSCRIPTION_FLAG_TRANSFERABLE_CREDITS -> :transferable_credits
      :SUBSCRIPTION_FLAG_ELIGIBLE_FOR_TRIAL -> :eligible_for_trial
      :SUBSCRIPTION_FLAG_ELIGIBLE_FOR_ADDONS -> :eligible_for_addons
      :SUBSCRIPTION_FLAG_NOT_CHARGED -> :not_charged
      :SUBSCRIPTION_FLAG_FREE -> :free
      :SUBSCRIPTION_FLAG_TRIAL_END_NACK -> :trial_end_nack
      _ -> nil
    end
  rescue
    _ -> nil
  end

  @spec suspensions_from_grpc([GrpcSubscriptionSuspension.t()]) :: [suspension()]
  defp suspensions_from_grpc(suspensions) do
    suspensions
    |> Enum.map(&suspension_from_grpc/1)
    |> Enum.filter(& &1)
  end

  @spec suspension_from_grpc(GrpcSubscriptionSuspension.t()) :: suspension() | nil
  defp suspension_from_grpc(suspension) do
    suspension
    |> GrpcSubscriptionSuspension.key()
    |> case do
      :SUBSCRIPTION_SUSPENSION_NO_PAYMENT_METHOD -> :no_payment_method
      :SUBSCRIPTION_SUSPENSION_MINER -> :miner
      :SUBSCRIPTION_SUSPENSION_NO_CREDITS -> :no_credits
      :SUBSCRIPTION_SUSPENSION_PAYMENT_FAILED -> :payement_failed
      :SUBSCRIPTION_SUSPENSION_TERMS_OF_SERVICE -> :terms_of_service
      :SUBSCRIPTION_SUSPENSION_ACCOUNT_AT_RISK -> :account_at_risk
      :SUBSCRIPTION_SUSPENSION_PIPELINE_BLOCK -> :pipeline_block
      _ -> nil
    end
  rescue
    _ -> nil
  end
end
