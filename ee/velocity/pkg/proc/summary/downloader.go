package summary

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/semaphoreio/semaphore/velocity/pkg/compression"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	"github.com/semaphoreio/semaphore/velocity/pkg/service"
)

func GetWorkflowSummary(fetcher service.ReportFetcherClient, artifactStoreID string, workflowID string, pipelineID string) (*entity.Summary, error) {
	url, err := fetcher.GetWorkflowReportSummaryURL(artifactStoreID, workflowID, pipelineID)
	if err != nil {
		return nil, err
	}

	var result entity.Summary

	err = download(url, &result)
	if err != nil {
		if err.Error() == "not found" {
			return nil, nil
		}
		return nil, err
	}

	return &result, nil
}

func GetJobSummary(fetcher service.ReportFetcherClient, artifactStoreID string, jobID string) (*entity.Summary, error) {
	url, err := fetcher.GetJobReportSummaryURL(artifactStoreID, jobID)
	if err != nil {
		return nil, err
	}

	var result entity.Summary

	err = download(url, &result)
	if err != nil {
		if err.Error() == "not found" {
			return nil, nil
		}
		return nil, err
	}

	return &result, nil
}

func download(url string, dest interface{}) error {
	response, err := http.Get(url) // #nosec
	if err != nil {
		return err
	}
	defer response.Body.Close()

	if response.StatusCode == http.StatusNotFound {
		return fmt.Errorf("not found")
	}

	bufferedReader := bufio.NewReader(response.Body)

	log.Printf("Decompressing report\n")
	decompressedBody, err := compression.GzipDecompress(bufferedReader, 1024*1024*1) // 1MB max size
	if err != nil {
		return err
	}

	log.Printf("Parsing report\n")
	decoder := json.NewDecoder(decompressedBody)
	err = decoder.Decode(&dest)
	if err != nil {
		return err
	}

	return nil
}

func IsGzipCompressed(reader io.Reader) (bool, error) {
	bufferedReader := bufio.NewReader(reader)

	// Peek the first 2 bytes of the file
	header, err := bufferedReader.Peek(2)
	if err != nil {
		return false, err
	}

	return header[0] == 0x1f && header[1] == 0x8b, nil
}
