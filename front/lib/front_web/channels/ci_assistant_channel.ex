defmodule FrontWeb.CiAssistantChannel do
  use Phoenix.Channel

  require Logger

  @doc """
  Proxies browser ↔ gateway communication through a Phoenix Channel.

  On join:
    1. Mint HMAC token server-side
    2. Open :gun WS to the gateway with ?hmac_token=
    3. Store :gun pid + stream ref in socket assigns

  Browser → gateway: handle_in("message", ...) forwards JSON via :gun
  Gateway → browser: handle_info({:gun_ws, ...}) pushes via channel
  """

  @impl true
  def join("ci_assistant:lobby", _params, socket) do
    send(self(), :connect_gateway)
    {:ok, socket}
  end

  def join(_topic, _params, _socket), do: {:error, %{reason: "invalid topic"}}

  @impl true
  def handle_in("message", %{"envelope" => json}, socket) do
    case socket.assigns do
      %{gun_pid: pid, gun_ref: ref} ->
        :gun.ws_send(pid, ref, {:text, json})

      _ ->
        push(socket, "gateway_message", %{
          envelope:
            Jason.encode!(%{
              type: "error",
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
              error: %{message: "Not connected to gateway"}
            })
        })
    end

    {:noreply, socket}
  end

  # ── Gateway connection lifecycle ────────────────────────────

  @impl true
  def handle_info(:connect_gateway, socket) do
    %{user_id: user_id, org_id: org_id} = socket.assigns

    hmac_token = Front.CiAssistant.Token.mint(user_id, org_id)

    {host, port, transport} = gateway_config()
    path = "/ws?hmac_token=#{URI.encode_www_form(hmac_token)}"

    case :gun.open(host, port, %{protocols: [:http], transport: transport}) do
      {:ok, pid} ->
        _monitor_ref = Process.monitor(pid)

        case :gun.await_up(pid, 5_000) do
          {:ok, _protocol} ->
            ref = :gun.ws_upgrade(pid, path, [])
            {:noreply, assign(socket, gun_pid: pid, gun_ref: ref)}

          {:error, reason} ->
            Logger.error("CI Assistant: gun await_up failed: #{inspect(reason)}")
            :gun.close(pid)
            push_error(socket, "Failed to connect to gateway")
            {:stop, :normal, socket}
        end

      {:error, reason} ->
        Logger.error("CI Assistant: gun open failed: #{inspect(reason)}")
        push_error(socket, "Failed to connect to gateway")
        {:stop, :normal, socket}
    end
  end

  # WS upgrade succeeded
  def handle_info({:gun_upgrade, _pid, ref, ["websocket"], _headers}, socket) do
    Logger.debug("CI Assistant: gateway WS connected")
    {:noreply, assign(socket, gun_ref: ref)}
  end

  # WS message from gateway → push to browser
  def handle_info({:gun_ws, _pid, _ref, {:text, frame}}, socket) do
    push(socket, "gateway_message", %{envelope: frame})
    {:noreply, socket}
  end

  # WS closed by gateway
  def handle_info({:gun_ws, _pid, _ref, {:close, _code, _reason}}, socket) do
    push_error(socket, "Gateway connection closed")
    {:stop, :normal, socket}
  end

  # gun process died
  def handle_info({:DOWN, _monitor, :process, _pid, reason}, socket) do
    Logger.warning("CI Assistant: gun process exited: #{inspect(reason)}")
    push_error(socket, "Gateway connection lost")
    {:stop, :normal, socket}
  end

  # WS upgrade failed (gun sends :gun_response on HTTP error or :gun_error)
  def handle_info({:gun_response, _pid, _ref, _fin, status, _headers}, socket) do
    Logger.error("CI Assistant: gateway WS upgrade failed with HTTP #{status}")
    push_error(socket, "Gateway rejected connection")
    {:stop, :normal, socket}
  end

  def handle_info({:gun_error, _pid, _ref, reason}, socket) do
    Logger.error("CI Assistant: gun error: #{inspect(reason)}")
    push_error(socket, "Gateway connection error")
    {:stop, :normal, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    if pid = socket.assigns[:gun_pid] do
      :gun.close(pid)
    end

    :ok
  end

  # ── Helpers ────────────────────────────────────────────────

  defp push_error(socket, message) do
    push(socket, "gateway_message", %{
      envelope:
        Jason.encode!(%{
          type: "error",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          error: %{message: message}
        })
    })
  end

  defp gateway_config do
    url = Application.get_env(:front, :ci_assistant_gateway_ws_url) || "ws://localhost:8080/ws"
    uri = URI.parse(url)
    host = to_charlist(uri.host || "localhost")

    {transport, default_port} =
      case uri.scheme do
        "wss" -> {:tls, 443}
        _ -> {:tcp, 80}
      end

    port = uri.port || default_port
    {host, port, transport}
  end
end
