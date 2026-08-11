defmodule PipelinesAPI.SuperjerryClient do
  @moduledoc """
  Communication with the Superjerry service over gRPC.
  Returns {:ok, result} | {:error, {:user|:not_found|:internal, msg}}.
  """

  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.SuperjerryClient.{RequestFormatter, GrpcClient, ResponseFormatter}

  @spec list_flaky_tests(map()) :: {:ok, Scrivener.Page.t()} | {:error, any()}
  def list_flaky_tests(params) do
    Metrics.benchmark("PipelinesAPI.superjerry_client", ["list_flaky_tests"], fn ->
      params
      |> RequestFormatter.form_list_flaky_tests_request()
      |> GrpcClient.list_flaky_tests()
      |> ResponseFormatter.process_list_flaky_tests_response(params)
    end)
  end

  @spec flaky_test_details(map()) :: {:ok, map()} | {:error, any()}
  def flaky_test_details(params) do
    Metrics.benchmark("PipelinesAPI.superjerry_client", ["flaky_test_details"], fn ->
      params
      |> RequestFormatter.form_flaky_test_details_request()
      |> GrpcClient.flaky_test_details()
      |> ResponseFormatter.process_flaky_test_details_response()
    end)
  end

  @spec flaky_test_disruptions(map()) :: {:ok, Scrivener.Page.t()} | {:error, any()}
  def flaky_test_disruptions(params) do
    Metrics.benchmark("PipelinesAPI.superjerry_client", ["flaky_test_disruptions"], fn ->
      params
      |> RequestFormatter.form_flaky_test_disruptions_request()
      |> GrpcClient.flaky_test_disruptions()
      |> ResponseFormatter.process_flaky_test_disruptions_response(params)
    end)
  end

  @spec list_flaky_history(map()) :: {:ok, list()} | {:error, any()}
  def list_flaky_history(params) do
    Metrics.benchmark("PipelinesAPI.superjerry_client", ["list_flaky_history"], fn ->
      params
      |> RequestFormatter.form_list_flaky_history_request()
      |> GrpcClient.list_flaky_history()
      |> ResponseFormatter.process_list_flaky_history_response()
    end)
  end

  @spec list_disruption_history(map()) :: {:ok, list()} | {:error, any()}
  def list_disruption_history(params) do
    Metrics.benchmark("PipelinesAPI.superjerry_client", ["list_disruption_history"], fn ->
      params
      |> RequestFormatter.form_list_disruption_history_request()
      |> GrpcClient.list_disruption_history()
      |> ResponseFormatter.process_list_disruption_history_response()
    end)
  end
end
