import { expect } from "chai"
import { regexMatchWithTimeout } from "./safe_regex"

class FakeBlob {
  constructor(parts, options) {
    this.parts = parts
    this.options = options
  }
}

function fakeWorkerOptions(WorkerClass, extraOptions = {}) {
  return {
    WorkerClass,
    BlobClass: FakeBlob,
    createObjectURL: () => "blob:regex-worker",
    revokeObjectURL: () => {},
    timeoutMs: 5,
    ...extraOptions
  }
}

describe("regexMatchWithTimeout", () => {
  it("returns worker match result and terminates worker", async () => {
    let terminated = false

    class FakeWorker {
      postMessage() {
        setTimeout(() => {
          this.onmessage({ data: { status: "mismatch" } })
        }, 0)
      }

      terminate() {
        terminated = true
      }
    }

    const result = await regexMatchWithTimeout(
      "^[0-9]+$",
      "abc",
      fakeWorkerOptions(FakeWorker)
    )

    expect(result.status).to.equal("mismatch")
    expect(terminated).to.equal(true)
  })

  it("returns timeout and terminates worker when worker does not reply", async () => {
    let terminated = false

    class HangingWorker {
      postMessage() {}

      terminate() {
        terminated = true
      }
    }

    const result = await regexMatchWithTimeout(
      "^(a+)+$",
      "aaaaaaaaaaaaaaaa!",
      fakeWorkerOptions(HangingWorker, { timeoutMs: 1 })
    )

    expect(result.status).to.equal("timeout")
    expect(terminated).to.equal(true)
  })

  it("does not run regex on the main thread when worker support is unavailable", async () => {
    const result = await regexMatchWithTimeout(
      "^(a+)+$",
      "aaaaaaaaaaaaaaaa!",
      fakeWorkerOptions(undefined)
    )

    expect(result.status).to.equal("unavailable")
  })
})
