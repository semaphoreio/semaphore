defmodule PipelinesAPI.Logs.Body do
  @moduledoc """
  Writes a job's log as the logs endpoint's response,
  `{ "events": [<event>,<event>,...] }`, from batches of events as loghub
  streams them, so a request never holds the whole log.

  The status has to be chosen before the first byte of the body. Batches are
  held until `commit_bytes` of events have arrived:

    - A log that ends, or fails, before that is answered as one response with
      the right status (a 200 with a Content-Length, or the error), exactly as
      when the whole log was read first.
    - A longer log is sent as a chunked 200 once the threshold is passed,
      and every later batch is written as it arrives.

  A failure after the 200 was sent can't change the status, so the response
  is aborted instead: on HTTP/1.1 the connection is closed without the final
  chunk, on HTTP/2 the stream is reset, so the client sees a failed
  transfer and can't mistake a partial log for a whole one. HTTP/1.0 has no
  way to mark a cut body (it ends when the connection closes); there the
  body just ends early, which is not valid JSON.

  The body is the same, byte for byte, whichever way it is sent.
  """

  require Logger

  alias Plug.Conn

  @prefix ~s({ "events": [)
  @suffix "] }"
  @default_commit_bytes 1024 * 1024

  defstruct [:conn, :commit_bytes, sent?: false, buffer: [], size: 0, empty?: true]

  def new(conn) do
    %__MODULE__{
      conn: Conn.put_resp_content_type(conn, "application/json"),
      commit_bytes: Application.get_env(:pipelines_api, :logs_commit_bytes, @default_commit_bytes)
    }
  end

  def sent?(%__MODULE__{sent?: sent?}), do: sent?

  @doc """
  Adds a batch of events. Returns `{:cont, body}`, or `{:halt, body}` when
  writing to the client fails. (With cowboy that doesn't happen: when the
  client goes away, cowboy kills the request process instead.)

  Once the 200 was sent, an exception here aborts the response too, since
  the caller can no longer answer with an error.
  """
  def add(%__MODULE__{} = body, []), do: {:cont, body}

  def add(%__MODULE__{sent?: false} = body, events) do
    piece = piece(body, events)

    body = %{
      body
      | buffer: [piece | body.buffer],
        size: body.size + IO.iodata_length(piece),
        empty?: false
    }

    if body.size >= body.commit_bytes,
      do: commit(body),
      else: {:cont, body}
  end

  def add(%__MODULE__{sent?: true} = body, events) do
    after_sent(body, fn -> write(%{body | empty?: false}, piece(body, events)) end)
  end

  @doc "Ends a log that was read to the end. Returns the conn."
  def finish(%__MODULE__{sent?: false} = body) do
    Conn.send_resp(body.conn, 200, [@prefix, Enum.reverse(body.buffer), @suffix])
  end

  def finish(%__MODULE__{sent?: true} = body) do
    after_sent(body, fn ->
      {_, body} = write(body, @suffix)
      body.conn
    end)
  end

  @doc """
  Aborts a response that was already sent as a 200 (see the moduledoc).
  Doesn't return.
  """
  def abort(%__MODULE__{sent?: true, conn: conn}) do
    case conn.adapter do
      # The connection process owns the socket; this request process is
      # linked to it and goes down with it.
      {Plug.Cowboy.Conn, %{pid: pid, version: :"HTTP/1.1"}} ->
        Process.exit(pid, :kill)
        exit(:log_stream_aborted)

      # cowboy resets the stream of a request process that exits abnormally.
      _ ->
        exit(:log_stream_aborted)
    end
  end

  # The events of a batch, with the comma that separates them from the
  # previous batch.
  defp piece(%__MODULE__{empty?: true}, events), do: Enum.intersperse(events, ",")
  defp piece(%__MODULE__{empty?: false}, events), do: [",", Enum.intersperse(events, ",")]

  defp commit(body) do
    conn = Conn.send_chunked(body.conn, 200)
    sent = %{body | conn: conn, sent?: true, buffer: [], size: 0}
    after_sent(sent, fn -> write(sent, [@prefix, Enum.reverse(body.buffer)]) end)
  end

  defp after_sent(body, fun) do
    fun.()
  rescue
    e ->
      Logger.error("Writing the log response failed after it started: #{inspect(e)}")
      abort(body)
  catch
    kind, reason ->
      Logger.error("Writing the log response failed after it started: #{inspect({kind, reason})}")
      abort(body)
  end

  defp write(body, data) do
    case Conn.chunk(body.conn, data) do
      {:ok, conn} -> {:cont, %{body | conn: conn}}
      {:error, _reason} -> {:halt, body}
    end
  end
end
