import { RequestStatus } from "./request_status";
import type * as stores from "../stores";

export class Request {
  url: URL;
  status: RequestStatus;

  constructor(url: string) {
    this.url = new URL(url, location.origin);
    this.status = RequestStatus.Zero;
  }

  get params(): URLSearchParams {
    return this.url.searchParams;
  }

  setParam(name: string, value: string): Request {
    this.params.set(name, value);
    return this;
  }

  setStatus(status: RequestStatus): Request {
    this.status = status;
    return this;
  }

  commit(): Request {
    this.status = RequestStatus.Fetch;
    return this;
  }

  reset(): Request {
    this.status = RequestStatus.Zero;
    this.url = new URL(this.url.toString(), location.origin);
    return this;
  }

  fetch(dispatcher: (a: stores.Request.Action) => void): Promise<any> {
    dispatcher({ type: `SET_STATUS`, value: RequestStatus.Loading });

    return fetch(this.url, { credentials: `same-origin` })
      .then((response) => {
        dispatcher({ type: `SET_STATUS`, value: RequestStatus.Success });
        return response.json();
      })
      .catch(() => {
        dispatcher({ type: `SET_STATUS`, value: RequestStatus.Error });
      });
  }
}
