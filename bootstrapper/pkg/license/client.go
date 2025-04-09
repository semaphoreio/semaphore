package license

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

type Client struct {
	httpClient *http.Client
	serverURL  string
}

func NewClient(serverURL string, httpClient *http.Client) *Client {
	if httpClient == nil {
		httpClient = &http.Client{
			Timeout: 10 * time.Second,
		}
	}
	return &Client{
		httpClient: httpClient,
		serverURL: serverURL,
	}
}

func (c *Client) VerifyLicense(req LicenseVerificationRequest) (*LicenseVerificationResponse, error) {
	jsonData, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	resp, err := c.httpClient.Post(
		fmt.Sprintf("%s/api/v1/verify/license", c.serverURL),
		"application/json",
		bytes.NewBuffer(jsonData),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to make request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var verificationResp LicenseVerificationResponse
	if err := json.NewDecoder(resp.Body).Decode(&verificationResp); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &verificationResp, nil
}
