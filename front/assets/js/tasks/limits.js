// Length caps shared by Parameter (create/edit form) and JustRun form.
// Keep in sync with Front.SafeRegex / Scheduler.SafeRegex (byte caps).
export const MAX_REGEX_PATTERN_LENGTH = 512
export const MAX_PARAM_VALUE_LENGTH = 4096

const encoder = (typeof TextEncoder !== "undefined") ? new TextEncoder() : null

// Returns UTF-8 byte length so JS limits match Elixir `byte_size/1`.
export function byteLength(value) {
  if (typeof value !== "string") { return 0 }
  if (!encoder) { return value.length }
  return encoder.encode(value).length
}

export function valueTooLong(value) {
  return typeof value === "string" && byteLength(value) > MAX_PARAM_VALUE_LENGTH
}

export function patternTooLong(parameter) {
  return parameter.validate_input_format
    && typeof parameter.regex_pattern === "string"
    && byteLength(parameter.regex_pattern) > MAX_REGEX_PATTERN_LENGTH
}

// Fail-open mismatch check: returns true only when prerequisites pass,
// the pattern compiles, and `test` rejects the value. Length-cap and
// invalid-pattern cases short-circuit to false so dedicated rules can
// surface their own message without conflict.
export function regexMismatch(parameter, value) {
  if (!parameter || !parameter.validate_input_format) { return false }
  if (!parameter.regex_pattern) { return false }
  if (patternTooLong(parameter)) { return false }
  if (!value || value.length < 1) { return false }
  if (valueTooLong(value)) { return false }
  let regex
  // Pattern is byte-capped above (512 B) and pre-validated upstream;
  // backend Scheduler.SafeRegex bounds matching via PCRE match_limit,
  // so this client-side check is best-effort UX, not a trust boundary.
  try { regex = new RegExp(parameter.regex_pattern) } catch (_err) { return false } // njsscan-ignore: regex_injection_dos
  return !regex.test(value)
}
