# Verifying an Emphere EOL-PHP backport artifact

Every artifact is a `.tar.gz` of an installed PHP tree, shipped with a SHA-256,
a cosign signature, and a CycloneDX SBOM. Verify all three before you deploy.

Replace `<ART>` with the artifact name, e.g.
`php-8.1.34-emphere-backport-linux-amd64.tar.gz`.

## 1. Checksum

```bash
sha256sum -c <ART>.sha256
```

## 2. Signature (cosign)

The artifacts are signed with Emphere's `packages-signing` key — the same key
that signs our managed images. Fetch the public key and verify:

```bash
curl -fsSL https://app.emphere.io/cosign.pub -o emphere-cosign.pub
cosign verify-blob --key emphere-cosign.pub --signature <ART>.sig <ART>
```

Expect `Verified OK`.

## 3. SBOM

`<ART>.cyclonedx.json` is a CycloneDX v1.6 SBOM of the built tree. Load it into
any SBOM/VEX tool, or read it directly.

## 4. Reproduce it yourself (optional, recommended)

You do not have to trust the binary. Rebuild from the same inputs and diff:

```bash
git clone https://github.com/emphereio/php-eol-backports
cd php-eol-backports
PLATFORM=linux/amd64 ./build.sh 8.1
```

The build fetches the official php.net release tarball, verifies its SHA-256,
and applies the unmodified upstream security commit from `patches/`.

## What's inside the tree

`php/emphere/` carries the provenance of each build:
- `security.patch` — the exact upstream commit applied
- `BUILD_INFO` — source version, patch hash, build time, builder image
- `build.log`, `test.log`, `test-summary.txt`, `TEST_NOTES.md`
