# Deploy claude-kiss.com

The site is a static Cloudflare Pages project. It has no server runtime, no analytics, and
no external fonts or scripts.

## Build locally

```sh
./website/build.sh
```

This generates:

```text
website/public/install.sh
website/public/releases/v0.6.0/claude-kiss.tar.gz
website/public/releases/v0.6.0/claude-kiss.tar.gz.sha256
website/public/releases/v0.6.0/release.json
```

## Deploy from this checkout

Authenticate Wrangler once:

```sh
wrangler login
```

If your authentication has access to multiple Cloudflare accounts, select the account that
contains the domain when prompted.

Create the Pages project if needed:

```sh
wrangler pages project create claude-kiss --production-branch main
```

Build and deploy:

```sh
./website/build.sh
wrangler pages deploy website/public --project-name claude-kiss --branch main
```

## Connect the domain

In Cloudflare Pages:

1. Open the `claude-kiss` project.
2. Go to **Custom domains**.
3. Add `claude-kiss.com`.
4. Add `www.claude-kiss.com` if desired, then redirect it to the apex domain.

The domain must remain in the same Cloudflare account as the Pages project.

## Git-connected deployments

Cloudflare Pages can also build directly from GitHub:

- production branch: `main`
- build command: `./website/build.sh`
- output directory: `website/public`

The static source files are committed, while `install.sh` and immutable release artifacts
are generated during the build.

## Release checklist

1. Update `VERSION`, the wrapper version, installer default version, and website metadata.
2. Run `./tests/test.sh`.
3. Run `./website/build.sh`.
4. Tag the exact commit:

   ```sh
   git tag "v$(cat VERSION)"
   git push origin main "v$(cat VERSION)"
   ```

5. Create the GitHub release from that tag.
6. Deploy the website so `https://claude-kiss.com/install.sh` serves the matching build.
