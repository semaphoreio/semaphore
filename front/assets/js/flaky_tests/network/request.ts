import $ from "jquery";

import { v4 as uuid } from 'uuid';
import { RequestStatus } from "../types";


export class FetchResponse<T> {
  body: T;
  headers: Headers;
  status: RequestStatus;
}

export async function FetchData<T>(url: URL): Promise<FetchResponse<T>> {
  const res = await fetch(url, { credentials: `same-origin` });
  return readResponse<T>(res);
}

export class RemoveResponse {
  headers: Headers;
  status: RequestStatus;
}

export async function RemoveData(url: URL): Promise<RemoveResponse> {
  const res = await fetch(url, {
    method: `DELETE`,
    credentials: `same-origin`,
    headers:  Headers()
  });
  let status = RequestStatus.Success;
  const response = new RemoveResponse();
  try {
    response.headers = res.headers;
  } catch {
    status = RequestStatus.Error;
  }

  response.status = status;
  return response;
}

export async function PostData<T>(url: URL, body: any): Promise<FetchResponse<T>> {
  const res = await fetch(url, {
    method: `POST`,
    credentials: `same-origin`,
    body: JSON.stringify(body),
    headers: Headers( `application/json`)
  });
  return readResponse<T>(res);
}

export async function PutData<T>(url: URL, body: any): Promise<FetchResponse<T>> {
  const res = await fetch(url, {
    method: `PUT`,
    credentials: `same-origin`,
    body: JSON.stringify(body),
    headers: Headers(`application/json`)
  });
  return readResponse<T>(res);
}

async function readResponse<T>(res: Response): Promise<FetchResponse<T>> {
  let status = RequestStatus.Success;
  const response = new FetchResponse<T>();
  try {
    response.body = await res.json() as T;
    response.headers = res.headers;
  } catch {
    status = RequestStatus.Error;
  }

  response.status = status;
  return response;
}


export const Headers = (contentType = `application/x-www-form-urlencoded`) => {
  return {
    'Content-Type': contentType,
    'Idempotency-Key': uuid(),
    'X-CSRF-Token': $(`meta[name='csrf-token']`).attr(`content`)
  };
};
