defmodule Front.Models.Billing.Invoice do
  alias InternalApi.Billing.Invoice, as: GrpcInvoice
  alias __MODULE__

  defstruct [:name, :total, :url]

  @type t :: %Invoice{
          name: String.t(),
          total: String.t(),
          url: String.t()
        }

  @spec new(Enum.t()) :: t()
  def new(params \\ %{}), do: struct(Invoice, params)

  @spec from_grpc(GrpcInvoice.t()) :: t()
  def from_grpc(invoice = %GrpcInvoice{}) do
    new(
      name: invoice.display_name,
      total: invoice.total_bill,
      url: invoice.pdf_download_url
    )
  end
end
