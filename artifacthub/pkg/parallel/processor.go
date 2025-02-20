package parallel

import (
	"sync"
)

type ParallelProcessor struct {
	Items       []string
	Action      func(item string)
	Parallelism int
}

func NewParallelProcessor(items []string, action func(item string), parallelism int) *ParallelProcessor {
	return &ParallelProcessor{
		Items:       items,
		Action:      action,
		Parallelism: parallelism,
	}
}

func (p *ParallelProcessor) Run() {
	var wg sync.WaitGroup

	for _, chunk := range p.createChunks() {
		wg.Add(1)
		go func(chunk []string) {
			defer wg.Done()
			_ = p.processChunk(chunk)
		}(chunk)
	}

	wg.Wait()
}

func (p *ParallelProcessor) createChunks() [][]string {
	chunkSize := len(p.Items)/p.Parallelism + 1

	var chunks [][]string
	for i := 0; i < len(p.Items); i += chunkSize {
		end := i + chunkSize
		if end > len(p.Items) {
			end = len(p.Items)
		}

		chunks = append(chunks, p.Items[i:end])
	}

	return chunks
}

func (p *ParallelProcessor) processChunk(items []string) error {
	for _, item := range items {
		p.Action(item)
	}

	return nil
}
