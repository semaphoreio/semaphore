defmodule Guard.InstanceConfig.Token do
  def encode(org_id) do
    # generate random 16 character string
    token = :crypto.strong_rand_bytes(12) |> Base.encode64(padding: false)

    %{org_id: org_id, token: token} |> Jason.encode!() |> Base.encode64(padding: false)
  end

  def decode(token) do
    token
    |> Base.decode64(padding: false)
    |> case do
      {:ok, token} -> token |> Jason.decode()
      _ -> {:error, "Invalid token"}
    end
  end
end
