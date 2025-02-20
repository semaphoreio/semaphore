package publicapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/gorilla/handlers"
	"github.com/gorilla/mux"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/loghub2/pkg/auth"
	"github.com/semaphoreio/semaphore/loghub2/pkg/storage"
)

type Server struct {
	httpServer            *http.Server
	Router                *mux.Router
	redisStorage          *storage.RedisStorage
	cloudStorage          storage.Storage
	privateKey            string
	timeoutHandlerTimeout time.Duration
}

func NewServer(
	redisStorage *storage.RedisStorage,
	cloudStorage storage.Storage,
	privateKey string,
	additionalMiddlewares ...mux.MiddlewareFunc) (*Server, error) {
	server := &Server{}
	server.redisStorage = redisStorage
	server.cloudStorage = cloudStorage
	server.privateKey = privateKey
	server.timeoutHandlerTimeout = 20 * time.Second

	server.InitRouter(additionalMiddlewares...)

	return server, nil
}

func (s *Server) InitRouter(additionalMiddlewares ...mux.MiddlewareFunc) {
	r := mux.NewRouter().StrictSlash(true)

	basePath := "/api/v1/logs"

	authenticatedRoute := r.Methods(http.MethodPost, http.MethodGet).Subrouter()
	authenticatedRoute.HandleFunc(basePath+"/{job_id}", s.ReceiveLogs).Methods("POST")
	authenticatedRoute.HandleFunc(basePath+"/{job_id}", s.SendLogs).Methods("GET")
	authenticatedRoute.Use(authMiddleware)
	authenticatedRoute.Use(additionalMiddlewares...)

	unauthenticatedRoute := r.Methods(http.MethodGet).Subrouter()
	unauthenticatedRoute.HandleFunc("/", s.HealthCheck).Methods("GET")

	s.Router = r
}

func (s *Server) Serve(host string, port int) error {
	address := fmt.Sprintf("%s:%d", host, port)

	// NOTE: It would be good to have a smaller timeout for POST /logs
	// than for GET /logs, but I didn't find a good way to do it yet.
	// Having a bigger timeout than needed is still better than having no timeouts at all,
	// so this is still an improvement.
	s.httpServer = &http.Server{
		Addr:         address,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
		Handler: http.TimeoutHandler(
			handlers.LoggingHandler(os.Stdout, s.Router),
			s.timeoutHandlerTimeout,
			"request timed out",
		),
	}

	return s.httpServer.ListenAndServe()
}

func (s *Server) SetTimeoutHandlerTimeout(t time.Duration) {
	s.timeoutHandlerTimeout = t
}

func (s *Server) Close() {
	if err := s.httpServer.Close(); err != nil {
		log.Printf("Error closing server: %v", err)
	}
}

func (s *Server) HealthCheck(w http.ResponseWriter, r *http.Request) {
	respondWith200(w)
}

func (s *Server) ReceiveLogs(w http.ResponseWriter, r *http.Request) {
	defer watchman.Benchmark(time.Now(), "logs.push")

	vars := mux.Vars(r)
	jobId := vars["job_id"]
	if jobId == "" {
		log.Printf("job_id is required")
		http.Error(w, "missing job_id", http.StatusBadRequest)
		return
	}

	jwtToken := r.Context().Value(tokenContextKey).(string)
	err := auth.ValidateToken(jwtToken, s.privateKey, jobId, "PUSH")
	if err != nil {
		respondWith401(w)
		return
	}

	startFromParam := r.URL.Query().Get("start_from")
	if startFromParam == "" {
		log.Printf("start_from is required - rejecting request")
		http.Error(w, "missing start_from", http.StatusBadRequest)
		return
	}

	startFrom, err := strconv.ParseInt(startFromParam, 10, 64)
	if err != nil {
		log.Printf("bad start_from provided: %s", startFromParam)
		http.Error(w, "bad start_from", http.StatusBadRequest)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		log.Printf("Error reading request body: %v", err)
		http.Error(w, "can't read body", http.StatusBadRequest)
		return
	}

	err = s.redisStorage.AppendLogsWithContext(r.Context(), jobId, startFrom, strings.Split(string(body), "\n"))
	if err == nil {
		w.WriteHeader(200)
		return
	}

	// The agent is trying to upload more log events
	// than the maximum allowed per request.
	// This should not happen because the agent should always
	// use the correct threshold, but if someone modifies the agent
	// or gets a hold on the log token, we respond with 413.
	if errors.Is(err, storage.ErrTooManyAppendItems) {
		http.Error(w, "Too many log events", http.StatusRequestEntityTooLarge)
		return
	}

	// If there's no more space for the job logs,
	// we respond with 422. The agent should stop
	// trying to upload more logs after this point.
	if errors.Is(err, storage.ErrNoMoreSpaceForKey) {
		http.Error(w, "No more space", http.StatusUnprocessableEntity)
		return
	}

	// If any other errors happen,
	// we might be dealing with connection issues with Redis,
	// or something else unknown, so we just respond with 500.
	log.Printf("Error appending logs to %s: %v", jobId, err)
	http.Error(w, "Error appending logs", http.StatusInternalServerError)
}

