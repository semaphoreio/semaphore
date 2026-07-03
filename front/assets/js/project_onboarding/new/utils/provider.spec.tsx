import { expect } from "chai";
import { describe, it } from "mocha";
import { IntegrationType } from "../types/provider";
import { getProviderNameWithBadge } from "./provider";

describe(`provider badges`, () => {
  it(`marks github oauth token as personal token`, () => {
    const node = getProviderNameWithBadge(IntegrationType.GithubOauthToken) as any;
    const [, badge] = node.props.children;

    expect(node.props.children[0]).to.eq(`GitHub`);
    expect(badge.props.children.trim()).to.eq(`Personal Token`);
  });

  it(`keeps github app label without personal token badge`, () => {
    const node = getProviderNameWithBadge(IntegrationType.GithubApp) as any;

    expect(node.props.children).to.eq(`GitHub`);
  });
});
