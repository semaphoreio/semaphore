package emitter

import (
	"log"
	"sync"

	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
)

func publishCustomDashboards(customDashboards []entity.MetricsDashboard, emitter *PendingMetricsEmitter, wg *sync.WaitGroup) {
	dashboardsSize := len(customDashboards)
	log.Printf("Publishing %d custom dashboards", dashboardsSize)
	dashboardsChan := make(chan entity.MetricsDashboard, dashboardsSize)

	for i := 0; i < workerSize; i++ {
		go emitter.emitMetricsDashboardSettings(wg, dashboardsChan)
	}

	wg.Add(dashboardsSize)
	for _, dashboard := range customDashboards {
		dashboardsChan <- dashboard
	}
	close(dashboardsChan)
}
