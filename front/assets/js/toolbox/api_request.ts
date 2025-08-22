import { v4 as uuid } from "uuid";

interface RequestOptions {
  method: `GET` | `POST` | `PUT` | `DELETE`;
  headers?: HeadersInit;
  body?: any;
  transform?: (data: any) => any;
}

export interface ApiResponse<T> {
  data: T | null;
  error: string | null;
  status: number | null;
}

const getHeaders = () => {
  return {
    "Content-Type": `application/json`,
    "Idempotency-Key": uuid(),
    "X-CSRF-Token":
      document
        .querySelector(`meta[name='csrf-token']`)
        ?.getAttribute(`content`) || ``,
  };
};

async function apiRequest<T>(
  url: string | URL,
  options: RequestOptions
): Promise<ApiResponse<T>> {
  const defaultHeaders = getHeaders();

  try {
    const response = await fetch(url, {
      method: options.method,
      headers: {
        ...defaultHeaders,
        ...(options.headers || {}),
      },
      body: options.body ? JSON.stringify(options.body) : undefined,
      credentials: `same-origin`,
    });

    let transformFun = (data: any) => data as T;
    if (options.transform) {
      transformFun = options.transform;
    }

    // Check if response has content
    const contentLength = response.headers.get(`content-length`);
    const hasContent = contentLength !== `0` && response.status !== 204;
    
    let json: any = null;
    let data: T | null = null;
    
    if (hasContent) {
      try {
        json = await response.json();
        data = transformFun(json);
      } catch (e) {
        // If JSON parsing fails, treat as empty response
        json = null;
        data = null;
      }
    }

    if (!response.ok) {
      return {
        data: data,
        error: json?.message || `Something went wrong`,
        status: response.status,
      };
    }

    return { data, error: null, status: response.status };
  } catch (error) {
    return {
      data: null,
      error: error.message || `Network error`,
      status: 503,
    };
  }
}

export const get = <T>(
  url: string | URL,
  body?: any,
  headers?: HeadersInit,
  transform?: (data: any) => T
) => apiRequest<T>(url, { method: `GET`, headers, transform });

export const post = <T>(
  url: string | URL,
  body?: any,
  headers?: HeadersInit,
  transform?: (data: any) => T
) => apiRequest<T>(url, { method: `POST`, body, headers, transform });

export const put = <T>(
  url: string | URL,
  body?: any,
  headers?: HeadersInit,
  transform?: (data: any) => T
) => apiRequest<T>(url, { method: `PUT`, body, headers, transform });

export const del = <T>(
  url: string | URL,
  body?: any,
  headers?: HeadersInit,
  transform?: (data: any) => T
) => apiRequest<T>(url, { method: `DELETE`, headers, transform });

export type Method = `get` | `post` | `put` | `delete`;

export const callApi = async <T>(
  method: Method,
  url: string,
  {
    body,
    headers,
    transform,
  }: { body?: any, headers?: HeadersInit, transform?: (data: any) => T, }
): Promise<ApiResponse<T>> => {
  switch (method) {
    case `post`:
      return post(url, body, headers, transform);
    case `put`:
      return put(url, body, headers, transform);
    case `delete`:
      return del(url, body, headers, transform);
    default:
    case `get`:
      return get(url, body, headers, transform);
  }
};

export class Url<T> {
  path: string;
  method: Method;

  call(
    props: {
      body?: any;
      headers?: HeadersInit;
      transform?: (data: any) => T;
    } = {}
  ): Promise<ApiResponse<T>> {
    return callApi<T>(this.method, this.path, {
      body: props.body,
      headers: props.headers,
      transform: props.transform,
    });
  }

  constructor(method: string, path: string) {
    this.method = method as Method;
    this.path = path;
  }

  static fromJSON<T>(json: any): Url<T> {
    const url = new Url<T>(`get`, ``);

    url.method = json.method;
    url.path = json.path;

    return url;
  }
}
