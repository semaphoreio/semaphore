package publicapi

import (
	"fmt"
	"io"
)

type JSONResponseWriter struct {
	w     io.Writer
	first bool
	count int64
	token int64
	final bool
}

func NewJSONResponseWriter(w io.Writer, token int64, final bool) *JSONResponseWriter {
	return &JSONResponseWriter{
		w:     w,
		final: final,
		token: token,
		first: true,
		count: 0,
	}
}

func (writer *JSONResponseWriter) Begin() error {
	// Write initial opening { for the JSON response
	_, err := writer.w.Write([]byte("{"))
	if err != nil {
		return fmt.Errorf("error writing opening delimiter: %v", err)
	}

	// Write beginning of "events" field
	_, err = writer.w.Write([]byte(`"events":[`))
	if err != nil {
		return fmt.Errorf("error writing beginning of 'events' field: %v", err)
	}

	return nil
}

func (writer *JSONResponseWriter) WriteEvent(event []byte) error {
	if !writer.first {
		_, err := writer.w.Write([]byte(","))
		if err != nil {
			return fmt.Errorf("error writing comma %v: %v", event, err)
		}
	}

	_, err := writer.w.Write(event)
	if err != nil {
		return fmt.Errorf("error encoding line %v: %v", event, err)
	}

	writer.first = false
	writer.count++
	return nil
}

func (writer *JSONResponseWriter) Finish() error {
	// Close 'events' field
	_, err := writer.w.Write([]byte("],"))
	if err != nil {
		return fmt.Errorf("error closing 'events' field: %v", err)
	}

	// Write 'next' field and close JSON
	if writer.final {
		_, err = writer.w.Write([]byte(`"next": null}`))
	} else {
		_, err = writer.w.Write([]byte(fmt.Sprintf(`"next": %d}`, writer.token+writer.count)))
	}

	if err != nil {
		return fmt.Errorf("error writing 'next' field: %v", err)
	}

	return nil
}
