defmodule Ppl.Sys2app do
  @moduledoc """
  Contains sys2app callback.
  Configures Application environment in runtime.
  """

  alias Util.Config

  @namespaces ~w(METRICS_NAMESPACE K8S_NAMESPACE)

  def callback do
    prefix =  System.get_env("METRICS_PREFIX")
    if prefix do
      Application.put_env(:watchman, :prefix, prefix)
    else
      @namespaces |> Config.set_watchman_prefix("ppl")
    end

    host = System.get_env("METRICS_HOST") || "0.0.0.0"

    port = (System.get_env("METRICS_PORT") || "8125")
    |> Integer.parse()
    |> elem(0)

    send_only = if System.get_env("ON_PREM") == "true", do: :external, else: :internal
    metrics_format = if System.get_env("ON_PREM") == "true", do: :aws_cloudwatch, else: :statsd_graphite

    Application.put_env(:watchman, :host, host)
    Application.put_env(:watchman, :port, port)
    Application.put_env(:watchman, :send_only, send_only)
    Application.put_env(:watchman, :external_backend, metrics_format)
  end

end
