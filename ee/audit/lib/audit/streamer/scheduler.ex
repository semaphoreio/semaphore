defmodule Audit.Streamer.Scheduler do
  require Logger
  @metric_name "audit_streamer"
  @external_metric_name "stream"

  import Ecto.Query

  @max_events_limit 2000

  def start_link(_) do
    {:ok, spawn_link(&loop/0)}
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def loop do
    Task.async(fn -> tick() end) |> Task.await(:infinity)

    :timer.sleep(:timer.minutes(10))

    loop()
  end

  @doc """
  On every tick, we load all the org ids that are set up to stream.

  For every such config that is not paused, we check if there are streams that are old to be exported.
  """
  def tick do
    streamer_configs =
      Watchman.benchmark("#{@metric_name}.tick.duration", fn ->
        Audit.Streamer.Config
        |> where([c], c.status == ^InternalApi.Audit.StreamStatus.value(:ACTIVE))
        |> where([c], c.last_streamed < ^Timex.shift(Timex.now(), days: -1))
        |> or_where([c], is_nil(c.last_streamed))
        |> Audit.Repo.all()
      end)

    if streamer_configs == [] do
      Logger.debug("No set up exporters. Sleeping.")
    else
      Logger.info("Processing #{inspect(streamer_configs)}")

      streamer_configs
      |> Enum.filter(fn config ->
        FeatureProvider.feature_enabled?(:audit_streaming, param: config.org_id)
      end)
      |> Enum.each(fn config -> lock_and_process(config.org_id) end)
    end
  end

  def lock_and_process(org_id) do
    Watchman.benchmark("#{@metric_name}.process.duration", fn ->
      Audit.Repo.transaction(fn ->
        # Audit.Streamer.Config.get(%{org_id: org_id}, %{lock: true})
        config =
          Audit.Streamer.Config
          |> where([c], c.org_id == ^org_id)
          |> lock("FOR UPDATE SKIP LOCKED")
          |> Audit.Repo.one()
          |> Audit.Streamer.Config.unserialize()

        process(config)
      end)
    end)
  end

  def process(nil) do
    Watchman.increment("#{@metric_name}.process.lock_missed")
    {:error, nil}
  end

  def process(config) do
    Watchman.increment("#{@metric_name}.process.lock_obtained")

    Watchman.benchmark("#{@metric_name}.process.duration", fn ->
      with events <-
             Audit.Event.all(%{org_id: config.org_id, streamed: false, limit: @max_events_limit}),
           false <- is_nil(events) or Enum.empty?(events) do
        first =
          events
          |> List.first()

        last =
          events
          |> List.last()

        stream_result =
          events
          |> Audit.Streamer.FileFormatter.csv()
          |> stream(Map.put(config, :file_name, new_file_name(first, last)))

        case stream_result do
          {:ok, size} ->
            event_ids = events |> Enum.map(fn e -> e.id end)

            Audit.Event
            |> where([e], e.id in ^event_ids)
            |> Audit.Repo.update_all(set: [streamed: true])

            Audit.Streamer.Config
            |> where([c], c.org_id == ^config.org_id)
            |> update(set: [last_streamed: ^last.timestamp])
            |> Audit.Repo.update_all([])

            Watchman.increment(
              internal: "#{@metric_name}.process.success",
              external: {@external_metric_name, [result: "success"]}
            )

            Watchman.submit("#{@metric_name}.process.file_size", size)

          {:error, "no events to be streamed"} ->
            Logger.info("processing #{inspect(config)} but there is no new events")

          {:error, msg} ->
            Logger.error("processing #{inspect(config)} #{inspect(msg)}")

            Watchman.increment(
              internal: {"#{@metric_name}.process.failure", ["#{config.org_id}"]},
              external: {@external_metric_name, [result: "failure"]}
            )
        end

        Audit.Streamer.Log.new(
          stream_result,
          config,
          first.timestamp,
          last.timestamp,
          new_file_name(first, last)
        )

        stream_result
      end
    end)
  end

  defp stream(_data, %{file_name: nil}) do
    {:error, "no events to be streamed"}
  end

  ## put provider as :S3 atom
  defp stream(data, %{
         provider: :S3,
         metadata: s3_config,
         cridentials: cridentials,
         file_name: file_name
       }) do
    config = Audit.Streamer.merge_config(s3_config, cridentials)

    upload_result = Audit.Streamer.Provider.S3.upload(data, config, file_name)

    case upload_result do
      {:ok, _} ->
        {:ok, String.length(data)}

      {:error, msg} ->
        {:error, msg}
    end
  end

  def new_file_name(first, last) when is_nil(first) or is_nil(last) do
    nil
  end

  def new_file_name(first, last) do
    "AuditLog-" <>
      (format_time(first.timestamp) <> "-" <> format_time(last.timestamp)) <> ".csv"
  end

  defp format_time(timestamp) do
    timestamp
    |> Timex.format!("{ISOdate}T{h24}:{m}:{s}")
  end

  def max_events_limit, do: @max_events_limit
end
