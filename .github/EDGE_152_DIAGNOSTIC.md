# Controlled Edge 152 diagnostic

This temporary branch isolates three fresh Ubuntu 24.04 runners at the exact
Microsoft Edge and Microsoft EdgeDriver version `152.0.4191.53`. Its base is
`0f8db35bd756803f769797886b295f32bac6b211` on `product/main`.

The branch-only workflow is named **Edge 152 diagnostic (controlled samples)**.
Only pushes to `codex/edge-152-diagnostic` trigger it. The sample matrix is
`[1, 2, 3]`, with `fail-fast: false`. Every sample runs the unchanged real Edge
adapter, SDK window positioning and 1440 x 900 outer-window sizing, and the
original complete Catalog P1/P2/P3 journey. There are no retries, test exclusions,
browser-policy changes, relaxed deadlines, or alternate success conditions.
This is diagnostic evidence; it is not a replacement production CI gate.

## Exact official distributions

Both URLs returned HTTP 200 during the 2026-09-03 13:19 UTC preflight.

| Distribution | Official URL | SHA-256 |
| --- | --- | --- |
| Browser Debian package, amd64, `152.0.4191.53-1` | <https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/microsoft-edge-stable_152.0.4191.53-1_amd64.deb> | `b3322445fbe6ce1e0bcff84ebbe0edea365e0eaf498b1ef6136dda52dea6e3a7` |
| Linux64 driver ZIP, `152.0.4191.53` | <https://msedgedriver.microsoft.com/152.0.4191.53/edgedriver_linux64.zip> | `58deca365a57cdf9fb2853da0fa3953d1bb1d90963943eab2172dea4cf5cb61f` |

The browser checksum is published in Microsoft's package index at
<https://packages.microsoft.com/repos/edge/dists/stable/main/binary-amd64/Packages.gz>:

```text
Package: microsoft-edge-stable
Version: 152.0.4191.53-1
Architecture: amd64
Size: 195720942
SHA256: b3322445fbe6ce1e0bcff84ebbe0edea365e0eaf498b1ef6136dda52dea6e3a7
Filename: pool/main/m/microsoft-edge-stable/microsoft-edge-stable_152.0.4191.53-1_amd64.deb
```

The driver checksum is an observed pin computed from the complete official
15,392,204-byte HTTPS download, rather than a separately published Microsoft
signature. Both full downloads are checked against their pins before use.
Package identity and the installed browser/driver versions must match exactly;
an unavailable version or checksum mismatch fails without substituting 151.
The installer only runs on disposable Linux amd64 CI runners.

Microsoft documents its package service and local Debian package installation at
<https://learn.microsoft.com/en-us/linux/packages>. Edge and driver matching and
official headless WebDriver use are documented at
<https://learn.microsoft.com/en-us/microsoft-edge/webdriver/>.

## Evidence

Each job uploads `edge-152-sample-1`, `edge-152-sample-2`, or
`edge-152-sample-3`, including:

- `distribution/distribution.json`: sample and commit identities, official source
  URLs, HTTP headers/status, download sizes/digests, exact installed versions.
- `distribution/package-install.log`: the local package installation result.
- `browser-identity.json`: the actual browser session's returned capabilities.
- `adapter.log`: original requests, window parameters/responses, status and time.
- `msedgedriver.log`: verbose driver, CDP, and browser startup logs.
- `journey.log`: original complete journey result.
- `diagnostics/`: actual URL/screenshot attempts with two-second total deadlines
  when an upstream session command fails with HTTP 500 or greater.

The branch is not intended to be merged into `product/main`. A successful sample
proves only that this exact version completed that run; three successes cannot
prove the earlier intermittent failure's cause or its permanent resolution.
