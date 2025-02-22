defmodule Zebra.Workers.Agent.HostedAgent do
  require Logger
  defstruct [:id, :name, :ip_address, :ctrl_port, :auth_token, :ssh_port]

  alias InternalApi.Chmura.Chmura.Stub
  alias InternalApi.Chmura.{OccupyAgentRequest, ReleaseAgentRequest}

  def http_options,
    do: [
      hackney: [
        :insecure,
        connect_timeout: 2_000,
        recv_timeout: 3_000
      ],
      ssl: [
        server_name_indication: :disable
      ]
    ]

  # sends a HTTP message to the agent
  def send(host, port, token, path, payload) do
    url = "https://#{host}:#{port}#{path}"

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{token || ""}"}
    ]

    case HTTPoison.post(url, payload, headers, http_options()) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        :ok

      e ->
        Logger.error("Failed to send to #{url}. Error #{inspect(e)}")
        submit_send_errors(host, e)
        {:error, e}
    end
  end

  defp submit_send_errors(host, error) do
    host = String.replace(host, ".", "-")

    case error do
      {:ok, %HTTPoison.Response{body: body, status_code: 401}} ->
        if String.contains?(body, "signature is invalid") do
          Watchman.increment({"agent.send.error", ["401_invalid_signature", host]})
        else
          Watchman.increment({"agent.send.error", ["401_unknown", host]})
        end

      {:error, %HTTPoison.Error{reason: {:tls_alert, _}}} ->
        Watchman.increment({"agent.send.error", ["tls_alert", host]})

      {:error, _} ->
        Watchman.increment({"agent.send.error", ["unknown", host]})

      _ ->
        Watchman.increment({"agent.send.error", ["unknown", host]})
    end
  end

  def occupy(job) do
    Task.async(fn ->
      Watchman.benchmark("zebra.external.chmura.occupy", fn ->
        request =
          OccupyAgentRequest.new(
            request_id: job.id,
            machine:
              InternalApi.Chmura.Agent.Machine.new(
                type: job.machine_type,
                os_image: job.machine_os_image
              )
          )

        Logger.info("Occupying agent for job: #{job.id} ...")

        case channel() |> Stub.occupy_agent(request, timeout: 30_000) do
          {:ok, response} ->
            {:ok, construct_agent(response)}

          {:error, error} ->
            Logger.error(inspect(error))
            {:error, error}
        end
      end)
    end)
    |> Task.await(:infinity)
  end

  def release(job) do
    Watchman.benchmark("zebra.external.chmura.occupy", fn ->
      Logger.info("Releasing agent for job '#{job.id}' agent_id: '#{job.agent_id}'")

      request = ReleaseAgentRequest.new(agent_id: job.agent_id)

      case Stub.release_agent(channel(), request, timeout: 30_000) do
        {:ok, _} ->
          :ok

        {:error, err} ->
          ids = "job_id:'#{job.id}' agent_id:'#{job.agent_id}'"
          Logger.error("Error while releasing agent #{ids}, err: #{inspect(err)}")
          {:error, err.message}
      end
    end)
  end

  def construct_agent(response) do
    %__MODULE__{
      id: response.agent.id,
      name: "",
      ip_address: response.agent.ip_address,
      ctrl_port: response.agent.ctrl_port,
      auth_token: response.agent.auth_token || "",
      ssh_port: response.agent.ssh_port
    }
  end

  defp channel do
    endpoint = Application.fetch_env!(:zebra, :chmura_endpoint)

    {:ok, channel} = GRPC.Stub.connect(endpoint)
    channel
  end
end
