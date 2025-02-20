package parallel

import (
	"fmt"
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
)

func Test__ParallelProcessor(t *testing.T) {
	items := generateItems(1000)
	processedItems := []string{}

	var lock sync.Mutex
	processor := NewParallelProcessor(items, func(item string) {
		lock.Lock()
		processedItems = append(processedItems, item)
		lock.Unlock()
	}, 3)

	processor.Run()

	// assert all elements are processed
	assert.Len(t, processedItems, 1000)
	for _, i := range items {
		assert.Contains(t, processedItems, i)
	}
}

func Test__ParallelProcessorChunkSizeOf1(t *testing.T) {
	items := generateItems(5)
	processedItems := []string{}

	var lock sync.Mutex
	processor := NewParallelProcessor(items, func(item string) {
		lock.Lock()
		processedItems = append(processedItems, item)
		lock.Unlock()
	}, 10)

	processor.Run()

	// assert all elements are processed
	assert.Len(t, processedItems, 5)
	for _, i := range items {
		assert.Contains(t, processedItems, i)
	}
}

func generateItems(length int) []string {
	items := []string{}
	for i := 0; i < length; i++ {
		items = append(items, fmt.Sprintf("item%d", i))
	}

	return items
}
