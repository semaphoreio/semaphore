
import { inflate } from 'pako';

export const DecompressGzip = (blob: Blob) => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = function(event) {
      try {
        // Assuming the loaded data is gzipped
        const decompressed = inflate(new Uint8Array(event.target.result as ArrayBufferLike), { to: `string` });
        resolve(decompressed);
      } catch (error) {
        // If decompression fails, reject the promise
        reject(error);
      }
    };
    reader.onerror = () => reject(reader.error);
    reader.readAsArrayBuffer(blob);
  });
};
