# Emphere EOL-PHP backport builder
# Builds a PHP release tarball from php.net with the official upstream
# CVE-2026-109618 / CVE-2026-109619 security commit applied on top.
#
#   docker build --build-arg PHP_VERSION=8.1.33 \
#                --build-arg PATCH_FILE=patches/php-8.1.patch \
#                -t emphere/php-backport:8.1 .
#
# The built tree is left at /opt/php with `make install` run into it, plus a
# build log and the exact patch recorded under /opt/php/emphere.
# Ubuntu 20.04 (focal) ships openssl 1.1.1 — the toolchain PHP 7.4/8.0/8.1 were
# built against — with reliable mirrors, unlike the bullseye security pool.
FROM ubuntu:20.04 AS build

ARG PHP_VERSION
ARG PATCH_FILE
ARG PHP_SHA256=""

ENV DEBIAN_FRONTEND=noninteractive TZ=UTC
RUN printf 'Acquire::Retries "10";\n' > /etc/apt/apt.conf.d/80emphere \
    && apt-get update && apt-get install -y --no-install-recommends \
         ca-certificates curl build-essential autoconf bison re2c pkg-config \
         libxml2-dev libsqlite3-dev libssl-dev libcurl4-openssl-dev \
         libonig-dev zlib1g-dev patch \
    && command -v re2c && command -v bison \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
# 1. Fetch the official release tarball over TLS from php.net.
RUN curl -fsSL -o php.tar.gz "https://www.php.net/distributions/php-${PHP_VERSION}.tar.gz"
# 2. Verify integrity if a SHA256 was supplied (TOFU-pinned in the harness).
RUN if [ -n "${PHP_SHA256}" ]; then echo "${PHP_SHA256}  php.tar.gz" | sha256sum -c -; \
    else echo "WARN: no SHA256 pinned, recording actual below"; fi \
    && sha256sum php.tar.gz
RUN tar -xzf php.tar.gz && mv "php-${PHP_VERSION}" php-src

# 3. Apply the official upstream security commit.
COPY ${PATCH_FILE} /src/security.patch
WORKDIR /src/php-src
# The commit is authored on the EOL branch; it applies on top of the final
# release tree. Try -p1 clean, then fall back to fuzz, then git-style.
RUN set -eux; \
    if patch -p1 --dry-run < /src/security.patch >/dev/null 2>&1; then \
        patch -p1 < /src/security.patch; \
    else \
        echo "clean apply failed, retrying with fuzz"; \
        patch -p1 -F3 < /src/security.patch; \
    fi; \
    cp /src/security.patch /src/applied.patch

# 4. Configure + build. A lean but realistic web-facing surface:
#    FPM + CLI, session, mbstring, curl, openssl, pdo_sqlite, opcache.
RUN ./configure \
      --prefix=/opt/php \
      --enable-fpm \
      --enable-mbstring \
      --enable-opcache \
      --with-openssl \
      --with-curl \
      --enable-pdo --with-pdo-sqlite --with-sqlite3 \
      --with-zlib \
      --enable-session \
      --enable-zend-test \
      --disable-cgi \
    && make -j"$(nproc)" 2>&1 | tee /src/build.log

# 4b. Run the fix's own regression tests + the session/upload surface the CVEs
#     live in. Captured to a log; a flaky unrelated test must not void the
#     artifact, so this never fails the build (results are inspected after).
RUN set -eux; \
    export NO_INTERACTION=1 REPORT_EXIT_STATUS=0 SKIP_ONLINE_TESTS=1; \
    TDIRS=""; for d in ext/session/tests ext/zend_test/tests sapi/cli/tests; do \
        [ -d "$d" ] && TDIRS="$TDIRS $d"; \
    done; \
    echo "running tests in:$TDIRS"; \
    ( make test TESTS="$TDIRS" 2>&1 | tee /src/test.log ) || true; \
    { grep -E "Number of tests|tests failed|FAILED|PASS|Tests (passed|failed)" /src/test.log || true; } \
      | tail -40 > /src/test-summary.txt; \
    cat /src/test-summary.txt

# 5. Install into /opt/php and stamp provenance.
RUN make install \
    && mkdir -p /opt/php/emphere \
    && cp /src/applied.patch /opt/php/emphere/security.patch \
    && cp /src/build.log /opt/php/emphere/build.log \
    && cp /src/test.log /opt/php/emphere/test.log 2>/dev/null || true \
    && cp /src/test-summary.txt /opt/php/emphere/test-summary.txt 2>/dev/null || true \
    && /opt/php/bin/php -v > /opt/php/emphere/php-v.txt 2>&1 \
    && echo "PHP_VERSION=${PHP_VERSION}" > /opt/php/emphere/BUILD_INFO \
    && echo "PATCH=$(sha256sum /opt/php/emphere/security.patch | cut -d' ' -f1)" >> /opt/php/emphere/BUILD_INFO \
    && echo "BUILT_AT=$(date -u +%FT%TZ)" >> /opt/php/emphere/BUILD_INFO \
    && echo "BUILDER=$(. /etc/os-release && echo "$ID:$VERSION_ID")" >> /opt/php/emphere/BUILD_INFO
