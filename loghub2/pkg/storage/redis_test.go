package storage

import (
	"context"
	"errors"
	"fmt"
	"io/ioutil"
	"strings"
	"testing"
	"time"

	assert "github.com/stretchr/testify/assert"
)

var redisStorage = NewRedisStorage(RedisConfig{
	Address:  "redis",
	Port:     "6379",
	Username: "",
	Password: "",
})

var logEvents1 = []string{"line1", "line2", "line3", "line4", "line5"}
var logEvents2 = []string{"line6", "line7", "line8", "line9", "line10"}

func Test__CheckGoodRedisConnection(t *testing.T) {
	assert.Nil(t, redisStorage.CheckConnection())
}

func Test__CheckBadRedisConnection(t *testing.T) {
	var badRedisStorage = NewRedisStorage(RedisConfig{
		Address:  "bad-host",
		Port:     "9999",
		Username: "",
		Password: "",
	})

	assert.NotNil(t, badRedisStorage.CheckConnection())
}

func Test__AppendLogs(t *testing.T) {
	t.Run("AppendedLogsCanBeFetched", LogsCanBeFetched)
	t.Run("AppendedLogsCanBeFetchedAsFile", LogsCanBeFetchedAsFile)
	t.Run("AppendLogsCanBeCalledMultipleTimes", CanBeCalledMultipleTimes)
	t.Run("AppendLogsCanBeCalledConcurrently", CanBeCalledConcurrently)
	t.Run("DeletesKeyIfStartFromIsZero", DeletesKeyIfStartFromIsZero)
	t.Run("TrimPreviousLogsIfStartFromIsBelowLength", TrimPreviousLogsIfStartFromIsBelowLength)
}

func LogsCanBeFetched(t *testing.T) {
	jobId := "LogsCanBeFetched"
	err := redisStorage.AppendLogs(jobId, 0, logEvents1)
	assert.Nil(t, err)

	logs, err := redisStorage.GetLogsUsingRange(context.Background(), jobId, 0, -1)
	assert.Nil(t, err)
	assert.Equal(t, logs, logEvents1)
}

func LogsCanBeFetchedAsFile(t *testing.T) {
	jobId := "LogsCanBeFetchedAsFile"
	logs := append(logEvents1, logEvents2...)
	err := redisStorage.AppendLogs(jobId, 0, logs)
	assert.Nil(t, err)

	fileName, logsRead, err := redisStorage.GetLogsAsFile(context.Background(), jobId, 2)
	assert.Nil(t, err)
	assert.Equal(t, int(logsRead), len(logs))

	fileContents, err := ioutil.ReadFile(fileName)
	assert.Nil(t, err)
	assert.Equal(t, fmt.Sprintf("%s\n", strings.Join(logs, "\n")), string(fileContents))
}

func CanBeCalledMultipleTimes(t *testing.T) {
	jobId := "CanBeCalledMultipleTimes"
	err := redisStorage.AppendLogs(jobId, 0, logEvents1)
	assert.Nil(t, err)
	err = redisStorage.AppendLogs(jobId, 5, logEvents2)
	assert.Nil(t, err)

	logs, err := redisStorage.GetLogsUsingRange(context.Background(), jobId, 0, -1)
	assert.Nil(t, err)
	assert.Equal(t, logs, append(logEvents1, logEvents2...))
}

func CanBeCalledConcurrently(t *testing.T) {
	jobId := "CanBeCalledConcurrently"
	go redisStorage.AppendLogs(jobId, 0, logEvents1)
	go redisStorage.AppendLogs(jobId, 0, logEvents2)
	go redisStorage.AppendLogs(jobId, 0, []string{"line11", "line12", "line13", "line14", "line15"})
	time.Sleep(time.Second)
	logs, err := redisStorage.GetLogsUsingRange(context.Background(), jobId, 0, -1)
	assert.Nil(t, err)
	assert.Len(t, logs, 5)
}

func DeletesKeyIfStartFromIsZero(t *testing.T) {
	jobId := "DeletesKeyIfStartFromIsZero"
	err := redisStorage.AppendLogs(jobId, 0, logEvents1)
	assert.Nil(t, err)
	err = redisStorage.AppendLogs(jobId, 0, logEvents2)
	assert.Nil(t, err)

	logs, err := redisStorage.GetLogsUsingRange(context.Background(), jobId, 0, -1)
	assert.Nil(t, err)
	assert.Equal(t, logs, logEvents2)
}

func TrimPreviousLogsIfStartFromIsBelowLength(t *testing.T) {
	jobId := "TrimPreviousLogsIfStartFromIsBelowLength"
	err := redisStorage.AppendLogs(jobId, 0, logEvents1)
	assert.Nil(t, err)
	err = redisStorage.AppendLogs(jobId, 5, logEvents2)
	assert.Nil(t, err)
	err = redisStorage.AppendLogs(jobId, 5, logEvents1)
	assert.Nil(t, err)
	logs, err := redisStorage.GetLogsUsingRange(context.Background(), jobId, 0, -1)
	assert.Nil(t, err)
	assert.Equal(t, logs, append(logEvents1, logEvents1...))
}

