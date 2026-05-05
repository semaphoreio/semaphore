export const REGEX_MATCH_TIMEOUT_MS = 50

const VALID_STATUSES = ["match", "mismatch", "invalid", "timeout", "unavailable"]

export function regexMatchWithTimeout(pattern, value, options = {}) {
  const timeoutMs = options.timeoutMs || REGEX_MATCH_TIMEOUT_MS
  const WorkerClass = optionOrGlobal(options, "WorkerClass", "Worker")
  const BlobClass = optionOrGlobal(options, "BlobClass", "Blob")
  const createObjectURL = options.createObjectURL || globalURLMethod("createObjectURL")
  const revokeObjectURL = options.revokeObjectURL || globalURLMethod("revokeObjectURL")
  const setTimeoutFn = options.setTimeoutFn || setTimeout
  const clearTimeoutFn = options.clearTimeoutFn || clearTimeout

  if (!WorkerClass || !BlobClass || !createObjectURL) {
    return Promise.resolve({ status: "unavailable" })
  }

  let objectURL
  let worker

  try {
    const blob = new BlobClass([workerSource()], { type: "application/javascript" })
    objectURL = createObjectURL(blob)
    worker = new WorkerClass(objectURL)
  } catch (_err) {
    if (objectURL && revokeObjectURL) { revokeObjectURL(objectURL) }
    return Promise.resolve({ status: "unavailable" })
  }

  return new Promise((resolve) => {
    let settled = false

    const timeout = setTimeoutFn(() => {
      finish({ status: "timeout" })
    }, timeoutMs)

    const finish = (result) => {
      if (settled) { return }
      settled = true

      clearTimeoutFn(timeout)
      if (worker && worker.terminate) { worker.terminate() }
      if (objectURL && revokeObjectURL) { revokeObjectURL(objectURL) }

      resolve(normalizeResult(result))
    }

    worker.onmessage = (event) => {
      finish(event.data)
    }

    worker.onerror = (event) => {
      if (event && event.preventDefault) { event.preventDefault() }
      finish({ status: "invalid" })
    }

    worker.postMessage({ pattern, value })
  })
}

function optionOrGlobal(options, optionName, globalName) {
  if (Object.prototype.hasOwnProperty.call(options, optionName)) {
    return options[optionName]
  }

  return typeof globalThis !== "undefined" ? globalThis[globalName] : undefined
}

function globalURLMethod(name) {
  if (typeof globalThis === "undefined" || !globalThis.URL) { return undefined }
  return globalThis.URL[name] ? globalThis.URL[name].bind(globalThis.URL) : undefined
}

function normalizeResult(result) {
  if (result && VALID_STATUSES.includes(result.status)) {
    return result
  }

  return { status: "invalid" }
}

function workerSource() {
  return `
self.onmessage = function(event) {
  var data = event.data || {};

  try {
    var regex = new RegExp(data.pattern);
    var matched = regex.test(data.value);
    self.postMessage({ status: matched ? "match" : "mismatch" });
  } catch (_err) {
    self.postMessage({ status: "invalid" });
  }
};
`
}
