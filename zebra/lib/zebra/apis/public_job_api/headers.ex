defmodule Zebra.Apis.PublicJobApi.Headers do
  def extract_org_id_and_user_id(call) do
    call
    |> GRPC.Stream.get_headers()
    |> Map.take(["x-semaphore-org-id", "x-semaphore-user-id"])
    |> Map.values()
    |> List.to_tuple()
  end
end
