package storage

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/loghub2/pkg/utils"
)

// 1 week of TTL
const defaultTTL = 60 * 60 * 24 * 7

// Each job can store up to ~16MB of logs
const defaultMaxKeySize = 16 * 1024 * 1024

// By default, each append operation can take up to 2000 items.
// This is a security measure to make sure we don't blow up the Lua stack.
const defaultMaxAppendItems = 2000

const noMoreSpaceErrMessage = "no more space for key"
const noMoreSpaceLogWarning = "Content of the log is bigger than 16MB. Log is trimmed."

var ErrNoMoreSpaceForKey = errors.New(noMoreSpaceErrMessage)
var ErrTooManyAppendItems = errors.New("too many append items")

const firstLogEventScript = `
redis.call('DEL', KEYS[1])
local result = redis.call('RPUSH', KEYS[1], unpack(ARGV))
redis.call('EXPIRE', KEYS[1], %d)
return result
`

var subsequentLogEventScript = fmt.Sprintf(`
local upto = tonumber(ARGV[1])
local epochSecs = tonumber(ARGV[2])
local usage = redis.call('MEMORY', 'USAGE', KEYS[1])

if not usage then
	usage = 0
end

if usage > %%d then
	local last = table.remove(redis.call('LRANGE', KEYS[1], -1, -1))
	if not string.match(last, "%s") then
		redis.call('RPUSH', KEYS[1], "{\"timestamp\":" .. epochSecs .. ",\"output\":\"%s\",\"event\":\"cmd_output\"}")
	end

	error("key is using " .. usage .. " bytes - %s " .. KEYS[1])
end

local length = redis.call('LLEN', KEYS[1])
if length > upto then
  redis.call('LTRIM', KEYS[1], 0, (upto - 1))
end

local elements = {unpack(ARGV)}
table.remove(elements, 1)
table.remove(elements, 1)

local result = redis.call('RPUSH', KEYS[1], unpack(elements))
redis.call('EXPIRE', KEYS[1], %%d)
return result
`, noMoreSpaceLogWarning, noMoreSpaceLogWarning, noMoreSpaceErrMessage)

type RedisStorage struct {
	Client         *redis.Client
	MaxKeySize     int64
	MaxAppendItems int
}

type RedisConfig struct {
	Address        string
	Port           string
	Username       string
	Password       string
	MaxKeySize     int64
	MaxAppendItems int
}

func NewRedisStorage(config RedisConfig) *RedisStorage {
	rdb := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%s", config.Address, config.Port),
		Username: config.Username,
		Password: config.Password,
		DB:       0,
	})

	maxKeySize := config.MaxKeySize
	if maxKeySize == 0 {
		maxKeySize = defaultMaxKeySize
	}

	maxAppendItems := config.MaxAppendItems
	if maxAppendItems == 0 {
		maxAppendItems = defaultMaxAppendItems
	}

	return &RedisStorage{
		Client:         rdb,
		MaxKeySize:     maxKeySize,
		MaxAppendItems: maxAppendItems,
	}
}

func (s *RedisStorage) CheckConnection() error {
	ctx, cancelFunc := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancelFunc()
	_, err := s.Client.Ping(ctx).Result()
	if err != nil {
		return err
	}

	log.Printf("Successfully connected to Redis")
	return nil
}

func buildEvalArguments(logs []string, startFrom int64) []interface{} {
	var arguments []interface{}
	if startFrom > 0 {
		arguments = make([]interface{}, len(logs)+2)
		arguments[0] = startFrom
		arguments[1] = time.Now().Unix()
		for i, v := range logs {
			arguments[i+2] = v
		}
	} else {
		arguments = make([]interface{}, len(logs))
		for i, v := range logs {
			arguments[i] = v
		}
	}

	return arguments
}

func (s *RedisStorage) AppendLogs(jobId string, startFrom int64, logs []string) error {
	return s.AppendLogsWithContext(context.Background(), jobId, startFrom, logs)
}

func (s *RedisStorage) AppendLogsWithContext(ctx context.Context, jobId string, startFrom int64, logs []string) error {
	filteredLogs := utils.FilterEmpty(logs)
	if len(filteredLogs) > 0 {
		return s.AppendLogsWithOptions(ctx, AppendOptions{
			Key:       jobId,
			StartFrom: startFrom,
			Logs:      utils.FilterEmpty(logs),
			TTL:       defaultTTL,
		})
	}

	return nil
}

type AppendOptions struct {
	Key       string
	StartFrom int64
	Logs      []string
	TTL       int64
}

func (o *AppendOptions) GetTTL() int64 {
	if o.TTL == 0 {
		return defaultTTL
	}

	return o.TTL
}

func (o AppendOptions) GenerateScript(maxKeySize int64) string {
	if o.StartFrom > 0 {
		return fmt.Sprintf(subsequentLogEventScript, maxKeySize, o.GetTTL())
	}

	return fmt.Sprintf(firstLogEventScript, o.GetTTL())
}

func (s *RedisStorage) AppendLogsWithOptions(ctx context.Context, options AppendOptions) error {
	defer watchman.Benchmark(time.Now(), "redis.write")

	logCount := len(options.Logs)
	log.Printf("Received %d log events for %s\n", logCount, options.Key)
	_ = watchman.Submit("log.events.count", logCount)

	if logCount > s.MaxAppendItems {
		return ErrTooManyAppendItems
	}

	arguments := buildEvalArguments(options.Logs, options.StartFrom)
	script := options.GenerateScript(s.MaxKeySize)

	_, err := s.Client.Eval(ctx, script, []string{options.Key}, arguments).Result()
	if err != nil {
		if strings.Contains(err.Error(), noMoreSpaceErrMessage) {
			log.Printf("Key %s is above max allowed size %d: %v", options.Key, s.MaxKeySize, err)
			return ErrNoMoreSpaceForKey
		}

		return err
	}

	return nil
}

func (s *RedisStorage) JobIdExists(ctx context.Context, jobId string) bool {
	exists, err := s.Client.Exists(ctx, jobId).Result()
	if err != nil {
		log.Printf("Error checking if key %s exists: %v", jobId, err)
		return false
	}

	return exists == 1
}

func (s *RedisStorage) GetLogsAsFile(ctx context.Context, jobId string, chunkSize int64) (string, int64, error) {
	file, err := os.CreateTemp("/tmp", jobId)
	if err != nil {
		return "", 0, err
	}

	start := int64(0)
	end := int64(chunkSize - 1)
	for {
		logs, err := s.GetLogsUsingRange(ctx, jobId, start, end)
		if err != nil {
			_ = file.Close()
			return "", start, err
		}

		if len(logs) == 0 {
			break
		}

		_, err = file.WriteString(fmt.Sprintf("%s\n", strings.Join(logs, "\n")))
		if err != nil {
			_ = file.Close()
			return "", start, err
		}

		start = end + 1
		end = end + chunkSize
	}

	return file.Name(), start, file.Close()
}

func (s *RedisStorage) GetLogsUsingRange(ctx context.Context, jobId string, start int64, end int64) ([]string, error) {
	defer watchman.Benchmark(time.Now(), "redis.read")
	logs, err := s.Client.LRange(ctx, jobId, start, end).Result()
	if err != nil {
		return nil, err
	}

	return logs, nil
}

func (s *RedisStorage) DeleteLogs(ctx context.Context, jobId string) (int64, error) {
	return s.Client.Del(ctx, jobId).Result()
}
