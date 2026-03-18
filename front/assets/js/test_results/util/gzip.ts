import { inflate, Inflate } from 'pako';
import { JSONParser, type JSONParserOptions, TokenType } from '@streamparser/json';

interface ReadableStreamWithPipeThrough<R = Uint8Array> extends ReadableStream<R> {
  pipeThrough<T>(
    transform: {
      writable: WritableStream<R>;
      readable: ReadableStream<T>;
    }
  ): ReadableStream<T>;
}

export interface TestResultsPayload {
  testResults: unknown[];
}

export interface DecompressGzipOptions {
  forceStreaming?: boolean;
}

interface ParsedStreamPayload {
  payload: TestResultsPayload;
  bytesRead: number;
}

class SchemaValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = `SchemaValidationError`;
  }
}

const LOG_PREFIX = `[DecompressGzip]`;
const GZIP_MAGIC_1 = 0x1f;
const GZIP_MAGIC_2 = 0x8b;

// Blobs smaller than this use the fast one-shot inflate → JSON.parse path.
// Above this threshold streaming decompression + incremental JSON parsing is
// used to avoid exceeding V8 string-length limits or JSON.parse memory
// constraints. Gzip-compressed JSON with high compression ratios (30-40×) can
// turn a 15 MB download into >500 MB of text, which breaks JSON.parse.
export const STREAMING_THRESHOLD_BYTES = 10 * 1024 * 1024;

const PROGRESS_LOG_INTERVAL = 5000;
const browserConsole: Pick<Console, `info` | `error`> | undefined = globalThis.console;

// @streamparser/json options: extract each element of the top-level testResults
// array individually so memory is never dominated by a single giant object.
// stringBufferSize is the *initial* allocation for string tokens; it auto-grows.
const STREAM_PARSER_OPTIONS: JSONParserOptions = {
  paths: [`$.testResults.*`],
  keepStack: false,
  separator: ``,
  stringBufferSize: 64 * 1024,
};

const logInfo = (message: string, details: Record<string, unknown>): void => {
  browserConsole?.info(`${LOG_PREFIX} ${message}`, details);
};

const logError = (message: string, error: unknown, details: Record<string, unknown>): void => {
  browserConsole?.error(`${LOG_PREFIX} ${message}`, { ...details, error });
};

const readBlobAsArrayBuffer = (blob: Blob): Promise<ArrayBuffer> => {
  if (typeof blob.arrayBuffer === `function`) {
    return blob.arrayBuffer();
  }

  return new Promise((resolve, reject) => {
    const reader = new FileReader();

    reader.onload = () => {
      if (reader.result instanceof ArrayBuffer) {
        resolve(reader.result);
        return;
      }

      reject(new Error(`Unexpected FileReader result type`));
    };

    reader.onerror = () => reject(reader.error || new Error(`Unknown FileReader error`));
    reader.readAsArrayBuffer(blob);
  });
};

const validatePayload = (parsed: unknown): TestResultsPayload => {
  if (
    typeof parsed !== `object` ||
    parsed === null ||
    !Array.isArray((parsed as Record<string, unknown>).testResults)
  ) {
    throw new SchemaValidationError(`Payload is missing testResults array`);
  }

  return parsed as TestResultsPayload;
};

// ---------------------------------------------------------------------------
// Simple path: one-shot inflate → JSON.parse (fast for small files)
// ---------------------------------------------------------------------------

const decompressSimple = async (blob: Blob): Promise<TestResultsPayload> => {
  const startedAt = Date.now();

  logInfo(`Using simple inflate path`, { blobSize: blob.size });

  const buffer = await readBlobAsArrayBuffer(blob);
  const decompressed = inflate(new Uint8Array(buffer), { to: `string` });
  const payload = validatePayload(JSON.parse(decompressed));

  logInfo(`Simple inflate complete`, {
    durationMs: Date.now() - startedAt,
    reportCount: payload.testResults.length,
  });

  return payload;
};

// ---------------------------------------------------------------------------
// Streaming path: chunked decompress → incremental JSON parse
// ---------------------------------------------------------------------------

