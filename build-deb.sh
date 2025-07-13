#!/usr/bin/env bash
set -euo pipefail

# Environment variables
DEB_BRANCH="${DEB_BRANCH:-debian/${PG_VERSION}-1}"
BUILD_DIR="/tmp/pg_deb_build"
SRC_DIR="${BUILD_DIR}/src"
PATCH_DIR="${BUILD_DIR}/spock"
PKG_OUTPUT="/output"

export DEBIAN_FRONTEND=noninteractive

prepare() {
  echo "Installing build tools and dependencies..."
  sudo ln -fs /usr/share/zoneinfo/UTC /etc/localtime

  sudo apt-get update
  sudo apt-get install -y devscripts build-essential fakeroot git curl \
    ca-certificates debhelper dpkg-dev gnupg

  echo "Cloning PostgreSQL Debian packaging repo..."
  rm -rf "$SRC_DIR"
  git clone -b "$DEB_BRANCH" https://salsa.debian.org/postgresql/postgresql.git "$SRC_DIR"

  echo "Parsing Debian changelog for full version..."
  pkg_version=$(cd "$SRC_DIR" && dpkg-parsechangelog -c 1 -S 'Version')
  full_postgres_version=${pkg_version%%-*}
  export full_postgres_version
  echo "PostgreSQL full version: $full_postgres_version"

  (cd /tmp && git clone https://salsa.debian.org/postgresql/postgresql-common.git && cd postgresql-common/pgdg && chmod 755 apt.postgresql.org.sh && sudo YES=yes ./apt.postgresql.org.sh)  

  echo "Downloading source tarball..."
  curl -L "https://ftp.postgresql.org/pub/source/v${full_postgres_version}/postgresql-${full_postgres_version}.tar.bz2" \
    -o "${BUILD_DIR}/postgresql-${full_postgres_version}.tar.bz2"
  tar -C "$BUILD_DIR" -xjf "${BUILD_DIR}/postgresql-${full_postgres_version}.tar.bz2"

  echo "Moving Debian packaging into source directory..."
  mv "$SRC_DIR/debian" "$BUILD_DIR/postgresql-${full_postgres_version}/"

  echo "Cloning patch repo and copying patches..."
  git clone --depth=1 --branch "$SPOCK_BRANCH" "$PG_SPOCK_REPO" "$PATCH_DIR"
  cp "$PATCH_DIR"/patches/pg${PG_MAJOR_VERSION}*.diff "$BUILD_DIR/postgresql-${full_postgres_version}/debian/patches" || echo "No patches found."

  echo "Adding patch names to series file..."
  for patch in "$BUILD_DIR/postgresql-${full_postgres_version}/debian/patches"/pg${PG_MAJOR_VERSION}*.diff; do
    basename "$patch" >> "$BUILD_DIR/postgresql-${full_postgres_version}/debian/patches/series" || true
  done

  echo "Patching control and test files..."
  sed -i -e '/tzdata-legacy/d' "$BUILD_DIR/postgresql-${full_postgres_version}/debian/control" || true
  sed -i -e 's/tzdata.*/tzdata,/' "$BUILD_DIR/postgresql-${full_postgres_version}/debian/tests/control" || true
  sed -i 's/postgresql-common-dev/postgresql-common/' $BUILD_DIR/postgresql-${full_postgres_version}/debian/control
}

build() {
  echo "Installing build dependencies..."
  cd "$BUILD_DIR/postgresql-${full_postgres_version}"
  sudo apt-get update
  sudo apt install -y postgresql-common
  sudo apt-get build-dep -y .

  echo "Building Debian package..."
  DISTRO=$(lsb_release -cs)
  dch -D "$DISTRO" --force-distribution -v "${PG_VERSION}-1+${DISTRO}" "Rebuild PostgreSQL $PG_VERSION for $DISTRO"

  dpkg-buildpackage -us -uc -b
}

post_build() {
  echo "Copying .deb packages to output..."
  sudo mkdir -p "$PKG_OUTPUT"
  # Rename .ddeb files to .deb files
  pushd $BUILD_DIR
  for file in $(ls | grep ddeb); do
    mv "$file" "${file%.ddeb}.deb";
  done
  popd
  sudo cp "$BUILD_DIR"/*.deb "$PKG_OUTPUT" || echo "No .deb packages found."
}

