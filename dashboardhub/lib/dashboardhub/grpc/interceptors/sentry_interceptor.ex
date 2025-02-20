defmodule Dashboardhub.Grpc.SentryInterceptor do
  @behaviour GRPC.ServerInterceptor
  require Logger

  def init(opts \\ []) do
    opts
  end

  def call(request, stream, next, opts) do
    next.(request, stream)
  rescue
    e in GRPC.RPCError ->
      if capture_status?(e.status, opts) do
        metadata = fetch_metadata(status: GRPC.Status.code_name(e.status))

        Task.Supervisor.start_child(Dashboardhub.SentryEventSupervisor, fn ->
          Sentry.capture_message(e.message, extra: metadata)
        end)
      end

      reraise(e, __STACKTRACE__)

    e ->
      metadata = fetch_metadata()

      Task.Supervisor.start_child(Dashboardhub.SentryEventSupervisor, fn ->
        Sentry.capture_exception(e, stacktrace: __STACKTRACE__, extra: metadata)
      end)

      reraise(e, __STACKTRACE__)
  end

  defp fetch_metadata(defaults \\ []) do
    metadata = Logger.metadata()
    request_id = Keyword.get(metadata, :request_id, "")

    defaults
    |> Keyword.merge(metadata)
    |> Keyword.put_new(:request_id, request_id)
    |> Enum.into(%{})
  end

  defp capture_status?(status, opts) do
    default_status_codes = [
      GRPC.Status.internal(),
      GRPC.Status.unavailable()
    ]

    status in Keyword.get(opts, :status_codes_to_capture, default_status_codes)
  end
end
