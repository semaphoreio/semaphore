## Releases

### Creating a new minor release

1. Create release branch:

```bash
git checkout main
git pull origin main
git checkout -b release/v0.4.x
git push origin release/v0.4.x
```

2. Start ephemeral environment and run E2Es on it.
3. If E2Es are green, tag the release branch:

```bash
git checkout release/v0.4.x
git pull origin release/v0.4.x
git tag v0.4.0
git push origin v0.4.0
```

If the E2Es are not green, you need to fix them before proceeding.

4. Use the "Generate Helm chart" and "Release" promotions to create a new Helm chart and push it to a release in GitHub.
5. After the release is published, generate the changelog for it and add it in the release description. Use [git-cliff](https://github.com/orhun/git-cliff), using the previous release tag and this one:

```bash
git-cliff v0.3.0..v0.4.0
```

A few notes here:
- You will need to review the changes and make sure they are appropriate. We are not enforcing conventional commits yet, so some changes might not be included.
- If there are breaking changes, include a section at the beginning of the changelog detailing the breaking changes.
- If the upgrade process requires any attention, include a section for it as well.
