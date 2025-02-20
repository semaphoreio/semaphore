package publicapi

import (
	"bytes"
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/loghub2/pkg/auth"
	"github.com/semaphoreio/semaphore/loghub2/pkg/storage"
	"github.com/semaphoreio/semaphore/loghub2/pkg/utils"
	assert "github.com/stretchr/testify/assert"
)

const TestBucketName = "server-test"
const LOGS = `
{"event": "job_started", "timestamp": 1624541916}
{"event": "cmd_started", "timestamp": 1624541916, "directive": "Exporting environment variables"}
{"event": "cmd_output", "timestamp": 1624541916, "output": "Exporting VAR1\n"}
{"event": "cmd_output", "timestamp": 1624541916, "output": "Exporting VAR2\n"}
{"event": "cmd_output", "timestamp": 1624541916, "output": "Exporting VAR3\n"}
`

var privateKey = "test-key"
var u, _ = url.Parse("http://gcs:4443/")
var httpClient = &http.Client{Transport: storage.RoundTripper(*u)}
var gcsStorage, _ = storage.NewGCSStorageWithClient(httpClient, TestBucketName)
var redisStorage = storage.NewRedisStorage(storage.RedisConfig{
	Address:        "redis",
	Port:           "6379",
	Username:       "",
	Password:       "",
	MaxAppendItems: 10,
	MaxKeySize:     1024,
})

var testServer, _ = NewServer(redisStorage, gcsStorage, privateKey)

func Test__HealthCheckEndpointRespondsWith200(t *testing.T) {
	request, _ := http.NewRequest("GET", "/", nil)
	response := executeRequest(request, "")
	assert.Equal(t, response.Code, 200)
}

func Test__PushLogs(t *testing.T) {
	t.Run("no token => 401", func(t *testing.T) {
		jobId := "NoTokenWhenPushingLogsYields401"
		request, _ := http.NewRequest("POST", fmt.Sprintf("/api/v1/logs/%s?start_from=0", jobId), strings.NewReader(LOGS))
		response := executeRequest(request, "")
		assert.Equal(t, response.Code, 401)
	})

	t.Run("bad token => 401", func(t *testing.T) {
		jobId := "BadTokenWhenPushingLogsYields401"
		request, _ := http.NewRequest("POST", fmt.Sprintf("/api/v1/logs/%s?start_from=0", jobId), strings.NewReader(LOGS))
		response := executeRequest(request, generateJwtToken(jobId, "PULL"))
		assert.Equal(t, response.Code, 401)
	})

	t.Run("no start_from => 400", func(t *testing.T) {
		jobId := "PushingLogsWithNoStartFromGets400"
		request, _ := http.NewRequest("POST", fmt.Sprintf("/api/v1/logs/%s", jobId), strings.NewReader(LOGS))
		response := executeRequest(request, generateJwtToken(jobId, "PUSH"))
		assert.Equal(t, response.Code, 400)
	})

	t.Run("request is ok => 200", func(t *testing.T) {
		jobId := "PushingLogsWithValidTokenYields200"
		request, _ := http.NewRequest("POST", fmt.Sprintf("/api/v1/logs/%s?start_from=0", jobId), strings.NewReader(LOGS))
		response := executeRequest(request, generateJwtToken(jobId, "PUSH"))
		assert.Equal(t, response.Code, 200)
	})

	t.Run("too many log events => 413", func(t *testing.T) {
		jobId := "PushingTooManyLogsInTheSameRequestYields413"
		tooManyLogs := LOGS + "\n" + LOGS + "\n" + LOGS
		request, _ := http.NewRequest("POST", fmt.Sprintf("/api/v1/logs/%s?start_from=0", jobId), strings.NewReader(tooManyLogs))
		response := executeRequest(request, generateJwtToken(jobId, "PUSH"))
		assert.Equal(t, response.Code, 413)
	})

	t.Run("no more space for logs => 422", func(t *testing.T) {
		jobId := "NoMoreSpaceForLogsYields422"
		token := generateJwtToken(jobId, "PUSH")

		attempts := 0
		eventuallyFn := func() bool {
			startFrom := attempts * 5
			request, _ := http.NewRequest("POST", fmt.Sprintf("/api/v1/logs/%s?start_from=%d", jobId, startFrom), strings.NewReader(LOGS))
			response := executeRequest(request, token)
			attempts++
			return response.Code == 422
		}

		assert.Eventually(t, eventuallyFn, 2*time.Second, 100*time.Millisecond)
	})

	t.Run("logs are not duplicated", func(t *testing.T) {
		jobId := "LogsAreNotDuplicated"

		// first request
		request, _ := http.NewRequest("POST", fmt.Sprintf("/api/v1/logs/%s?start_from=0", jobId), strings.NewReader(LOGS))
		executeRequest(request, generateJwtToken(jobId, "PUSH"))

		// second request with the same token
		request, _ = http.NewRequest("POST", fmt.Sprintf("/api/v1/logs/%s?token=0", jobId), strings.NewReader(LOGS))
		executeRequest(request, generateJwtToken(jobId, "PUSH"))

		request, _ = http.NewRequest("GET", fmt.Sprintf("/api/v1/logs/%s", jobId), nil)
		response := executeRequest(request, generateJwtToken(jobId, "PULL"))
		assert.Equal(t, response.Code, 200)
		assert.Equal(t, string(response.Body.Bytes()[:]), expectedResponse(LOGS, 0))
	})
}

