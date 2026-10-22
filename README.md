# PHP EOL Security Backports — CVE-2026-109618 & CVE-2026-109619 (php2shell)

**Signed, tested, reproducible builds of end-of-life PHP (7.4, 8.0, 8.1) with the
official upstream security fix for the two critical "php2shell" remote code
execution vulnerabilities applied.**

If you are searching for a **PHP 7.4 security patch**, a **PHP 8.0 security
build**, or a **PHP 8.1 backport** for **CVE-2026-109618** / **CVE-2026-109619**,
this repository builds and publishes exactly that — as downloadable binaries you
can verify, and as a one-command build you can reproduce yourself.

Maintained by [Emphere](https://emphere.io). Questions, or need a version that
isn't here? **[Book a call](https://calendly.com/ak-emphere/emphere-container-security-strategy-call)**
or **[contact@emphere.com](mailto:contact@emphere.com)** — see
[Need help?](#need-help) below.

---

## The short version

On 21 October 2026 the PHP project shipped an out-of-band security release for
two critical, unauthenticated remote-code-execution flaws (CVSS v4.0 **9.2**),
collectively nicknamed **php2shell**:

- **CVE-2026-109618** — state corruption during out-of-memory handling.
- **CVE-2026-109619** — stale request state reused across requests (use-after-free).

Official fixed releases exist only for **PHP 8.2 and newer** (8.2.35, 8.3.36,
8.4.27, 8.5.12). For end-of-life **7.4, 8.0, and 8.1**, the PHP security team
published a *source-only* backport — a patch you are expected to compile
yourself. PHP versions **below 7.4** receive no official fix at all.

This repo does the part the source backport leaves undone: it **builds, tests,
signs, and SBOMs** the EOL versions so you can deploy them instead of running a
compiler, or rebuild them yourself and diff.

## Downloads

Grab builds from the **[latest release](https://github.com/emphereio/php-eol-backports/releases/latest)**.
`linux/amd64`. Each version ships a `.tar.gz` plus a SHA-256, a cosign signature,
and a CycloneDX SBOM.

| PHP branch | Build | What it fixes | Download |
|------------|-------|---------------|----------|
| **7.4** | 7.4.33 | CVE-2026-109618, CVE-2026-109619 | [tar.gz](https://github.com/emphereio/php-eol-backports/releases/latest/download/php-7.4.33-emphere-backport-linux-amd64.tar.gz) · [sha256](https://github.com/emphereio/php-eol-backports/releases/latest/download/php-7.4.33-emphere-backport-linux-amd64.tar.gz.sha256) · [sig](https://github.com/emphereio/php-eol-backports/releases/latest/download/php-7.4.33-emphere-backport-linux-amd64.tar.gz.sig) · [sbom](https://github.com/emphereio/php-eol-backports/releases/latest/download/php-7.4.33-emphere-backport-linux-amd64.cyclonedx.json) |
| **8.0** | 8.0.30 | CVE-2026-109618, CVE-2026-109619 | [tar.gz](https://github.com/emphereio/php-eol-backports/releases/latest/download/php-8.0.30-emphere-backport-linux-amd64.tar.gz) · [sha256](https://github.com/emphereio/php-eol-backports/releases/latest/download/php-8.0.30-emphere-backport-linux-amd64.tar.gz.sha256) · [sig](https://github.com/emphereio/php-eol-backports/releases/latest/download/php-8.0.30-emphere-backport-linux-amd64.tar.gz.sig) · [sbom](https://github.com/emphereio/php-eol-backports/releases/latest/download/php-8.0.30-emphere-backport-linux-amd64.cyclonedx.json) |
| **8.1** | 8.1.34 | CVE-2026-109618, CVE-2026-109619 | [tar.gz](https://github.com/emphereio/php-eol-backports/releases/latest/download/php-8.1.34-emphere-backport-linux-amd64.tar.gz) · [sha256](https://github.com/emphereio/php-eol-backports/releases/latest/download/php-8.1.34-emphere-backport-linux-amd64.tar.gz.sha256) · [sig](https://github.com/emphereio/php-eol-backports/releases/latest/download/php-8.1.34-emphere-backport-linux-amd64.tar.gz.sig) · [sbom](https://github.com/emphereio/php-eol-backports/releases/latest/download/php-8.1.34-emphere-backport-linux-amd64.cyclonedx.json) |

Full writeup: **https://emphere.webflow.io/blogs/php2shell-eol-php-backport**

## How each build is made

Inside a pinned `ubuntu:20.04` builder (openssl 1.1.1 — the toolchain these PHP
versions shipped against):

1. Downloads the official release tarball from `php.net` over TLS.
2. Verifies it against php.net's published **SHA-256**.
3. Applies the **exact upstream security commit**, unmodified (`patches/php-<branch>.patch`).
4. Builds a realistic web-facing surface: FPM + CLI, session, mbstring, curl, openssl,
   opcache, pdo_sqlite.
5. Runs the regression tests that ship *inside the fix* plus the session / upload
   surface the CVEs live in.
6. Boots the built PHP and runs a **functional smoke**: session persistence across
   requests + a real multipart upload (received, moved, byte-exact).
7. Stamps provenance next to the binary and emits a `.tar.gz` + `.sha256`.

## Provenance of the patches

| Branch | Base release | SHA-256 (php.net) | Upstream commit |
|--------|--------------|-------------------|-----------------|
| 7.4 | 7.4.33 | `5a2337…f463e` | `712e60f9ed` |
| 8.0 | 8.0.30 | `449d20…4c80c` | `82f8f31b16` |
| 8.1 | 8.1.34 | `3c5b06…c4bfa` | `1d7dec178a` |

Each `patches/php-<branch>.patch` is the unmodified `.patch` of the named
`php/php-src` commit ("Avoid state corruption via bailout", Arnaud Le Blanc).
Re-fetch and diff:

```bash
curl -L https://github.com/php/php-src/commit/1d7dec178a.patch | diff - patches/php-8.1.patch
```

## Verify a download

```bash
# 1. Checksum
sha256sum -c <ART>.sha256

# 2. Signature — signed with Emphere's packages-signing key (same key as our managed images)
curl -fsSL https://app.emphere.io/cosign.pub -o emphere-cosign.pub
cosign verify-blob --key emphere-cosign.pub --signature <ART>.sig <ART>

# 3. SBOM: <ART>.cyclonedx.json is CycloneDX, load it into any SBOM/VEX tool
```

See [`VERIFY.md`](VERIFY.md) for detail.

## Build it yourself

You do not have to trust the binary. Rebuild from the same inputs and diff:

```bash
git clone https://github.com/emphereio/php-eol-backports
cd php-eol-backports
PLATFORM=linux/amd64 ./build.sh 8.1      # or 7.4 / 8.0 / all
```

## Important behavior change

The minimal EOL backport **disables PHP's `session.upload_progress` feature
entirely**, regardless of your `php.ini`. This is upstream's deliberate choice for
7.4–8.1: close the use-after-free by removing the feature path.

- **File uploads still work.** Regular multipart uploads are unaffected (verified
  by the smoke test on every build).
- **Upload *progress tracking* is off.** Code that reads
  `$_SESSION[...upload_progress...]` to drive a progress bar gets nothing. Nothing
  crashes; it is a feature, not a failure.

## FAQ

**Is there a patched build of PHP 8.1 / 8.0 / 7.4 for php2shell?**
Yes — this repo. See [Downloads](#downloads).

**What are CVE-2026-109618 and CVE-2026-109619?**
Two critical (CVSS 9.2) unauthenticated remote-code-execution flaws in PHP core,
affecting every SAPI that serves web requests (PHP-FPM, mod_php, php-cgi,
FrankenPHP, LiteSpeed). Disclosed and patched out-of-band on 21 October 2026.

**My PHP version is end-of-life. Did it get an official fix?**
Only 8.2+ got releases. 7.4/8.0/8.1 got a source-only backport (what this repo
builds). Below 7.4, nothing official exists.

**Are these the official fix, or your own patch?**
The official upstream fix, applied unmodified. Emphere did not author the security
logic — it is the PHP core team's. We built, tested, and signed it.

**Are these binaries "proven" against the exploit?**
No. The honest claim is **built and tested**, not "proven against a working
exploit." See [Scope](#scope--honesty).

**What if I'm on PHP below 7.4, a different architecture, or need help rolling
this out?**
[Reach out](#need-help). Take EOL PHP off the public internet in the meantime
(behind a WAF or VPN).

## Need help?

Running EOL PHP you can't easily upgrade, stuck on a version or architecture not
published here, or dealing with a broader supply-chain or CVE-remediation problem?

**[Book a call](https://calendly.com/ak-emphere/emphere-container-security-strategy-call)**,
email **[contact@emphere.com](mailto:contact@emphere.com)**, or open an issue. We
build and verify fixed versions of stuck software for a living — EOL runtimes,
other architectures, other packages, signed artifacts with provenance. Happy to
help, no charge for a conversation.

Emphere: [emphere.io](https://emphere.io) · verified remediation and supply-chain
security for cloud workloads.

## Scope & honesty

- This is the **official upstream fix**, built and tested. It is **not** an
  Emphere-authored patch.
- It is **not yet** verified against a working exploit (vulnerable fires / fixed
  blocked / revert returns). Until then: "built and tested," not "proven."
- `linux/amd64` today. Need another architecture? [Ask](#need-help).
- Below 7.4 there is no official backport. Take it off the public internet.

## License & credit

PHP and the security patches are the work of The PHP Group and the PHP core
development team, under the [PHP License v3.01](https://www.php.net/license/). See
[`NOTICE`](NOTICE). Emphere is not affiliated with or endorsed by The PHP Group.
