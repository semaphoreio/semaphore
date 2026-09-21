import { expect } from 'chai';
import { DecompressGzipJson, IsGzipBlob, STREAMING_THRESHOLD_BYTES } from './gzip';
import { gzip } from 'pako';
import { JSDOM } from 'jsdom';

interface BlobWithMockedStream {
  stream: () => {
    pipeThrough: () => ReadableStream<Uint8Array>;
  };
}

const makeGzipBlob = (payload: Record<string, unknown>): Blob => {
  const compressed = gzip(JSON.stringify(payload));
  return new Blob([new Uint8Array(compressed).buffer], { type: `application/json` });
};

describe(`DecompressGzipJson`, () => {
  beforeEach(() => {
    const dom = new JSDOM(`<!DOCTYPE html><p>Some DOM</p>`);
    global.window = dom.window as any;
    global.FileReader = dom.window.FileReader as any;
    (global as any).DecompressionStream = undefined;
  });

  afterEach(() => {
    delete (global as any).DecompressionStream;
  });

  describe(`simple path (small blobs)`, () => {
    it(`should parse a gzipped test results payload`, async () => {
      const payload = {
        testResults: [
          { id: `report-1`, name: `Report 1`, suites: [] },
          { id: `report-2`, name: `Report 2`, suites: [] },
        ]
      };

      const parsedPayload = await DecompressGzipJson(makeGzipBlob(payload));
      expect(parsedPayload).to.deep.equal(payload);
    });

    it(`should parse an empty testResults array`, async () => {
      const payload = { testResults: [] };

      const parsedPayload = await DecompressGzipJson(makeGzipBlob(payload));
      expect(parsedPayload).to.deep.equal(payload);
    });

    it(`should fall back to streaming when simple inflate fails`, async () => {
      const payload = {
        testResults: [
          { id: `report-1`, name: `Report 1`, suites: [] },
        ]
      };

      const blob = makeGzipBlob(payload);
      const originalParse = JSON.parse;
      let parseBlocked = true;

      JSON.parse = ((text: string) => {
        if (parseBlocked) {
          parseBlocked = false;
          throw new RangeError(`Simulated string too long`);
        }
        // eslint-disable-next-line @typescript-eslint/no-unsafe-return
        return originalParse(text);
      }) as typeof JSON.parse;

      try {
        const parsedPayload = await DecompressGzipJson(blob);
        expect(parsedPayload).to.deep.equal(payload);
      } finally {
        JSON.parse = originalParse;
      }
    });
  });

  describe(`streaming path (forceStreaming or large blobs)`, () => {
    it(`should parse a gzipped payload via pako streaming`, async () => {
      const payload = {
        testResults: [
          { id: `report-1`, name: `Report 1`, suites: [] },
          { id: `report-2`, name: `Report 2`, suites: [] },
        ]
      };

      const parsedPayload = await DecompressGzipJson(
        makeGzipBlob(payload),
        { forceStreaming: true },
      );
      expect(parsedPayload).to.deep.equal(payload);
    });

    it(`should parse an empty testResults array via streaming`, async () => {
      const payload = { testResults: [] };

      const parsedPayload = await DecompressGzipJson(
        makeGzipBlob(payload),
        { forceStreaming: true },
      );
      expect(parsedPayload).to.deep.equal(payload);
    });

    it(`should fallback to pako streaming when native DecompressionStream fails`, async () => {
      let streamAttempted = false;

      (global as any).DecompressionStream = class {
        constructor() {
          streamAttempted = true;
        }
      };

      const payload = {
        testResults: [
          { id: `report-1`, name: `Report 1`, suites: [] },
          { id: `report-2`, name: `Report 2`, suites: [] },
        ]
      };

      const parsedPayload = await DecompressGzipJson(
        makeGzipBlob(payload),
        { forceStreaming: true },
      );
      expect(streamAttempted).to.equal(true);
      expect(parsedPayload).to.deep.equal(payload);
    });

    it(`should fallback to pako when native stream returns empty output`, async () => {
      const payload = {
        testResults: [
          { id: `report-1`, name: `Report 1`, suites: [] },
        ]
      };

      const blob = makeGzipBlob(payload);

      (blob as unknown as BlobWithMockedStream).stream = () => ({
        pipeThrough: () => new ReadableStream<Uint8Array>({
          start(controller) {
            controller.close();
          }
        })
      });

      (global as any).DecompressionStream = class {};

      const parsedPayload = await DecompressGzipJson(blob, { forceStreaming: true });
      expect(parsedPayload).to.deep.equal(payload);
    });
  });

  describe(`error handling`, () => {
    it(`should reject invalid gzip data`, async () => {
      const invalidBlob = new Blob([`invalid data`], { type: `application/json` });

      try {
        await DecompressGzipJson(invalidBlob);
        expect.fail(`Expected decompression to fail`);
      } catch (error) {
        expect(error).to.be.an(`error`);
        expect((error as Error).message).to.not.include(`Expected decompression to fail`);
      }
    });

    it(`should reject invalid gzip data via streaming path`, async () => {
      const invalidBlob = new Blob([`invalid data`], { type: `application/json` });

      try {
        await DecompressGzipJson(invalidBlob, { forceStreaming: true });
        expect.fail(`Expected decompression to fail`);
      } catch (error) {
        expect(error).to.be.an(`error`);
        expect((error as Error).message).to.not.include(`Expected decompression to fail`);
      }
    });

    it(`should reject gzipped payload missing testResults via simple path`, async () => {
      const blob = makeGzipBlob({ error: `forbidden` });

      try {
        await DecompressGzipJson(blob);
        expect.fail(`Expected schema validation to fail`);
      } catch (error) {
        expect(error).to.be.an(`error`);
        expect((error as Error).message).to.include(`Payload is missing testResults array`);
      }
    });

    it(`should reject gzipped payload with non-array testResults`, async () => {
      const blob = makeGzipBlob({ testResults: {} });

      try {
        await DecompressGzipJson(blob);
        expect.fail(`Expected schema validation to fail`);
      } catch (error) {
        expect(error).to.be.an(`error`);
        expect((error as Error).message).to.include(`Payload is missing testResults array`);
      }
    });

    it(`should reject gzipped payload missing testResults via streaming path`, async () => {
      const blob = makeGzipBlob({ error: `forbidden` });

      try {
        await DecompressGzipJson(blob, { forceStreaming: true });
        expect.fail(`Expected schema validation to fail`);
      } catch (error) {
        expect(error).to.be.an(`error`);
        expect((error as Error).message).to.include(`Payload is missing testResults array`);
      }
    });

    it(`should reject gzipped payload with non-array testResults via streaming path`, async () => {
      const blob = makeGzipBlob({ testResults: {} });

      try {
        await DecompressGzipJson(blob, { forceStreaming: true });
        expect.fail(`Expected schema validation to fail`);
      } catch (error) {
        expect(error).to.be.an(`error`);
        expect((error as Error).message).to.include(`Payload is missing testResults array`);
      }
    });

    it(`should reject gzipped payload with string testResults via streaming path`, async () => {
      const blob = makeGzipBlob({ testResults: `not an array` });

      try {
        await DecompressGzipJson(blob, { forceStreaming: true });
        expect.fail(`Expected schema validation to fail`);
      } catch (error) {
        expect(error).to.be.an(`error`);
        expect((error as Error).message).to.include(`Payload is missing testResults array`);
      }
    });
  });

  describe(`IsGzipBlob`, () => {
    it(`should detect gzip magic header`, async () => {
      const gzipBlob = makeGzipBlob({ testResults: [] });
      const plainBlob = new Blob([JSON.stringify({ testResults: [] })], { type: `application/json` });

      expect(await IsGzipBlob(gzipBlob)).to.equal(true);
      expect(await IsGzipBlob(plainBlob)).to.equal(false);
    });

    it(`should return false for blobs smaller than 2 bytes`, async () => {
      const tinyBlob = new Blob([`x`]);
      expect(await IsGzipBlob(tinyBlob)).to.equal(false);
    });
  });

  describe(`STREAMING_THRESHOLD_BYTES`, () => {
    it(`should be 10 MB`, () => {
      expect(STREAMING_THRESHOLD_BYTES).to.equal(10 * 1024 * 1024);
    });
  });

});