func Test__LogsHaveATTL(t *testing.T) {
	jobId := "LogsHaveATTL"

	redisStorage.AppendLogsWithOptions(context.Background(), AppendOptions{
		Key:       jobId,
		StartFrom: 0,
		Logs:      logEvents1,
		TTL:       1,
	})

	assert.True(t, redisStorage.JobIdExists(context.Background(), jobId))
	assert.Eventually(t, func() bool { return !redisStorage.JobIdExists(context.Background(), jobId) }, 2*time.Second, 500*time.Millisecond)
}

func Test__LogsHaveAMaxSize(t *testing.T) {
	jobId := "LogsHaveAMaxSize"

	newRedisStorage := NewRedisStorage(RedisConfig{
		Address:    "redis",
		Port:       "6379",
		Username:   "",
		Password:   "",
		MaxKeySize: 256,
	})

	attempts := 0
	appendAndCheckForMaxKeySizeErr := func() bool {
		err := newRedisStorage.AppendLogsWithOptions(context.Background(), AppendOptions{
			Key:       jobId,
			StartFrom: int64(attempts * len(logEvents1)),
			Logs:      logEvents1,
		})

		attempts++
		return errors.Is(err, ErrNoMoreSpaceForKey)
	}

	// the logs we are sending have a size of ~25B,
	// and here, we are appending at most 20 times => 500B.
	// We should be blocked before we get there.
	assert.Eventually(t, appendAndCheckForMaxKeySizeErr, 2*time.Second, 100*time.Millisecond)

	// when this happens, we append a log size limit warning event to the logs
	logEvents, err := newRedisStorage.GetLogsUsingRange(context.Background(), jobId, 0, -1)
	assert.Nil(t, err)

	if assert.NotEmpty(t, logEvents) {
		lastEvent := logEvents[len(logEvents)-1]
		assert.Contains(t, lastEvent, "Content of the log is bigger than 16MB. Log is trimmed.")
	}
}

func Test__AppendHasALimitOnNumberOfItems(t *testing.T) {
	jobId := "AppendHasALimitOnNumberOfItems"

	newRedisStorage := NewRedisStorage(RedisConfig{
		Address:        "redis",
		Port:           "6379",
		Username:       "",
		Password:       "",
		MaxAppendItems: 10,
	})

	tooManyLogEvents := []string{}
	tooManyLogEvents = append(tooManyLogEvents, logEvents1...)
	tooManyLogEvents = append(tooManyLogEvents, logEvents1...)
	tooManyLogEvents = append(tooManyLogEvents, logEvents1...)
	err := newRedisStorage.AppendLogsWithOptions(context.Background(), AppendOptions{
		Key:       jobId,
		StartFrom: 0,
		Logs:      tooManyLogEvents,
	})

	assert.ErrorIs(t, err, ErrTooManyAppendItems)
}

func Test__JobIdExists(t *testing.T) {
	t.Run("ReturnsFalseIfJobDoesNotExist", ReturnsFalseIfJobDoesNotExist)
	t.Run("ReturnsTrueIfJobExists", ReturnsTrueIfJobExists)
}

func ReturnsFalseIfJobDoesNotExist(t *testing.T) {
	assert.False(t, redisStorage.JobIdExists(context.Background(), "this-job-id-does-not-exist"))
}

func ReturnsTrueIfJobExists(t *testing.T) {
	jobId := "ReturnsTrueIfJobExists"
	redisStorage.AppendLogs(jobId, 0, logEvents1)
	assert.True(t, redisStorage.JobIdExists(context.Background(), jobId))
}

func Test__DeleteLogs(t *testing.T) {
	t.Run("DeletingAnInexistentKeyDoesNothing", DeletingAnInexistentKeyDoesNothing)
	t.Run("DeletingAnExistentKeyWorks", DeletingAnExistentKeyWorks)
}

func DeletingAnInexistentKeyDoesNothing(t *testing.T) {
	keysDeleted, err := redisStorage.DeleteLogs(context.Background(), "this-job-id-does-not-exist")
	assert.Nil(t, err)
	assert.Equal(t, keysDeleted, int64(0))
}

func DeletingAnExistentKeyWorks(t *testing.T) {
	jobId := "DeletingAnExistentKeyWorks"
	redisStorage.AppendLogs(jobId, 0, logEvents1)
	keysDeleted, err := redisStorage.DeleteLogs(context.Background(), jobId)
	assert.Nil(t, err)
	assert.Equal(t, keysDeleted, int64(1))
}