func Test__PullLogs(t *testing.T) {
	t.Run("no token => 401", func(t *testing.T) {
		jobId := "NoTokenWhenPullingLogsYields401"
		request, _ := http.NewRequest("GET", fmt.Sprintf("/api/v1/logs/%s", jobId), nil)
		response := executeRequest(request, "")
		assert.Equal(t, response.Code, 401)
	})

	t.Run("bad auth token => 401", func(t *testing.T) {
		jobId := "BadTokenWhenPullingLogsYields401"
		request, _ := http.NewRequest("GET", fmt.Sprintf("/api/v1/logs/%s", jobId), nil)
		response := executeRequest(request, generateJwtToken(jobId, "PUSH"))
		assert.Equal(t, response.Code, 401)
	})

	t.Run("no logs => 404", func(t *testing.T) {
		jobId := "PullingNonExistentLogsYields404"
		request, _ := http.NewRequest("GET", fmt.Sprintf("/api/v1/logs/%s", jobId), nil)
		response := executeRequest(request, generateJwtToken(jobId, "PULL"))
		assert.Equal(t, response.Code, 404)
	})

	t.Run("logs exist => 200", func(t *testing.T) {
		// storing logs
		jobId := "PullingExistentLogsYields200"
		request, _ := http.NewRequest("POST", fmt.Sprintf("/api/v1/logs/%s?start_from=0", jobId), strings.NewReader(LOGS))
		executeRequest(request, generateJwtToken(jobId, "PUSH"))

		// retrieving logs
		request, _ = http.NewRequest("GET", fmt.Sprintf("/api/v1/logs/%s", jobId), nil)
		response := executeRequest(request, generateJwtToken(jobId, "PULL"))
		assert.Equal(t, response.Code, 200)
		assert.Equal(t, string(response.Body.Bytes()[:]), expectedResponse(LOGS, 0))
	})

	t.Run("logs exist and are returned as text => 200", func(t *testing.T) {
		// storing logs
		jobId := "PullingExistentRawLogsYields200"
		request, _ := http.NewRequest("POST", fmt.Sprintf("/api/v1/logs/%s?start_from=0", jobId), strings.NewReader(LOGS))
		executeRequest(request, generateJwtToken(jobId, "PUSH"))

		// retrieving logs
		url := fmt.Sprintf("/api/v1/logs/%s?jwt=%s&raw=true", jobId, generateJwtToken(jobId, "PULL"))
		request, _ = http.NewRequest("GET", url, nil)
		request.Header.Set("x-semaphore-org-id", uuid.NewString())
		response := httptest.NewRecorder()
		testServer.Router.ServeHTTP(response, request)

		assert.Equal(t, response.Code, 200)
		assert.Equal(t,
			string(response.Body.Bytes()[:]),
			"Exporting environment variables\nExporting VAR1\nExporting VAR2\nExporting VAR3\n",
		)
	})

	t.Run("using log token => 200", func(t *testing.T) {
		// storing logs
		jobId := "LogsCanBePulledWithToken"
		request, _ := http.NewRequest("POST", fmt.Sprintf("/api/v1/logs/%s?start_from=0", jobId), strings.NewReader(LOGS))
		executeRequest(request, generateJwtToken(jobId, "PUSH"))

		// retrieving logs
		request, _ = http.NewRequest("GET", fmt.Sprintf("/api/v1/logs/%s?token=3", jobId), nil)
		response := executeRequest(request, generateJwtToken(jobId, "PULL"))
		assert.Equal(t, response.Code, 200)
		assert.Equal(t, string(response.Body.Bytes()[:]), expectedResponse(LOGS, 3))
	})

	t.Run("job does not exist => 404", func(t *testing.T) {
		jobId := "this-job-id-does-not-exist"
		request, _ := http.NewRequest("GET", fmt.Sprintf("/api/v1/logs/%s", jobId), nil)
		response := executeRequest(request, generateJwtToken(jobId, "PULL"))
		assert.Equal(t, response.Code, 404)
	})
}

