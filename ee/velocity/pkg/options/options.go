// Package options is used to define options for the tackle.
package options

import (
	"os"

	"github.com/renderedtext/go-tackle"
	"github.com/semaphoreio/semaphore/velocity/pkg/env"
)

const (
	pipelineDoneOptions           = "plumber"
	afterPipelineDoneOptions      = "after_pipeline"
	recentOptions                 = "recent"
	weeklyOptions                 = "weekly"
	pipelineSummaryOptions        = "pipeline_summary"
	jobSummaryOptions             = "job_summary"
	serverFarmOptions             = "server_farm"
	collectPipelineMetricsOptions = "collect_pipeline_metrics"
	projectHubOptions             = "project_hub"
	superjerryJobSummary          = "superjerry_job_summary"
)

func CollectPipelineMetricsDoneEvent() tackle.Options {
	return optionsForKind(collectPipelineMetricsOptions)
}

func PipelineDoneEvent() tackle.Options {
	return optionsForKind(pipelineDoneOptions)
}

func AfterPipelineDoneEvent() tackle.Options {
	return optionsForKind(afterPipelineDoneOptions)
}

func Recent() tackle.Options {
	return optionsForKind(recentOptions)
}

func Weekly() tackle.Options {
	return optionsForKind(weeklyOptions)
}

func PipelineSummaryDone() tackle.Options {
	return optionsForKind(pipelineSummaryOptions)
}

func JobSummaryDone() tackle.Options {
	return optionsForKind(jobSummaryOptions)
}

func JobSummaryJobFinished() tackle.Options {
	return optionsForKind(serverFarmOptions)
}

func JobFinished() tackle.Options {
	return optionsForKind(serverFarmOptions)
}

func SuperjerryJobSummary() tackle.Options {
	return optionsForKind(superjerryJobSummary)
}

func ProjectDeleted() tackle.Options {
	return optionsForKind(projectHubOptions)
}

func optionsForKind(kind string) tackle.Options {
	rabbitURL := env.GetOrFail("RABBITMQ_URL")
	hostname := os.Getenv("HOSTNAME")

	switch kind {
	case collectPipelineMetricsOptions:
		return tackle.Options{
			URL:            rabbitURL,
			ConnectionName: hostnameOrValue(hostname, "velocity.pipeline_metrics_emitter"),
			RemoteExchange: "velocity_pipeline_metrics_exchange",
			RoutingKey:     "done",
			Service:        "velocity.pipeline_metrics_emitter",
		}
	case pipelineDoneOptions:
		return tackle.Options{
			URL:            rabbitURL,
			ConnectionName: hostnameOrValue(hostname, "velocity.pipeline_processor"),
			RemoteExchange: "pipeline_state_exchange",
			RoutingKey:     "done",
			Service:        "velocity.pipeline_processor",
		}
	case afterPipelineDoneOptions:
		return tackle.Options{
			URL:            rabbitURL,
			ConnectionName: hostnameOrValue(hostname, "velocity.pipeline_summary_processor"),
			RemoteExchange: "after_pipeline_state_exchange",
			RoutingKey:     "done",
			Service:        "velocity.pipeline_summary_processor",
		}
	case recentOptions:
		return tackle.Options{
			URL:            rabbitURL,
			ConnectionName: hostnameOrValue(hostname, "velocity.recent_pipeline"),
			RemoteExchange: "velocity_notification_exchange",
			RoutingKey:     "recent",
			Service:        "velocity.recent_pipeline",
		}
	case weeklyOptions:
		return tackle.Options{
			URL:            rabbitURL,
			ConnectionName: hostnameOrValue(hostname, "velocity.weekly_pipeline"),
			RemoteExchange: "velocity_notification_exchange",
			Service:        "velocity.weekly_pipeline",
			RoutingKey:     "weekly",
		}

	case pipelineSummaryOptions:
		return tackle.Options{
			URL:            rabbitURL,
			ConnectionName: hostnameOrValue(hostname, "velocity.pipeline_summary_processor"),
			RemoteExchange: "velocity_pipeline_summary_exchange",
			Service:        "velocity.pipeline_summary_processor",
			RoutingKey:     "done",
		}

	case jobSummaryOptions:
		return tackle.Options{
			URL:            rabbitURL,
			ConnectionName: hostnameOrValue(hostname, "velocity.job_summary_processor"),
			RemoteExchange: "velocity_job_summary_exchange",
			Service:        "velocity.job_summary_processor",
			RoutingKey:     "done",
		}

	case serverFarmOptions:
		return tackle.Options{
			URL:            rabbitURL,
			ConnectionName: hostnameOrValue(hostname, "velocity.job_summary_processor"),
			RemoteExchange: "server_farm.job_state_exchange",
			Service:        "velocity.job_summary_processor",
			RoutingKey:     "job_finished",
		}

	case projectHubOptions:
		return tackle.Options{
			URL:            rabbitURL,
			ConnectionName: hostnameOrValue(hostname, "velocity.organization_health_processor"),
			RemoteExchange: "project_exchange",
			Service:        "velocity.organization_health_processor",
			RoutingKey:     "deleted",
		}

	case superjerryJobSummary:
		return tackle.Options{
			URL:            rabbitURL,
			ConnectionName: hostnameOrValue(hostname, "velocity.superjerry_collector"),
			RemoteExchange: "velocity_job_summary_exchange",
			Service:        "velocity.superjerry_collector",
			RoutingKey:     "done",
		}
	}

	return tackle.Options{}
}

func hostnameOrValue(hostname, value string) string {
	if hostname == "" {
		return value
	}

	return hostname
}
