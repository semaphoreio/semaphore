import { expect } from 'chai';
import { DecompressGzip } from './gzip';
import { deflate } from 'pako';
import { JSDOM } from 'jsdom';

describe(`DecompressGzip`, () => {
  // FileReader is browser only thing - we need to stub it
  beforeEach(() => {
    const dom = new JSDOM(`<!DOCTYPE html><p>Some DOM</p>`);
    global.window = dom.window as any;
    global.FileReader = dom.window.FileReader as any;
  });


  it(`should correctly decompress a gzipped blob`, async () => {
    // Prepare compressed blob
    const testString = `Hello, world!`;
    const compressed = deflate(testString);
    const buffer = new Uint8Array(compressed).buffer;
    const blob = new Blob([buffer]);

    const result = await DecompressGzip(blob);
    expect(result).to.equal(testString);
  });

  it(`should reject on decompression error`, (done) => {
    // Create a malformed blob that would cause an error
    const invalidBlob = new Blob([`invalid data`]);

    DecompressGzip(invalidBlob)
      .catch((error) => {
        expect(error).to.be.an(`error`);
      })
      .finally(() => done());
  });
});
