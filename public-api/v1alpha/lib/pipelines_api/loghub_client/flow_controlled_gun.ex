defmodule PipelinesAPI.LoghubClient.FlowControlledGun do
  @moduledoc """
  The grpc gun adapter with HTTP/2 flow control tied to the reader.

  By default gun acknowledges every DATA frame (WINDOW_UPDATE) as it arrives
  and sends it to the calling process, so a caller that reads slower than
  loghub sends lets the rest of the log pile up in its mailbox. Connected
  with a gun `flow` (see `http2_opts/0`), gun stops granting the stream more
  window once `flow` frames are delivered and not yet read. Each frame the
  grpc client takes out of the mailbox gives one back, so loghub only sends
  as fast as the caller reads, and at most about `flow` frames plus one
  stream window wait in the mailbox.

  Every other callback is the plain gun adapter.
  """

  alias GRPC.Adapter.Gun

  # 16 frames (16 KiB each by default) plus a 256 KiB stream window: well
  # under 1 MiB per stream, and still more than one 256 KiB loghub batch in
  # flight, so a reader that keeps up isn't slowed down.
  @flow 16
  @stream_window 262_144

  @doc "gun HTTP/2 options that turn the flow control on."
  def http2_opts, do: %{flow: @flow, initial_stream_window_size: @stream_window}

  defdelegate connect(channel, opts), to: Gun
  defdelegate disconnect(channel), to: Gun
  defdelegate send_request(stream, message, opts), to: Gun
  defdelegate send_headers(stream, opts), to: Gun
  defdelegate send_data(stream, message, opts), to: Gun
  defdelegate end_stream(stream), to: Gun
  defdelegate cancel(conn_payload, stream_payload), to: Gun
  defdelegate recv_headers(conn_payload, stream_payload, opts), to: Gun

  def recv_data_or_trailers(
        conn_payload = %{conn_pid: conn_pid},
        stream_payload = %{stream_ref: stream_ref},
        opts
      ) do
    case Gun.recv_data_or_trailers(conn_payload, stream_payload, opts) do
      data = {:data, _} ->
        # gun counts one per DATA frame delivered; this one is read now.
        :gun.update_flow(conn_pid, stream_ref, 1)
        data

      other ->
        other
    end
  end
end
