// Length caps shared by Parameter (create/edit form) and JustRun form.
// Keep in sync with Front.SafeRegex / Scheduler.SafeRegex (byte caps).
export const MAX_REGEX_PATTERN_LENGTH = 512
export const MAX_PARAM_VALUE_LENGTH = 4096

// Returns UTF-8 byte length so JS limits match Elixir `byte_size/1`.
// `TextEncoder` is available in modern browsers and in Node (used by tests).
export function byteLength(value) {
  if (typeof value !== "string") { return 0 }
  if (typeof TextEncoder === "undefined") { return value.length }
  return new TextEncoder().encode(value).length
}
