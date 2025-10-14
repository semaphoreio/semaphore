package main

import (
	"flag"
	"fmt"
	"log"

	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/echo"
)

var (
	versionFlag = flag.Bool("version", false, "print the server version and exit")
	nameFlag    = flag.String("name", "semaphore-echo", "implementation name advertised to MCP clients")
	httpAddr    = flag.String("http", ":3001", "address to serve the streamable MCP transport")
	version     = "0.1.0"
)

func main() {
	flag.Parse()

	if *versionFlag {
		fmt.Println(version)
		return
	}

	srv := server.NewMCPServer(*nameFlag, version, server.WithToolCapabilities(true))
	echo.Register(srv)

	httpServer := server.NewStreamableHTTPServer(srv)
	log.Printf("mcp_server listening on %s (streamable HTTP)", *httpAddr)

	if err := httpServer.Start(*httpAddr); err != nil {
		log.Fatalf("streamable HTTP server failed: %v", err)
	}
}
