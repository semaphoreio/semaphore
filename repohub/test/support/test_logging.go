package testsupport

import (
	"fmt"
	"io"
	"log"
	"os"
	"sync"
)

var (
	testLogsSetupDone = false
	logLock           sync.Mutex
)

func SetupTestLogs() {
	logLock.Lock()
	defer logLock.Unlock()

	if testLogsSetupDone {
		return
	}

	testLogsSetupDone = true
	f, err := os.OpenFile("/app/log/test.log", os.O_RDWR|os.O_CREATE|os.O_APPEND, 0600)
	if err != nil {
		fmt.Printf("error opening file: %v", err)
		panic("can't open log file")
	}

	wrt := io.MultiWriter(os.Stdout, f)
	log.SetOutput(wrt)
	log.SetFlags(log.Ldate | log.Lmicroseconds | log.Lshortfile)
}
