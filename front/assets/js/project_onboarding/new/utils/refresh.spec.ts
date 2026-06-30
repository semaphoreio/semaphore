import { expect } from "chai";
import { describe, it } from "mocha";
import {
  decideRefreshOutcome,
  formatCooldown,
  cooldownScope,
  isTargetedRefreshDisabled,
  isOrgRefreshLocked,
} from "./refresh";

describe(`formatCooldown`, () => {
  it(`keeps values of 60s or less in seconds`, () => {
    expect(formatCooldown(45)).to.eq(`45s`);
    expect(formatCooldown(60)).to.eq(`60s`);
  });

  it(`shows rounded minutes above a minute`, () => {
    expect(formatCooldown(61)).to.eq(`1 minute`);
    expect(formatCooldown(90)).to.eq(`2 minutes`);
    expect(formatCooldown(328)).to.eq(`5 minutes`);
    expect(formatCooldown(600)).to.eq(`10 minutes`);
  });
});

describe(`decideRefreshOutcome`, () => {
  it(`rate-limits a 429 with the server-provided retry_after as the cooldown`, () => {
    const out = decideRefreshOutcome(
      429,
      { state: `rate_limited`, retry_after: 42, message: `Try again soon.` },
      undefined,
      `octo/repo`,
      60
    );

    expect(out.kind).to.eq(`rate_limited`);
    expect(out).to.have.property(`cooldown`, 42);
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

describe(`cooldownScope`, () => {
  it(`scopes a slugged refresh as targeted`, () => {
    expect(cooldownScope(`octo/repo`)).to.eq(`targeted`);
  });

  it(`scopes an absent or empty slug as org`, () => {
    expect(cooldownScope(undefined)).to.eq(`org`);
    expect(cooldownScope(``)).to.eq(`org`);
  });
});

describe(`refresh control gating`, () => {
  it(`a targeted cooldown blocks the targeted control but leaves the org control enabled`, () => {
    // The bug: a targeted 429 used to set a shared cooldown that disabled the org
    // control, though the backend throttles the two independently.
    expect(isTargetedRefreshDisabled(`octo/repo`, false, 45)).to.eq(true);
    expect(isOrgRefreshLocked(false, 0)).to.eq(false);
  });

  it(`an org cooldown locks the org control but leaves targeted enabled`, () => {
    expect(isOrgRefreshLocked(false, 300)).to.eq(true);
    expect(isTargetedRefreshDisabled(`octo/repo`, false, 0)).to.eq(false);
  });

  it(`an in-flight refresh locks both controls`, () => {
    expect(isOrgRefreshLocked(true, 0)).to.eq(true);
    expect(isTargetedRefreshDisabled(`octo/repo`, true, 0)).to.eq(true);
  });

  it(`an invalid manual slug disables the targeted control regardless of cooldown`, () => {
    expect(isTargetedRefreshDisabled(null, false, 0)).to.eq(true);
  });
});