const decodeChunksToPayload = async (
  feedChunks: (onChunk: (chunk: Uint8Array | string) => void) => Promise<void>
): Promise<ParsedStreamPayload> => {
  const reports: unknown[] = [];
  let bytesRead = 0;

  // Track whether the root JSON object contains a "testResults" key whose
  // value is an array.  Without this the streaming path silently returns
  // { testResults: [] } for payloads that lack the key entirely.
  let foundTestResultsArray = false;
  let depth = 0;
  let expectKey = false;
  let awaitTestResultsValue = false;

  const parser = new JSONParser(STREAM_PARSER_OPTIONS);

  parser.onToken = ({ token, value }) => {
    if (token === TokenType.LEFT_BRACE || token === TokenType.LEFT_BRACKET) {
      if (awaitTestResultsValue && token === TokenType.LEFT_BRACKET) {
        foundTestResultsArray = true;
      }

      awaitTestResultsValue = false;
      depth++;

      if (token === TokenType.LEFT_BRACE && depth === 1) {
        expectKey = true;
      }

      return;
    }

    if (token === TokenType.RIGHT_BRACE || token === TokenType.RIGHT_BRACKET) {
      depth--;
      awaitTestResultsValue = false;
      return;
    }

    if (depth !== 1) {
      return;
    }

    if (token === TokenType.COLON) {
      return;
    }

    if (token === TokenType.COMMA) {
      expectKey = true;
      awaitTestResultsValue = false;
      return;
    }

    if (expectKey && token === TokenType.STRING) {
      awaitTestResultsValue = value === `testResults`;
      expectKey = false;
      return;
    }

    awaitTestResultsValue = false;
  };

  parser.onValue = ({ value, key }) => {
    if (typeof key !== `number` || value === undefined) {
      return;
    }

    reports.push(value);

    if (reports.length % PROGRESS_LOG_INTERVAL === 0) {
      logInfo(`Parsed test report chunk`, {
        reportsParsed: reports.length,
      });
    }
  };

  await feedChunks((chunk: Uint8Array | string) => {
    if (typeof chunk === `string`) {
      bytesRead += chunk.length;
      parser.write(chunk);
      return;
    }

    if (chunk.byteLength === 0) {
      return;
    }

    bytesRead += chunk.byteLength;
    parser.write(chunk);
  });

  parser.end();

  if (bytesRead > 0 && !foundTestResultsArray) {
    throw new SchemaValidationError(`Payload is missing testResults array`);
  }

  return {
    payload: { testResults: reports },
    bytesRead,
  };
};

const streamWithNativeDecompression = async (blob: Blob): Promise<TestResultsPayload> => {
  const startedAt = Date.now();

  logInfo(`Using native DecompressionStream`, {
    blobSize: blob.size,
    blobType: blob.type || `unknown`,
  });

  const ds = new DecompressionStream(`gzip`);
  const decompressedStream = (blob.stream() as unknown as ReadableStreamWithPipeThrough<Uint8Array>).pipeThrough(ds);

  const { payload, bytesRead } = await decodeChunksToPayload(async (onChunk) => {
    const reader = decompressedStream.getReader();

    for (;;) {
      const { done, value } = await reader.read();

      if (done) {
        break;
      }

      if (value) {
        onChunk(value);
      }
    }
  });

  if (blob.size > 0 && bytesRead === 0) {
    throw new Error(`Native decompression produced empty output`);
  }

  logInfo(`Native streaming decompression complete`, {
    durationMs: Date.now() - startedAt,
    reportCount: payload.testResults.length,
    decompressedBytes: bytesRead,
  });

  return payload;
};

const streamWithPako = async (blob: Blob): Promise<TestResultsPayload> => {
  const startedAt = Date.now();

  logInfo(`Using pako streaming`, {
    blobSize: blob.size,
    blobType: blob.type || `unknown`,
  });

  try {
    const compressedBuffer = await readBlobAsArrayBuffer(blob);

    logInfo(`Loaded compressed buffer`, {
      compressedBytes: compressedBuffer.byteLength,
    });

    const { payload, bytesRead } = await decodeChunksToPayload((onChunk) => {
      const inflator = new Inflate();
      (inflator as unknown as { onData: (chunk: Uint8Array) => void, }).onData = onChunk;
      inflator.push(new Uint8Array(compressedBuffer), true);

      if (inflator.err) {
        throw new Error(inflator.msg || `Pako inflate failed`);
      }

      return Promise.resolve();
    });

    logInfo(`Pako streaming complete`, {
      durationMs: Date.now() - startedAt,
      reportCount: payload.testResults.length,
      decompressedBytes: bytesRead,
    });

    return payload;
  } catch (error) {
    logError(`Pako streaming decompression failed`, error, {
      durationMs: Date.now() - startedAt,
      blobSize: blob.size,
    });

    throw error;
  }
};

const decompressStreaming = async (blob: Blob): Promise<TestResultsPayload> => {
  const hasNativeStream = typeof DecompressionStream !== `undefined`;

  if (hasNativeStream) {
    try {
      return await streamWithNativeDecompression(blob);
    } catch (error) {
      if (error instanceof SchemaValidationError) {
        throw error;
      }

      logError(`Native streaming failed, falling back to pako`, error, {
        blobSize: blob.size,
      });
    }
  }

  return streamWithPako(blob);
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

export const IsGzipBlob = async (blob: Blob): Promise<boolean> => {
  if (blob.size < 2) {
    return false;
  }

  const headerBuffer = await readBlobAsArrayBuffer(blob.slice(0, 2));
  const header = new Uint8Array(headerBuffer);

  return header[0] === GZIP_MAGIC_1 && header[1] === GZIP_MAGIC_2;
};

export const DecompressGzipJson = async (
  blob: Blob,
  options: DecompressGzipOptions = {},
): Promise<TestResultsPayload> => {
  const useStreaming = options.forceStreaming || blob.size >= STREAMING_THRESHOLD_BYTES;

  logInfo(`Starting decompression`, {
    blobSize: blob.size,
    blobType: blob.type || `unknown`,
    strategy: useStreaming ? `streaming` : `simple`,
  });

  if (!useStreaming) {
    try {
      return await decompressSimple(blob);
    } catch (error) {
      if (error instanceof SchemaValidationError) {
        throw error;
      }

      logError(`Simple decompression failed, falling back to streaming`, error, {
        blobSize: blob.size,
      });
    }
  }

  return decompressStreaming(blob);
};
