package shared

import (
	"fmt"
	"strings"
	"time"

	responsepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/response_status"
	statuspb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/status"
	"google.golang.org/genproto/googleapis/rpc/code"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// FormatTimestamp renders a protobuf timestamp as RFC3339. Returns an empty string when nil or zero.
func FormatTimestamp(ts *timestamppb.Timestamp) string {
	if ts == nil {
		return ""
	}

	t := ts.AsTime().UTC().Round(time.Second)
	if t.IsZero() {
		return ""
	}
	return t.Format(time.RFC3339)
}

// CheckStatus validates an InternalApi.Status payload.
func CheckStatus(st *statuspb.Status) error {
	if st == nil {
		return fmt.Errorf("missing status in response")
	}
	if st.GetCode() != code.Code_OK {
		return fmt.Errorf("request failed: %s", strings.TrimSpace(st.GetMessage()))
	}
	return nil
}

// CheckResponseStatus validates an InternalApi.ResponseStatus payload.
func CheckResponseStatus(st *responsepb.ResponseStatus) error {
	if st == nil {
		return fmt.Errorf("missing response status")
	}
	if st.GetCode() != responsepb.ResponseStatus_OK {
		return fmt.Errorf("request failed: %s", strings.TrimSpace(st.GetMessage()))
	}
	return nil
}
