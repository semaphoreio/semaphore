import { expect } from "chai";
import { describe, it } from "mocha";
import { decideRefreshOutcome } from "./refresh";

describe(`decideRefreshOutcome`, () => {
  it(`rate-limits a 429 with the server-provided retry_after and message`, () => {
    const out = decideRefreshOutcome(
      429,
      { state: `rate_limited`, retry_after: 42, message: `Try again soon.` },
      undefined,
      `octo/repo`,
      60
    );

    expect(out.kind).to.eq(`rate_limited`);
    expect(out).to.have.property(`cooldown`, 42);
    expect(out).to.have.property(`message`, `Try again soon.`);
    expect(out.ok).to.eq(false);
  });

  it(`still starts the cooldown on a 429 with an empty body (falls back to default)`, () => {
    // Regression: the 429 check must run before the empty-body check, otherwise a
    // bodyless rate-limit response is swallowed as a generic error and the
    // cooldown never starts.
    const out = decideRefreshOutcome(429, null, undefined, undefined, 60);

    expect(out.kind).to.eq(`rate_limited`);
    expect(out).to.have.property(`cooldown`, 60);
    expect(out.ok).to.eq(false);
  });

  it(`treats a full refresh "started" as starting the cooldown`, () => {
    const out = decideRefreshOutcome(200, { state: `started` }, undefined, undefined, 60);

    expect(out.kind).to.eq(`started`);
    expect(out).to.have.property(`startCooldown`, true);
    expect(out.ok).to.eq(true);
  });

  it(`treats a targeted "started" as not starting the cooldown`, () => {
    const out = decideRefreshOutcome(200, { state: `started` }, undefined, `octo/repo`, 60);

    expect(out.kind).to.eq(`started`);
    expect(out).to.have.property(`startCooldown`, false);
  });

  it(`treats "already_running" like "started"`, () => {
    const out = decideRefreshOutcome(200, { state: `already_running` }, undefined, undefined, 60);

    expect(out.kind).to.eq(`started`);
  });

  it(`reloads immediately on a targeted "done"`, () => {
    const out = decideRefreshOutcome(200, { state: `done` }, undefined, `octo/repo`, 60);

    expect(out.kind).to.eq(`done`);
    expect(out).to.have.property(`reloadNow`, true);
    expect(out.ok).to.eq(true);
  });

  it(`does not reload on a full "done"`, () => {
    const out = decideRefreshOutcome(200, { state: `done` }, undefined, undefined, 60);

    expect(out.kind).to.eq(`done`);
    expect(out).to.have.property(`reloadNow`, false);
  });

  it(`maps a business failure to an error with the server message`, () => {
    const out = decideRefreshOutcome(
      422,
      { state: `failed`, message: `The GitHub App has no access to octo/repo.` },
      undefined,
      `octo/repo`,
      60
    );

    expect(out.kind).to.eq(`error`);
    expect(out).to.have.property(`message`, `The GitHub App has no access to octo/repo.`);
    expect(out.ok).to.eq(false);
  });

  it(`falls back to the transport error when an unknown state carries no message`, () => {
    const out = decideRefreshOutcome(200, { state: `mystery` }, `boom`, undefined, 60);

    expect(out.kind).to.eq(`error`);
    expect(out).to.have.property(`message`, `boom`);
  });

  it(`reports the transport error when there is no body and it is not a 429`, () => {
    const out = decideRefreshOutcome(503, null, `Service unavailable`, undefined, 60);

    expect(out.kind).to.eq(`error`);
    expect(out).to.have.property(`message`, `Service unavailable`);
  });

  it(`uses a default message when there is neither body nor error`, () => {
    const out = decideRefreshOutcome(500, null, undefined, undefined, 60);

    expect(out.kind).to.eq(`error`);
    expect(out).to.have.property(`message`, `Could not refresh repositories.`);
  });
});