func Benchmark__PullRawLogsFromGCS(b *testing.B) {
	_ = gcsStorage.CreateBucket(TestBucketName, "whatever")

	jobId := "16mb-of-logs"
	err := gcsStorage.SaveFile(context.Background(), "testdata/16mb-logs", jobId)
	if err != nil {
		b.Fatalf("Error uploading data to fake gcs server: %v", err)
	}

	token := generateJwtToken(jobId, "PULL")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		request, _ := http.NewRequest("GET", fmt.Sprintf("/api/v1/logs/%s?raw=true", jobId), nil)
		response := executeRequest(request, token)
		response.Result().Body.Close()
	}
}

func Benchmark__PullJSONLogsFromGCS(b *testing.B) {
	_ = gcsStorage.CreateBucket(TestBucketName, "whatever")

	jobId := "16mb-of-logs"
	err := gcsStorage.SaveFile(context.Background(), "testdata/16mb-logs", jobId)
	if err != nil {
		b.Fatalf("Error uploading data to fake gcs server: %v", err)
	}

	token := generateJwtToken(jobId, "PULL")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		request, _ := http.NewRequest("GET", fmt.Sprintf("/api/v1/logs/%s", jobId), nil)
		response := executeRequest(request, token)
		response.Result().Body.Close()
	}
}

func uploadToRedis(jobId string) error {
	redisStorage := storage.NewRedisStorage(storage.RedisConfig{
		Address:        "redis",
		Port:           "6379",
		Username:       "",
		Password:       "",
		MaxAppendItems: 2000,
		MaxKeySize:     16 * 1024 * 1024,
	})

	f, err := os.Open("testdata/16mb-logs")
	if err != nil {
		return err
	}

	var chunks int64
	var len int64
	var logs = []string{}

	return storage.GunzipWithReader(f, func(line []byte) error {
		if len >= 2000 {
			err2 := redisStorage.AppendLogs(jobId, chunks*2000, logs)
			if err2 != nil {
				return err2
			}

			chunks++
			logs = []string{}
			len = 0
			return err2
		}

		len++
		logs = append(logs, string(line))
		return nil
	})
}

func Benchmark__PullJSONLogsFromRedis(b *testing.B) {
	jobId := "16mb-logs-from-redis"
	err := uploadToRedis(jobId)
	if err != nil {
		b.Fatalf("Error uploading files to Redis")
	}

	token := generateJwtToken(jobId, "PULL")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		request, _ := http.NewRequest("GET", fmt.Sprintf("/api/v1/logs/%s", jobId), nil)
		response := executeRequest(request, token)
		response.Result().Body.Close()
	}
}

func Benchmark__PullRawLogsFromRedis(b *testing.B) {
	jobId := "16mb-logs-from-redis"
	err := uploadToRedis(jobId)
	if err != nil {
		b.Fatalf("Error uploading files to Redis")
	}

	token := generateJwtToken(jobId, "PULL")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		request, _ := http.NewRequest("GET", fmt.Sprintf("/api/v1/logs/%s?raw=true", jobId), nil)
		response := executeRequest(request, token)
		response.Result().Body.Close()
	}
}

func executeRequest(request *http.Request, token string) *httptest.ResponseRecorder {
	request.Header.Set("x-semaphore-org-id", uuid.NewString())

	if token != "" {
		request.Header.Set("Authorization", fmt.Sprintf("Bearer %s", token))
	}

	recorder := httptest.NewRecorder()
	testServer.Router.ServeHTTP(recorder, request)
	return recorder
}

func expectedResponse(logs string, startFrom int64) string {
	logEvents := utils.FilterEmpty(strings.Split(logs, "\n"))
	buf := bytes.NewBuffer(make([]byte, 0))
	responseWriter := NewJSONResponseWriter(buf, startFrom, false)
	_ = responseWriter.Begin()

	for _, logEvent := range logEvents[startFrom:] {
		_ = responseWriter.WriteEvent([]byte(logEvent))
	}

	_ = responseWriter.Finish()
	return buf.String()
}

func generateJwtToken(subject, action string) string {
	token, _ := auth.GenerateToken(privateKey, subject, action, time.Minute)
	return token
}
