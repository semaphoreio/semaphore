defmodule Front.Models.Billing.Credits do
  alias InternalApi.Billing.CreditAvailable, as: GrpcAvailableCredits
  alias InternalApi.Billing.CreditBalance, as: GrpcCreditBalance
  alias InternalApi.Billing.CreditsUsageResponse, as: GrpcCreditsUsageResponse
  alias __MODULE__

  defmodule AvailableCredits do
    defstruct [:type, :amount, :given_at, :expires_at]

    @type credit_type :: :prepaid | :gift | :subscription | :educational | :unspecified
    @type t :: %AvailableCredits{
            type: credit_type(),
            amount: String.t(),
            given_at: DateTime.t(),
            expires_at: DateTime.t()
          }

    @spec new(Enum.t()) :: t()
    def new(params \\ %{}), do: struct(AvailableCredits, params)

    @spec from_grpc(GrpcAvailableCredits.t()) :: t()
    def from_grpc(available_credit = %GrpcAvailableCredits{}) do
      new(
        type: type_from_grpc(available_credit.type),
        amount: available_credit.amount,
        given_at: Timex.from_unix(available_credit.given_at.seconds),
        expires_at: Timex.from_unix(available_credit.expires_at.seconds)
      )
    end

    @spec type_from_grpc(InternalApi.Billing.CreditType.t()) :: credit_type()
    defp type_from_grpc(value) do
      value
      |> InternalApi.Billing.CreditType.key()
      |> case do
        :CREDIT_TYPE_PREPAID -> :prepaid
        :CREDIT_TYPE_GIFT -> :gift
        :CREDIT_TYPE_SUBSCRIPTION -> :subscription
        :CREDIT_TYPE_EDUCATIONAL -> :educational
        _ -> :unspecified
      end
    end
  end

  defmodule BalanceCredits do
    defstruct [:type, :description, :amount, :occured_at]

    @type balance_type :: :charge | :deposit | :unspecified
    @type t :: %BalanceCredits{
            type: balance_type(),
            description: String.t(),
            amount: String.t(),
            occured_at: DateTime.t()
          }

    @spec new(Enum.t()) :: t()
    def new(params \\ %{}), do: struct(BalanceCredits, params)

    @spec from_grpc(GrpcCreditBalance.t()) :: t()
    def from_grpc(credit_balance = %GrpcCreditBalance{}) do
      new(
        type: type_from_grpc(credit_balance.type),
        description: credit_balance.description,
        amount: credit_balance.amount,
        occured_at: Timex.from_unix(credit_balance.occured_at.seconds)
      )
    end

    @spec type_from_grpc(InternalApi.Billing.CreditBalanceType.t()) :: balance_type()
    def type_from_grpc(value) do
      value
      |> InternalApi.Billing.CreditBalanceType.key()
      |> case do
        :CREDIT_BALANCE_TYPE_CHARGE -> :charge
        :CREDIT_BALANCE_TYPE_DEPOSIT -> :deposit
        _ -> :unspecified
      end
    end
  end

  defstruct available: [], balance: []

  @type t :: %Credits{
          available: [AvailableCredits.t()],
          balance: [BalanceCredits.t()]
        }

  @spec new(Enum.t()) :: t()
  def new(params \\ %{}), do: struct(Credits, params)

  @spec from_grpc(GrpcCreditsUsageResponse.t()) :: t()
  def from_grpc(credits_usage = %GrpcCreditsUsageResponse{}) do
    new(
      available: Enum.map(credits_usage.credits_available, &AvailableCredits.from_grpc/1),
      balance: Enum.map(credits_usage.credits_balance, &BalanceCredits.from_grpc/1)
    )
  end
end
