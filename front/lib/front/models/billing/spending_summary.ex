defmodule Front.Models.Billing.SpendingSummary do
  alias InternalApi.Billing.SpendingSummary, as: GrpcSpendingSummary
  alias __MODULE__

  defstruct total_bill: "$ 0.00",
            subscription_total: "$ 0.00",
            usage_total: "$ 0.00",
            usage_used: "$ 0.00",
            credits_total: "$ 0.00",
            credits_used: "$ 0.00",
            credits_starting: "$ 0.00",
            discount: "0",
            discount_amount: "$ 0"

  @type t :: %SpendingSummary{
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

  @spec new(Enum.t()) :: t()
  def new(params \\ %{}), do: struct(SpendingSummary, params)

  @spec from_grpc(GrpcSpendingSummary.t() | nil) :: t()
  def from_grpc(spending_summary = %GrpcSpendingSummary{}) do
    new(
      total_bill: spending_summary.total_bill,
      subscription_total: spending_summary.subscription_total,
      usage_total: spending_summary.usage_total,
      usage_used: spending_summary.usage_used,
      credits_total: spending_summary.credits_total,
      credits_used: spending_summary.credits_used,
      credits_starting: spending_summary.credits_starting,
      discount: spending_summary.discount,
      discount_amount: spending_summary.discount_amount
    )
  end

  def from_grpc(nil) do
    new(
      total_bill: "$ 0.00",
      subscription_total: "$ 0.00",
      usage_total: "$ 0.00",
      usage_used: "$ 0.00",
      credits_total: "$ 0.00",
      credits_used: "$ 0.00",
      credits_starting: "$ 0.00",
      discount: "0",
      discount_amount: "$ 0.00"
    )
  end
end
