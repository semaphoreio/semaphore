package logging

import (
	"net/http"
	"strings"

	"github.com/sirupsen/logrus"
)

const (
	userIDHeader    = "X-Semaphore-User-ID"
	requestIDHeader = "X-Request-Id"
)

// ClientIP returns the original client address as reported by the ingress:
// the first X-Forwarded-For entry, falling back to X-Real-Ip.
func ClientIP(headers http.Header) string {
	if headers == nil {
		return ""
	}

	if xff := strings.TrimSpace(headers.Get("X-Forwarded-For")); xff != "" {
		return strings.TrimSpace(strings.Split(xff, ",")[0])
	}

	return strings.TrimSpace(headers.Get("X-Real-Ip"))
}

// ForwardedFor returns the complete X-Forwarded-For chain, normalized to
// "a, b, c" and with repeated headers merged in order. The first entry is
// whatever the client sent, so it can be forged; the entries appended by our
// own load balancer and ingress cannot, which is why the whole chain is kept.
func ForwardedFor(headers http.Header) string {
	if headers == nil {
		return ""
	}

	var hops []string
	for _, value := range headers.Values("X-Forwarded-For") {
		for _, hop := range strings.Split(value, ",") {
			if hop = strings.TrimSpace(hop); hop != "" {
				hops = append(hops, hop)
			}
		}
	}

	return strings.Join(hops, ", ")
}

// RequestFields returns the caller identity fields carried by an MCP HTTP request:
// the authenticated user (set by the auth service), the client IP plus the full
// X-Forwarded-For chain, the user agent, and the ingress request ID, which joins
// these lines with the ingress access log. Empty values are omitted.
func RequestFields(headers http.Header) logrus.Fields {
	fields := logrus.Fields{}
	if headers == nil {
		return fields
	}

	putIfPresent(fields, "userId", strings.ToLower(strings.TrimSpace(headers.Get(userIDHeader))))
	putIfPresent(fields, "clientIp", ClientIP(headers))
	putIfPresent(fields, "forwardedFor", ForwardedFor(headers))
	putIfPresent(fields, "userAgent", strings.TrimSpace(headers.Get("User-Agent")))
	putIfPresent(fields, "httpRequestId", strings.TrimSpace(headers.Get(requestIDHeader)))

	return fields
}

// ToolCallFields extends RequestFields with the organization the tool call
// targets, when the caller passed it as the organization_id argument.
func ToolCallFields(headers http.Header, arguments any) logrus.Fields {
	fields := RequestFields(headers)

	if args, ok := arguments.(map[string]any); ok {
		if orgID, ok := args["organization_id"].(string); ok {
			putIfPresent(fields, "orgId", strings.ToLower(strings.TrimSpace(orgID)))
		}
	}

	return fields
}

func putIfPresent(fields logrus.Fields, key, value string) {
	if value != "" {
		fields[key] = value
	}
}
