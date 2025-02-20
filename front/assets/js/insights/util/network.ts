import $ from 'jquery';

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { v4 as uuid } from 'uuid';

/**
 * Returns an object containing the headers for a request.
 * 
 * @param {string} contentType - The content type of the request.
 * @returns {object} An object containing the headers for the request.
 */
export const Headers = (contentType = `application/x-www-form-urlencoded`) => {
  return {
    'Content-Type': contentType,
    'Idempotency-Key': uuid(),
    'X-CSRF-Token': $(`meta[name='csrf-token']`).attr(`content`)
  };
};