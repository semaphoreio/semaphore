defmodule Front.Models.Billing.Seat do
  alias InternalApi.Usage.Seat, as: UsageSeat
  alias __MODULE__

  defstruct [
    :display_name,
    :user_id,
    :origin,
    :status,
    :date
  ]

  @type seat_origin :: :semaphore | :github | :bitbucket | :gitlab | :unspecified
  @type seat_status :: :active_member | :non_active_member | :non_member | :unspecified

  @type t :: %Seat{
          user_id: String.t(),
          display_name: String.t(),
          origin: seat_origin(),
          status: seat_status(),
          date: DateTime.t()
        }

  def new(params), do: struct(Seat, params)

  def from_grpc(seat = %UsageSeat{}) do
    %Seat{
      user_id: seat.user_id,
      display_name: seat.display_name,
      origin: origin_from_grpc(seat.origin),
      status: status_from_grpc(seat.status),
      date: Timex.from_unix(seat.date.seconds)
    }
  end

  @spec origin_from_grpc(InternalApi.Usage.SeatOrigin.t()) :: seat_origin()
  def origin_from_grpc(value) do
    value
    |> InternalApi.Usage.SeatOrigin.key()
    |> case do
      :SEAT_ORIGIN_SEMAPHORE -> :semaphore
      :SEAT_ORIGIN_GITHUB -> :github
      :SEAT_ORIGIN_BITBUCKET -> :bitbucket
      :SEAT_ORIGIN_GITLAB -> :gitlab
      _ -> :unspecified
    end
  end

  @spec status_from_grpc(InternalApi.Usage.SeatStatus.t()) :: seat_status()
  def status_from_grpc(value) do
    value
    |> InternalApi.Usage.SeatStatus.key()
    |> case do
      :SEAT_TYPE_ACTIVE_MEMBER -> :active_member
      :SEAT_TYPE_NON_ACTIVE_MEMBER -> :non_active_member
      :SEAT_TYPE_NON_MEMBER -> :non_member
      _ -> :unspecified
    end
  end
end