func (s *Server) SendLogs(w http.ResponseWriter, r *http.Request) {
	defer watchman.Benchmark(time.Now(), "logs.pull")

	vars := mux.Vars(r)
	jobId := vars["job_id"]
	if jobId == "" {
		log.Printf("job_id is required")
		http.Error(w, "missing job_id", http.StatusBadRequest)
		return
	}

	jwtToken := r.Context().Value(tokenContextKey).(string)
	err := auth.ValidateToken(jwtToken, s.privateKey, jobId, "PULL")
	if err != nil {
		respondWith401(w)
		return
	}

	token := int64(0)
	tokenString := r.URL.Query().Get("token")
	if tokenString != "" {
		token, err = strconv.ParseInt(tokenString, 10, 64)
		if err != nil {
			http.Error(w, "bad token", http.StatusBadRequest)
			return
		}
	}

	rawLogs := r.URL.Query().Get("raw") == "true"

	// If there are logs in Redis for this job,
	// it means the job did not finish yet, so we grab all the logs from Redis.
	if s.redisStorage.JobIdExists(r.Context(), jobId) {
		err := s.streamLogsFromRedis(r.Context(), jobId, token, rawLogs, w)
		if err != nil {
			log.Printf("Error getting logs for %s from Redis: %v", jobId, err)
			http.Error(w, "error getting logs", http.StatusInternalServerError)
		}

		return
	}

	// If no logs are found in Redis, two things are possible:
	// (1) logs for this job were not received at all
	// (2) job is finished and logs are in final cloud storage.
	exists, err := s.cloudStorage.Exists(r.Context(), jobId)
	if !exists || err != nil {
		http.Error(w, fmt.Sprintf("Logs for %s not found", jobId), http.StatusNotFound)
		return
	}

	err = s.streamLogsFromCloudStorage(r.Context(), jobId, token, rawLogs, w)
	if err != nil {
		log.Printf("Error getting logs for %s from cloud storage: %v", jobId, err)
		http.Error(w, "error getting logs", http.StatusInternalServerError)
	}
}

func (s *Server) streamLogsFromRedis(ctx context.Context, jobId string, token int64, rawLogs bool, w http.ResponseWriter) error {
	logs, err := s.redisStorage.GetLogsUsingRange(ctx, jobId, token, -1)
	if err != nil {
		log.Printf("Error getting logs from Redis: %v", err)
		return err
	}

	if rawLogs {
		return s.streamRawLogsFromRedis(logs, w)
	}

	return s.streamJSONLogsFromRedis(logs, token, w)
}

func (s *Server) streamJSONLogsFromRedis(logs []string, token int64, w http.ResponseWriter) error {
	w.Header().Set("Content-Type", "application/json")

	jsonWriter := NewJSONResponseWriter(w, token, false)
	err := jsonWriter.Begin()
	if err != nil {
		return err
	}

	for _, line := range logs {
		err = jsonWriter.WriteEvent([]byte(line))
		if err != nil {
			return err
		}
	}

	return jsonWriter.Finish()
}

func (s *Server) streamRawLogsFromRedis(logs []string, w http.ResponseWriter) error {
	for _, log := range logs {
		err := s.writeRaw(w, []byte(log))
		if err != nil {
			return err
		}
	}

	return nil
}

func (s *Server) streamLogsFromCloudStorage(ctx context.Context, jobId string, token int64, rawLogs bool, w http.ResponseWriter) error {
	zippedReader, err := s.cloudStorage.ReadFileAsReader(ctx, jobId)
	if err != nil {
		return err
	}

	defer zippedReader.Close()

	if rawLogs {
		return storage.GunzipWithReader(zippedReader, func(line []byte) error {
			return s.writeRaw(w, line)
		})
	}

	return s.streamJSONLogsFromCloudStorage(w, zippedReader, token)
}

func (s *Server) streamJSONLogsFromCloudStorage(w http.ResponseWriter, zippedReader io.Reader, token int64) error {
	w.Header().Set("Content-Type", "application/json")
	jsonWriter := NewJSONResponseWriter(w, token, true)
	err := jsonWriter.Begin()
	if err != nil {
		return err
	}

	i := int64(0)
	err = storage.GunzipWithReader(zippedReader, func(line []byte) error {
		if i >= token {
			return jsonWriter.WriteEvent(line)
		}

		return nil
	})

	if err != nil {
		return err
	}

	return jsonWriter.Finish()
}

func (s *Server) writeRaw(w http.ResponseWriter, line []byte) error {
	v := make(map[string]interface{})
	err := json.Unmarshal(line, &v)
	if err != nil {
		return fmt.Errorf("error parsing line '%v': %v", string(line), err)
	}

	// if we are returning only raw logs, we only need a few event types.
	switch v["event"] {
	case "cmd_started":
		_, err = w.Write([]byte(v["directive"].(string) + "\n"))
	case "cmd_output":
		_, err = w.Write([]byte(v["output"].(string)))
	}

	return err
}
