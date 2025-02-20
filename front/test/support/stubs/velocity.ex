defmodule Support.Stubs.Velocity do
  alias InternalApi.Velocity, as: API
  alias Support.Stubs.DB

  require Logger

  def init do
    DB.add_table(:pipeline_summaries, [:pipeline_id, :api_model])
    DB.add_table(:job_summaries, [:pipeline_id, :job_id, :api_model])
    DB.add_table(:pipeline_performance_metrics, [:id, :response])
    DB.add_table(:pipeline_frequency_metrics, [:id, :response])
    DB.add_table(:pipeline_reliability_metrics, [:id, :response])
    DB.add_table(:project_performance, [:id, :response])
    DB.add_table(:project_settings, [:id, :response])
    DB.add_table(:metrics_dashboards, [:id, :response])
    DB.add_table(:organization_health, [:project_ids, :api_model])
    DB.add_table(:flaky_tests_filter, [:id, :api_model])

    __MODULE__.Grpc.init()
  end

  @spec pipeline_performance_metrics(request :: API.ListPipelinePerformanceMetricsRequest.t()) ::
          %{
            id: API.ListPipelinePerformanceMetricsRequest.t(),
            response: API.ListPipelinePerformanceMetricsResponse.t()
          }
  def pipeline_performance_metrics(
        request = %API.ListPipelinePerformanceMetricsRequest{},
        _opts \\ []
      ) do
    from_date = Timex.from_unix(request.from_date.seconds)
    to_date = Timex.from_unix(request.to_date.seconds)

    response =
      API.MetricAggregation.key(request.aggregate)
      |> case do
        :RANGE ->
          %API.ListPipelinePerformanceMetricsResponse{
            all_metrics: generate_performance_metrics(from_date, to_date, for_range: true),
            passed_metrics: generate_performance_metrics(from_date, to_date, for_range: true),
            failed_metrics: generate_performance_metrics(from_date, to_date, for_range: true)
          }

        :DAILY ->
          %API.ListPipelinePerformanceMetricsResponse{
            all_metrics: generate_performance_metrics(from_date, to_date),
            passed_metrics: generate_performance_metrics(from_date, to_date),
            failed_metrics: generate_performance_metrics(from_date, to_date)
          }
      end

    %{
      id: request,
      response: response
    }
    |> then(&DB.insert(:pipeline_performance_metrics, &1))
  end

  @spec pipeline_frequency_metrics(request :: API.ListPipelineFrequencyMetricsRequest.t()) ::
          %{
            id: API.ListPipelineFrequencyMetricsRequest.t(),
            response: API.ListPipelineFrequencyMetricsResponse.t()
          }
  def pipeline_frequency_metrics(
        request = %API.ListPipelineFrequencyMetricsRequest{},
        _opts \\ []
      ) do
    from_date = Timex.from_unix(request.from_date.seconds)
    to_date = Timex.from_unix(request.to_date.seconds)

    response =
      API.MetricAggregation.key(request.aggregate)
      |> case do
        :RANGE ->
          %API.ListPipelineFrequencyMetricsResponse{
            metrics: generate_frequency_metrics(from_date, to_date, for_range: true)
          }

        :DAILY ->
          %API.ListPipelineFrequencyMetricsResponse{
            metrics: generate_frequency_metrics(from_date, to_date)
          }
      end

    %{
      id: request,
      response: response
    }
    |> then(&DB.insert(:pipeline_frequency_metrics, &1))
  end

  @spec pipeline_reliability_metrics(request :: API.ListPipelineReliabilityMetricsRequest.t()) ::
          %{
            id: API.ListPipelineReliabilityMetricsRequest.t(),
            response: API.ListPipelineReliabilityMetricsResponse.t()
          }
  def pipeline_reliability_metrics(
        request = %API.ListPipelineReliabilityMetricsRequest{},
        _opts \\ []
      ) do
    from_date = Timex.from_unix(request.from_date.seconds)
    to_date = Timex.from_unix(request.to_date.seconds)

    response =
      API.MetricAggregation.key(request.aggregate)
      |> case do
        :RANGE ->
          %API.ListPipelineReliabilityMetricsResponse{
            metrics: generate_reliability_metrics(from_date, to_date, for_range: true)
          }

        :DAILY ->
          %API.ListPipelineReliabilityMetricsResponse{
            metrics: generate_reliability_metrics(from_date, to_date)
          }
      end

    %{
      id: request,
      response: response
    }
    |> then(&DB.insert(:pipeline_reliability_metrics, &1))
  end

  def update_metrics_dashboard(%API.UpdateMetricsDashboardRequest{id: _dashboard_id, name: _name}) do
    %API.UpdateMetricsDashboardResponse{}
  end

  def delete_metrics_dashboard(%API.DeleteMetricsDashboardRequest{id: dashboard_id}) do
    DB.delete(:metrics_dashboards, dashboard_id)

    %API.DeleteMetricsDashboardResponse{}
  end

  def update_dashboard_item(%API.UpdateDashboardItemRequest{}) do
    %API.UpdateDashboardItemResponse{}
  end

  def initialize_flaky_tests_filters(%API.InitializeFlakyTestsFiltersRequest{
        project_id: project_id,
        organization_id: org_id
      }) do
    [
      %API.FlakyTestsFilter{
        id: "5b235feb-804f-4cba-a443-e4d26d2e3883",
        name: "Show only ignored from master",
        value: "@git.ignored:true @git.branch:master",
        project_id: project_id,
        organization_id: org_id,
        inserted_at:
          Timex.today()
          |> Timex.to_datetime()
          |> Timex.to_unix()
          |> then(&Google.Protobuf.Timestamp.new(seconds: &1))
      },
      %API.FlakyTestsFilter{
        id: "9c08e6e3-a548-4d85-9d2b-75a6fb9e9a60",
        name: "List flaky tests from master only",
        value: "@git.branch:master",
        project_id: project_id,
        organization_id: org_id,
        inserted_at:
          Timex.today()
          |> Timex.shift(days: -1)
          |> Timex.to_datetime()
          |> Timex.to_unix()
          |> then(&Google.Protobuf.Timestamp.new(seconds: &1))
      }
    ]
    |> Enum.each(fn filter ->
      DB.insert(:flaky_tests_filter, %{
        id: filter.id,
        api_model: filter
      })
    end)

    filters(org_id, project_id)
  end

  def list_flaky_tests_filters(%API.ListFlakyTestsFiltersRequest{
        project_id: project_id,
        organization_id: org_id
      }) do
    filters(org_id, project_id)
  end

  defp filters(_org_id, project_id) do
    filters =
      DB.filter(:flaky_tests_filter, fn %{api_model: api_model} ->
        api_model.project_id == project_id
      end)

    %API.ListFlakyTestsFiltersResponse{
      filters: Enum.map(filters, & &1.api_model)
    }
  end

  def create_flaky_tests_filter(%API.CreateFlakyTestsFilterRequest{
        project_id: project_id,
        organization_id: org_id,
        name: name,
        value: value
      }) do
    now =
      Timex.today()
      |> Timex.to_datetime()
      |> Timex.to_unix()
      |> then(&Google.Protobuf.Timestamp.new(seconds: &1))

    id = Ecto.UUID.generate()

    response = %API.FlakyTestsFilter{
      id: Ecto.UUID.generate(),
      name: name,
      value: value,
      inserted_at: now,
      updated_at: now,
      project_id: project_id,
      organization_id: org_id
    }

    %{
      id: id,
      api_model: response
    }
    |> then(&DB.insert(:flaky_tests_filter, &1))

    %API.CreateFlakyTestsFilterResponse{
      filter: response
    }
  end

  def update_flaky_tests_filter(%API.UpdateFlakyTestsFilterRequest{
        id: id,
        name: name,
        value: value
      }) do
    now =
      Timex.today()
      |> Timex.to_datetime()
      |> Timex.to_unix()
      |> then(&Google.Protobuf.Timestamp.new(seconds: &1))

    %API.UpdateFlakyTestsFilterResponse{
      filter: %API.FlakyTestsFilter{
        id: id,
        name: name,
        value: value,
        project_id: Ecto.UUID.generate(),
        organization_id: Ecto.UUID.generate(),
        inserted_at: now,
        updated_at: now
      }
    }
  end

  def remove_flaky_tests_filter(%API.RemoveFlakyTestsFilterRequest{id: id}) do
    DB.delete(:flaky_tests_filter, id)

    %API.RemoveFlakyTestsFilterResponse{}
  end

  def change_dashboard_item_notes(%API.ChangeDashboardItemNotesRequest{id: _id, notes: _notes}) do
    %API.ChangeDashboardItemNotesResponse{}
  end

  def delete_dashboard_item(%API.DeleteDashboardItemRequest{id: _id}) do
    %API.DeleteDashboardItemResponse{}
  end

  def metrics_dashboard(request = %API.CreateMetricsDashboardRequest{}, _opts \\ []) do
    now =
      Timex.today()
      |> Timex.to_datetime()
      |> Timex.to_unix()
      |> then(&Google.Protobuf.Timestamp.new(seconds: &1))

    %API.CreateMetricsDashboardResponse{
      dashboard: %API.MetricsDashboard{
        id: Ecto.UUID.generate(),
        name: request.name,
        organization_id: request.organization_id,
        project_id: request.project_id,
        inserted_at: now,
        updated_at: now,
        items: []
      }
    }
  end

  def metrics_dashboards(request = %API.ListMetricsDashboardsRequest{}, _opts \\ []) do
    response = %API.ListMetricsDashboardsResponse{
      dashboards: [
        %API.MetricsDashboard{
          id: "1",
          name: "Dashboard 1",
          organization_id: "1",
          project_id: request.project_id,
          items: [
            %API.DashboardItem{
              id: Ecto.UUID.generate(),
              name: "Production Duration",
              branch_name: "master",
              metrics_dashboard_id: "1",
              pipeline_file_name: "pipeline.yml",
              settings: %API.DashboardItemSettings{
                metric: 1,
                goal: "10"
              },
              notes:
                "This metric presents us with data about the duration which a pipeline takes to run in a given month in minutes. This is a good metric to track because it can help us identify if our pipelines are taking too long to run. If they are, we can look into ways to optimize them."
            },
            %API.DashboardItem{
              id: Ecto.UUID.generate(),
              name: "Production Duration deviation",
              branch_name: "master",
              metrics_dashboard_id: "1",
              pipeline_file_name: "pipeline.yml",
              settings: %API.DashboardItemSettings{
                metric: 3,
                goal: "10"
              },
              notes:
                "This metric give us the deviation in the duration of a pipeline in the last 30 days"
            }
          ]
        },
        %API.MetricsDashboard{
          id: "2",
          name: "Dashboard 2",
          organization_id: "2",
          project_id: request.project_id,
          items: [
            %API.DashboardItem{
              id: Ecto.UUID.generate(),
              name: "Production Frequency",
              branch_name: "master",
              metrics_dashboard_id: "1",
              pipeline_file_name: ".semaphore/semaphore.yml",
              settings: %API.DashboardItemSettings{
                metric: 2,
                goal: "10"
              },
              notes: "This metric presents the number of successful builds per day."
            },
            %API.DashboardItem{
              id: Ecto.UUID.generate(),
              name: "Production Reliability Percentage",
              branch_name: "master",
              metrics_dashboard_id: "1",
              pipeline_file_name: ".semaphore/daily-prod.yml",
              settings: %API.DashboardItemSettings{
                metric: 3,
                goal: "10"
              },
              notes:
                "This metric presents us with an overall view of the reliability of our production pipelines."
            }
          ]
        }
      ]
    }

    %{
      id: request,
      response: response
    }
    |> then(&DB.insert(:metrics_dashboards, &1))
  end

  def create_dashboard_item(request = %API.CreateDashboardItemRequest{}) do
    %API.CreateDashboardItemResponse{
      item: %API.DashboardItem{
        id: Ecto.UUID.generate(),
        name: request.name,
        branch_name: request.branch_name,
        metrics_dashboard_id: request.metrics_dashboard_id,
        pipeline_file_name: request.pipeline_file_name,
        settings: %API.DashboardItemSettings{
          metric: 1,
          goal: ""
        },
        notes: "Test notes"
      }
    }
  end

  def describe_dashboard_item(_request = %API.DescribeDashboardItemRequest{}) do
    %API.DescribeDashboardItemResponse{
      item: %API.DashboardItem{
        id: Ecto.UUID.generate(),
        name: "fake item",
        branch_name: "main",
        metrics_dashboard_id: "1234",
        pipeline_file_name: "pipeline.yml",
        settings: %API.DashboardItemSettings{
          metric: 2,
          goal: ""
        },
        notes: "Test notes"
      }
    }
  end

  @spec project_performance(request :: API.DescribeProjectPerformanceRequest.t()) ::
          %{
            id: API.DescribeProjectPerformanceRequest.t(),
            response: API.DescribeProjectPerformanceResponse.t()
          }
  def project_performance(request = %API.DescribeProjectPerformanceRequest{}, _opts \\ []) do
    mttr = random(20, 1200)

    last_run =
      Timex.today()
      |> Timex.to_datetime()
      |> Timex.subtract(Timex.Duration.from_minutes(random(20, 12_000)))
      |> Timex.to_unix()
      |> then(&Google.Protobuf.Timestamp.new(seconds: &1))

    response = %API.DescribeProjectPerformanceResponse{
      mean_time_to_recovery_seconds: mttr,
      last_successful_run_at: last_run,
      from_date: request.from_date,
      to_date: request.to_date
    }

    %{
      id: request,
      response: response
    }
    |> then(&DB.insert(:project_performance, &1))
  end

  def project_settings(
        request = %API.DescribeProjectSettingsRequest{},
        _opts \\ []
      ) do
    response = %API.DescribeProjectSettingsResponse{
      settings: generate_project_settings()
    }

    %{
      id: request,
      response: response
    }
    |> then(&DB.insert(:project_settings, &1))
  end

  def update_insights_project_settings(
        request = %API.UpdateProjectSettingsRequest{},
        _opts \\ []
      ) do
    response = %API.UpdateProjectSettingsResponse{
      settings: generate_project_settings()
    }

    %{
      id: request,
      response: response
    }
    |> then(&DB.insert(:project_settings, &1))
  end

  def generate_reliability_metrics(from_date, to_date, opts \\ []) do
    for_range = Keyword.get(opts, :for_range, false)

    limit =
      for_range
      |> case do
        true ->
          1

        false ->
          abs(Timex.diff(from_date, to_date, :days)) + 1
      end

    0..(limit - 1)
    |> Enum.map(fn idx ->
      if for_range == true or random(0, 100) > 30 do
        generate_one_reliability_metric(idx, from_date, to_date, for_range)
      else
        from_date = Timex.add(from_date, Timex.Duration.from_days(idx))
        from_date = Timex.to_unix(from_date)
        to_date = Timex.to_unix(to_date)

        %API.ReliabilityMetric{
          from_date: Google.Protobuf.Timestamp.new(seconds: from_date),
          to_date: Google.Protobuf.Timestamp.new(seconds: to_date),
          all_count: 0,
          passed_count: 0,
          failed_count: 0
        }
      end
    end)
  end

  defp generate_one_reliability_metric(idx, from_date, to_date, for_range) do
    {from_date, to_date} = format_date_range(from_date, to_date, idx, for_range)

    passed_count = random(0, 100)
    failed_count = random(0, 5)

    %API.ReliabilityMetric{
      from_date: Google.Protobuf.Timestamp.new(seconds: from_date),
      to_date: Google.Protobuf.Timestamp.new(seconds: to_date),
      all_count: passed_count + failed_count,
      passed_count: passed_count,
      failed_count: failed_count
    }
  end

  defp generate_frequency_metrics(from_date, to_date, opts \\ []) do
    for_range = Keyword.get(opts, :for_range, false)

    limit =
      for_range
      |> case do
        true ->
          1

        false ->
          abs(Timex.diff(from_date, to_date, :days)) + 1
      end

    0..(limit - 1)
    |> Enum.map(fn idx ->
      if for_range == true or random(0, 100) > 10 do
        generate_one_frequency_metric(for_range, from_date, to_date, idx)
      else
        from_date = Timex.add(from_date, Timex.Duration.from_days(idx))
        to_date = from_date

        %API.FrequencyMetric{
          from_date: Google.Protobuf.Timestamp.new(seconds: Timex.to_unix(from_date)),
          to_date: Google.Protobuf.Timestamp.new(seconds: Timex.to_unix(to_date)),
          all_count: 0
        }
      end
    end)
  end

  defp generate_one_frequency_metric(for_range, from_date, to_date, idx) do
    {from_date, to_date} = format_date_range(from_date, to_date, idx, for_range)

    %API.FrequencyMetric{
      from_date: Google.Protobuf.Timestamp.new(seconds: from_date),
      to_date: Google.Protobuf.Timestamp.new(seconds: to_date),
      all_count: random(0, 100)
    }
  end

  defp generate_performance_metrics(from_date, to_date, opts \\ []) do
    for_range = Keyword.get(opts, :for_range, false)

    limit =
      for_range
      |> case do
        true ->
          1

        false ->
          abs(Timex.diff(from_date, to_date, :days)) + 1
      end

    0..(limit - 1)
    |> Enum.map(fn idx ->
      {from_date, to_date} = format_date_range(from_date, to_date, idx, for_range)

      %API.PerformanceMetric{
        from_date: Google.Protobuf.Timestamp.new(seconds: from_date),
        to_date: Google.Protobuf.Timestamp.new(seconds: to_date),
        count: random(1, 100),
        mean_seconds: random(100, 1000),
        median_seconds: random(1, 100),
        min_seconds: random(1, 100),
        max_seconds: random(1, 100),
        std_dev_seconds: random(1, 100),
        p95_seconds: random(1, 100)
      }
    end)
  end

  defp generate_project_settings do
    %API.Settings{
      cd_branch_name: "master_#{random(1, 100)}",
      cd_pipeline_file_name: ".semaphore/deployment_#{random(1, 100)}.yml",
      ci_branch_name: "master_#{random(1, 100)}",
      ci_pipeline_file_name: ".semaphore/pipeline_#{random(1, 100)}.yml"
    }
  end

  defp random(from, to) do
    from + :rand.uniform(to - from)
  end

  def create_pipeline_summary(params \\ []) do
    alias InternalApi.Velocity.{
      PipelineSummary,
      Summary
    }

    with pipeline_id <- Keyword.get(params, :pipeline_id, Ecto.UUID.generate()),
         summary <- Keyword.get(params, :summary, []) do
      rand = &Enum.random(&1..&2)

      passed = rand.(0, 100)
      skipped = rand.(0, 100)
      error = rand.(0, 100)
      failed = rand.(0, 100)
      disabled = rand.(0, 100)
      duration = rand.(1_000_000, 100_000_000_000)
      total = passed + skipped + error + failed + disabled

      summary =
        [
          total: total,
          passed: passed,
          skipped: skipped,
          error: error,
          failed: failed,
          disabled: disabled,
          # nanoseconds
          duration: duration
        ]
        |> Keyword.merge(summary)

      api_model = PipelineSummary.new(pipeline_id: pipeline_id, summary: Summary.new(summary))

      DB.delete(:pipeline_summaries, fn
        %{pipeline_id: ^pipeline_id} ->
          true

        _ ->
          false
      end)

      DB.insert(:pipeline_summaries, %{
        pipeline_id: pipeline_id,
        api_model: api_model
      })
    end
  end

  def create_job_summary(params \\ []) do
    alias InternalApi.Velocity.{
      JobSummary,
      Summary
    }

    with pipeline_id <- Keyword.get(params, :pipeline_id, Ecto.UUID.generate()),
         job_id <- Keyword.get(params, :job_id, Ecto.UUID.generate()),
         summary <- Keyword.get(params, :summary, []) do
      rand = &Enum.random(&1..&2)

      passed = rand.(0, 100)
      skipped = rand.(0, 100)
      error = rand.(0, 100)
      failed = rand.(0, 100)
      disabled = rand.(0, 100)
      duration = rand.(1_000_000, 100_000_000_000)
      total = passed + skipped + error + failed + disabled

      summary =
        [
          total: total,
          passed: passed,
          skipped: skipped,
          error: error,
          failed: failed,
          disabled: disabled,
          # nanoseconds
          duration: duration
        ]
        |> Keyword.merge(summary)

      api_model =
        JobSummary.new(pipeline_id: pipeline_id, job_id: job_id, summary: Summary.new(summary))

      DB.delete(:job_summaries, fn
        %{job_id: ^job_id} ->
          true

        _ ->
          false
      end)

      DB.insert(:job_summaries, %{
        pipeline_id: pipeline_id,
        job_id: job_id,
        api_model: api_model
      })
    end
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(
        PipelineMetricsMock,
        :list_pipeline_summaries,
        &Grpc.list_pipeline_summaries/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :list_job_summaries,
        &Grpc.list_job_summaries/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :list_pipeline_performance_metrics,
        &Grpc.list_pipeline_performance_metrics/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :list_pipeline_reliability_metrics,
        &Grpc.list_pipeline_reliability_metrics/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :list_pipeline_frequency_metrics,
        &Grpc.list_pipeline_frequency_metrics/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :describe_project_performance,
        &Grpc.describe_project_performance/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :describe_project_settings,
        &Grpc.describe_project_settings/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :update_project_settings,
        &Grpc.update_project_settings/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :list_metrics_dashboards,
        &Grpc.list_metrics_dashboards/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :create_metrics_dashboard,
        &Grpc.create_metrics_dashboard/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :delete_metrics_dashboard,
        &Grpc.delete_metrics_dashboard/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :update_metrics_dashboard,
        &Grpc.update_metrics_dashboard/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :create_dashboard_item,
        &Grpc.create_dashboard_item/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :delete_dashboard_item,
        &Grpc.delete_dashboard_item/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :update_dashboard_item,
        &Grpc.update_dashboard_item/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :change_dashboard_item_notes,
        &Grpc.change_dashboard_item_notes/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :describe_dashboard_item,
        &Grpc.describe_dashboard_item/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :fetch_organization_health,
        &Grpc.fetch_organization_health/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :list_flaky_tests_filters,
        &Grpc.list_flaky_tests_filters/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :initialize_flaky_tests_filters,
        &Grpc.initialize_flaky_tests_filters/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :create_flaky_tests_filter,
        &Grpc.create_flaky_tests_filter/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :update_flaky_tests_filter,
        &Grpc.update_flaky_tests_filter/2
      )

      GrpcMock.stub(
        PipelineMetricsMock,
        :remove_flaky_tests_filter,
        &Grpc.remove_flaky_tests_filter/2
      )
    end

    def list_pipeline_performance_metrics(req, _) do
      DB.find(:pipeline_performance_metrics, req)
      |> case do
        nil -> Support.Stubs.Velocity.pipeline_performance_metrics(req)
        response -> response
      end
      |> then(fn %{response: response} ->
        response
      end)
    end

    def list_pipeline_frequency_metrics(req, _) do
      DB.find(:pipeline_frequency_metrics, req)
      |> case do
        nil -> Support.Stubs.Velocity.pipeline_frequency_metrics(req)
        response -> response
      end
      |> then(fn %{response: response} ->
        response
      end)
    end

    @spec list_pipeline_reliability_metrics(
            InternalApi.Velocity.ListPipelineReliabilityMetricsRequest.t(),
            any
          ) :: InternalApi.Velocity.ListPipelineReliabilityMetricsResponse.t()
    def list_pipeline_reliability_metrics(req, _) do
      DB.find(:pipeline_reliability_metrics, req)
      |> case do
        nil -> Support.Stubs.Velocity.pipeline_reliability_metrics(req)
        response -> response
      end
      |> then(fn %{response: response} ->
        response
      end)
    end

    def describe_project_performance(req, _) do
      DB.find(:project_performance, req)
      |> case do
        nil -> Support.Stubs.Velocity.project_performance(req)
        response -> response
      end
      |> then(fn %{response: response} ->
        response
      end)
    end

    def list_metrics_dashboards(req, _) do
      DB.find(:metrics_dashboards, req)
      |> case do
        nil -> Support.Stubs.Velocity.metrics_dashboards(req)
        response -> response
      end
      |> then(fn %{response: response} ->
        response
      end)
    end

    def create_metrics_dashboard(req, _) do
      Support.Stubs.Velocity.metrics_dashboard(req)
    end

    def delete_metrics_dashboard(req, _) do
      Support.Stubs.Velocity.delete_metrics_dashboard(req)
    end

    def update_metrics_dashboard(req, _) do
      Support.Stubs.Velocity.update_metrics_dashboard(req)
    end

    def describe_dashboard_item(req, _) do
      Support.Stubs.Velocity.describe_dashboard_item(req)
    end

    def create_dashboard_item(req, _) do
      Support.Stubs.Velocity.create_dashboard_item(req)
    end

    def update_dashboard_item(req, _) do
      Support.Stubs.Velocity.update_dashboard_item(req)
    end

    def change_dashboard_item_notes(req, _) do
      Support.Stubs.Velocity.change_dashboard_item_notes(req)
    end

    def delete_dashboard_item(req, _) do
      Support.Stubs.Velocity.delete_dashboard_item(req)
    end

    def list_flaky_tests_filters(req, _) do
      Support.Stubs.Velocity.list_flaky_tests_filters(req)
    end

    def create_flaky_tests_filter(req, _) do
      Support.Stubs.Velocity.create_flaky_tests_filter(req)
    end

    def update_flaky_tests_filter(req, _) do
      Support.Stubs.Velocity.update_flaky_tests_filter(req)
    end

    def remove_flaky_tests_filter(req, _) do
      Support.Stubs.Velocity.remove_flaky_tests_filter(req)
    end

    def describe_project_settings(req, _) do
      DB.find(:project_settings, req)
      |> case do
        nil -> Support.Stubs.Velocity.project_settings(req)
        response -> response
      end
      |> then(fn %{response: response} ->
        response
      end)
    end

    def update_project_settings(req, _) do
      DB.find(:project_settings, req)
      |> case do
        nil -> Support.Stubs.Velocity.update_insights_project_settings(req)
        response -> response
      end
      |> then(fn %{response: response} ->
        response
      end)
    end

    def initialize_flaky_tests_filters(req, _) do
      DB.find_by(:flaky_tests_filter, :project_id, req.project_id)
      |> case do
        nil -> Support.Stubs.Velocity.initialize_flaky_tests_filters(req)
        response -> response
      end
    end

    def list_pipeline_summaries(req, _) do
      alias InternalApi.Velocity.ListPipelineSummariesResponse

      pipeline_summaries =
        DB.filter(:pipeline_summaries, fn summary ->
          summary.pipeline_id in req.pipeline_ids
        end)
        |> Enum.map(fn summary -> summary.api_model end)

      ListPipelineSummariesResponse.new(pipeline_summaries: pipeline_summaries)
    end

    def list_job_summaries(req, _) do
      alias InternalApi.Velocity.ListJobSummariesResponse

      job_summaries =
        DB.filter(:job_summaries, fn summary ->
          summary.job_id in req.job_ids
        end)
        |> Enum.map(fn summary -> summary.api_model end)

      ListJobSummariesResponse.new(job_summaries: job_summaries)
    end

    defp random(from, to) do
      from + :rand.uniform(to - from)
    end

    def fetch_organization_health(req, _) do
      DB.find_by(:organization_health, :project_ids, req.project_ids)
      |> case do
        nil -> Support.Stubs.Velocity.Grpc.organization_health(req)
        response -> response
      end
      |> then(fn %{response: response} ->
        response
      end)
    end

    def organization_health(req) do
      alias InternalApi.Velocity.OrganizationHealthResponse
      alias InternalApi.Velocity.ProjectHealthMetrics
      alias InternalApi.Velocity.Stats

      now =
        Timex.today()
        |> Timex.to_datetime()
        |> Timex.to_unix()
        |> then(&Google.Protobuf.Timestamp.new(seconds: &1))

      response =
        OrganizationHealthResponse.new(
          health_metrics:
            Enum.map(req.project_ids, fn project_id ->
              passed_count = random(0, 100)
              failed_count = random(0, 100)
              all_count = passed_count + failed_count

              passed_runs = random(0, 100)
              failed_runs = random(0, 100)
              all_runs = passed_runs + failed_runs

              ProjectHealthMetrics.new(
                project_id: project_id,
                project_name: "Project #{project_id}",
                last_successful_run_at: now,
                mean_time_to_recovery_seconds: 0,
                default_branch:
                  Stats.new(
                    all_count: all_count,
                    passed_count: passed_count,
                    failed_count: failed_count,
                    avg_seconds: random(60, 10_000),
                    avg_seconds_successful: random(60, 10_000),
                    queue_time_seconds: random(60, 10_000),
                    queue_time_seconds_successful: random(60, 10_000)
                  ),
                all_branches:
                  Stats.new(
                    all_count: all_runs,
                    passed_count: passed_runs,
                    failed_count: failed_runs,
                    avg_seconds: random(60, 10_000),
                    avg_seconds_successful: random(60, 10_000),
                    queue_time_seconds: random(60, 10_000),
                    queue_time_seconds_successful: random(60, 10_000)
                  )
              )
            end)
        )

      %{response: response}
    end
  end

  defp format_date_range(from_date, to_date, idx, for_range) do
    for_range
    |> case do
      true ->
        {from_date, to_date}

      false ->
        from_date = Timex.add(from_date, Timex.Duration.from_days(idx))
        to_date = from_date

        {from_date, to_date}
    end
    |> then(fn {from_date, to_date} ->
      {Timex.to_unix(from_date), Timex.to_unix(to_date)}
    end)
  end
end
