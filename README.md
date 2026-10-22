# EOL-PHP backport: CVE-2026-109618 / CVE-2026-109619 (php2shell)

Reproducible builds of end-of-life PHP (7.4, 8.0, 8.1) with the **official upstream
security commit** for the php2shell RCEs applied on top. PHP shipped releases only
for 8.2+. These branches got a source backport and nothing else. This harness turns
that source backport into a built, tested, checksummed artifact.

## What it does

For each branch, inside a pinned `debian:11-slim` builder (openssl 1.1, the toolchain
these PHP versions shipped against):

1. Downloads the official release tarball from `php.net` over TLS.
2. Verifies it against php.net's published **SHA-256**.
3. Applies the **exact upstream security commit**, unmodified (`patches/php-<branch>.patch`).
4. Builds a realistic web-facing surface: FPM + CLI, session, mbstring, curl, openssl,
   opcache, pdo_sqlite.
5. Runs the regression tests that ship *inside the fix* plus the session / upload
   surface the CVEs live in (`ext/session/tests`, `ext/zend_test/tests`, `sapi/cli/tests`).
6. Stamps provenance next to the binary and emits a `.tar.gz` + `.sha256`.

## Provenance of the patches

| Branch | Base release | SHA-256 (php.net) | Upstream commit |
|--------|--------------|-------------------|-----------------|
| 7.4 | 7.4.33 | `5a2337…f463e` | `712e60f9ed` |
| 8.0 | 8.0.30 | `449d20…4c80c` | `82f8f31b16` |
| 8.1 | 8.1.34 | `3c5b06…c4bfa` | `1d7dec178a` |

Each `patches/php-<branch>.patch` is the unmodified `.patch` of the named `php/php-src`
commit ("Avoid state corruption via bailout", Arnaud Le Blanc). Re-fetch and diff:

```bash
curl -L https://github.com/php/php-src/commit/1d7dec178a.patch | diff - patches/php-8.1.patch
```

## Usage

```bash
./build.sh 8.1            # one branch
./build.sh all            # 7.4, 8.0, 8.1
PLATFORM=linux/amd64 ./build.sh 8.1   # x86-64 artifact (emulated on Apple Silicon, slow)
```

Artifacts land in `out/`:
- `php-<ver>-emphere-backport-linux-<arch>.tar.gz` — installed tree under `php/`
- `…​.tar.gz.sha256` — checksum
- inside the tree, `php/emphere/`: `security.patch`, `build.log`, `test-summary.txt`, `BUILD_INFO`

## Signing + SBOM (release step)

Not run by `build.sh`. Per artifact:

```bash
cosign sign-blob --yes out/php-8.1.34-emphere-backport-linux-arm64.tar.gz \
  > out/php-8.1.34-...tar.gz.sig
syft out/php-8.1.34-emphere-backport-linux-arm64/php -o cyclonedx-json \
  > out/php-8.1.34-...cyclonedx.json
```

## Scope and honesty

- This is the **official fix**, built and tested. It is **not** an Emphere-authored patch.
- It is **not yet** verified against a working exploit (vulnerable fires / fixed blocked /
  revert returns). That is the next step. Until then: "built and tested", not "proven".
- Below 7.4 there is no official backport. Take it off the public internet.
