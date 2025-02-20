package emitter

import (
	"log"
	"sync"

	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
)

const workerSize = 100

func publishProjectSettings(projectSettings []entity.ProjectSettings, emitter *PendingMetricsEmitter, wg *sync.WaitGroup) {
	settingsChan := make(chan entity.ProjectSettings, len(projectSettings))
	log.Printf(`Publishing %d project settings`, len(projectSettings))

	for i := 0; i < workerSize; i++ {
		go emitter.emitSetting(wg, settingsChan)
	}

	wg.Add(len(projectSettings))
	for _, settings := range projectSettings {
		settingsChan <- settings
	}
	close(settingsChan)
}
