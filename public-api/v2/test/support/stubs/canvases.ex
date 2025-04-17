defmodule Support.Stubs.Canvases do
  alias Support.Stubs.{DB, UUID}

  def init do
    DB.add_table(:canvases, [:id, :name, :org_id, :created_at])

    __MODULE__.Grpc.init()
  end

  def create_canvas(org, params \\ []) do
    canvas = build(org, params)

    DB.insert(:canvases, %{
      id: UUID.gen(),
      name: canvas.name,
      org_id: canvas.organization_id,
      created_at: 1_549_885_252
    })
  end

  def build(org, params \\ []) do
    defaults = [
      user_id: UUID.gen(),
      created_at: 1_549_885_252
    ]

    params = defaults |> Keyword.merge(params)

    %{
      name: params[:name],
      organization_id: org.id,
      created_at: params[:created_at]
    }
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(CanvasMock, :create_canvas, &__MODULE__.create_canvas/2)
      GrpcMock.stub(CanvasMock, :describe_canvas, &__MODULE__.describe_canvas/2)
    end

    def describe_canvas(req, _call) do
      case find_canvas(req) do
        {:ok, canvas} ->
          %InternalApi.Delivery.DescribeCanvasResponse{
            canvas: %InternalApi.Delivery.Canvas{
              id: canvas.id,
              name: canvas.name,
              organization_id: canvas.org_id,
              created_at: %Google.Protobuf.Timestamp{seconds: canvas.created_at}
            }
          }

        {:error, message} ->
          raise GRPC.RPCError, status: :not_found, message: message
      end
    end

    def create_canvas(req, _call) do
      org_id = req.organization_id
      id = UUID.gen()

      case find_canvas(%{organization_id: org_id, name: req.name}) do
        {:ok, _} ->
          raise GRPC.RPCError,
            status: :already_exists,
            message: "Canvas #{req.name} already exists"

        _ ->
          DB.insert(:canvases, %{id: id, name: req.name, org_id: org_id, created_at: 1_549_885_252})

          %InternalApi.Delivery.CreateCanvasResponse{
            canvas: %InternalApi.Delivery.Canvas{
              id: id,
              name: req.name,
              organization_id: org_id,
              created_at: %Google.Protobuf.Timestamp{seconds: 1_549_885_252}
            }
          }
      end
    end

    defp find_canvas(req) do
      case Enum.find(org_canvases(req.organization_id), fn c ->
             c.id == req.id || c.name == req.name
           end) do
        nil ->
          {:error, "Canvas not found"}

        canvas ->
          {:ok, canvas}
      end
    end

    defp org_canvases(org_id) do
      DB.filter(:canvases, org_id: org_id)
    end
  end
end
