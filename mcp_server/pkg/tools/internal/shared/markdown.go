package shared

import (
	"fmt"
	"strings"
)

// MarkdownBuilder helps construct consistent Markdown responses.
type MarkdownBuilder struct {
	sb strings.Builder
}

// NewMarkdownBuilder creates a new Markdown builder.
func NewMarkdownBuilder() *MarkdownBuilder {
	return &MarkdownBuilder{}
}

// H1 adds a level-1 heading.
func (mb *MarkdownBuilder) H1(text string) *MarkdownBuilder {
	mb.sb.WriteString(fmt.Sprintf("# %s\n\n", text))
	return mb
}

// H2 adds a level-2 heading.
func (mb *MarkdownBuilder) H2(text string) *MarkdownBuilder {
	mb.sb.WriteString(fmt.Sprintf("## %s\n\n", text))
	return mb
}

// H3 adds a level-3 heading.
func (mb *MarkdownBuilder) H3(text string) *MarkdownBuilder {
	mb.sb.WriteString(fmt.Sprintf("### %s\n\n", text))
	return mb
}

// Paragraph adds a paragraph of text.
func (mb *MarkdownBuilder) Paragraph(text string) *MarkdownBuilder {
	mb.sb.WriteString(fmt.Sprintf("%s\n\n", text))
	return mb
}

// ListItem adds a bullet point.
func (mb *MarkdownBuilder) ListItem(text string) *MarkdownBuilder {
	mb.sb.WriteString(fmt.Sprintf("- %s\n", text))
	return mb
}

// KeyValue adds a key-value pair as a bullet point.
func (mb *MarkdownBuilder) KeyValue(key, value string) *MarkdownBuilder {
	if value == "" {
		return mb
	}
	mb.sb.WriteString(fmt.Sprintf("- **%s**: %s\n", key, value))
	return mb
}

// Code adds an inline code snippet.
func (mb *MarkdownBuilder) Code(text string) *MarkdownBuilder {
	mb.sb.WriteString(fmt.Sprintf("`%s`", text))
	return mb
}

// Bold adds bold text inline.
func (mb *MarkdownBuilder) Bold(text string) *MarkdownBuilder {
	mb.sb.WriteString(fmt.Sprintf("**%s**", text))
	return mb
}

// Line adds a horizontal rule.
func (mb *MarkdownBuilder) Line() *MarkdownBuilder {
	mb.sb.WriteString("---\n\n")
	return mb
}

// Newline adds a blank line.
func (mb *MarkdownBuilder) Newline() *MarkdownBuilder {
	mb.sb.WriteString("\n")
	return mb
}

// Raw adds raw content without formatting.
func (mb *MarkdownBuilder) Raw(text string) *MarkdownBuilder {
	mb.sb.WriteString(text)
	return mb
}

// String returns the final Markdown content.
func (mb *MarkdownBuilder) String() string {
	return mb.sb.String()
}

// EmptyMessage returns a formatted "no results" message.
func EmptyMessage(entityType string) string {
	return fmt.Sprintf("No %s found.\n", entityType)
}

// PaginationHint returns a formatted pagination hint.
func PaginationHint(cursor, field string) string {
	if cursor == "" {
		return ""
	}
	return fmt.Sprintf("\n---\n\n📄 **More results available**. Use `%s=\"%s\"` to fetch the next page.\n", field, cursor)
}

// StatusIcon returns an appropriate emoji for a status.
func StatusIcon(status string) string {
	status = strings.ToLower(status)
	switch status {
	case "passed", "success", "ok":
		return "✅"
	case "failed", "failure", "error":
		return "❌"
	case "running", "in_progress":
		return "🔄"
	case "stopped", "canceled":
		return "⛔"
	case "queued", "pending":
		return "⏳"
	case "warning":
		return "⚠️"
	default:
		return "•"
	}
}

// FormatBoolean returns a user-friendly boolean representation.
func FormatBoolean(value bool, trueText, falseText string) string {
	if value {
		return trueText
	}
	return falseText
}
