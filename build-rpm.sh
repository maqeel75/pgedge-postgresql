#!/bin/bash
set -euo pipefail

RHEL="$(rpm --eval %rhel)"

prepare() {
  echo "Installing required packages..."
  dnf install -y rpm-build rpmdevtools yum-utils tar wget git

  echo "📦 Enabling additional repositories..."
  if [ "$RHEL" = "8" ]; then
    dnf install -y epel-release
    dnf config-manager --set-enabled powertools
  else
    dnf config-manager --set-enabled crb
  fi

  echo "Setting up RPM build environment..."
  rpmdev-setuptree

  echo "Cloning PostgreSQL pgrpms repo..."
  rm -rf /tmp/pgrpms
  git clone https://git.postgresql.org/git/pgrpms.git /tmp/pgrpms

  echo "Copying packaging files..."
  cp /tmp/pgrpms/rpm/redhat/${PG_MAJOR_VERSION}/postgresql-${PG_MAJOR_VERSION}/EL-${RHEL}/postgresql-${PG_MAJOR_VERSION}* ~/rpmbuild/SOURCES/
  cp /tmp/pgrpms/rpm/redhat/${PG_MAJOR_VERSION}/postgresql-${PG_MAJOR_VERSION}/EL-${RHEL}/postgresql-${PG_MAJOR_VERSION}.spec ~/rpmbuild/SPECS/

  echo "Applying postgresql spec patch ..."
  if [ -f "rpm/patches/postgresql-${PG_MAJOR_VERSION}.spec.patch" ]; then
    patch -d ~/rpmbuild/SPECS -p0 < "/rpm/patches/postgresql-${PG_MAJOR_VERSION}.spec.patch"
    sed -i 's|%{sname}%{pgmajorversion}|pgedge-%{sname}%{pgmajorversion}|g' ~/rpmbuild/SPECS/postgresql-${PG_MAJOR_VERSION}.spec
    sed -i 's|PGDG||g' ~/rpmbuild/SPECS/postgresql-${PG_MAJOR_VERSION}.spec
  else
    echo "Warning: No patch file found for spec. Skipping patch step."
  fi

  echo "Downloading official source tarball and docs..."
  wget https://download.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.bz2 -O ~/rpmbuild/SOURCES/postgresql-${PG_VERSION}.tar.bz2
  wget https://www.postgresql.org/files/documentation/pdf/${PG_MAJOR_VERSION}/postgresql-${PG_MAJOR_VERSION}-A4.pdf -O ~/rpmbuild/SOURCES/postgresql-${PG_MAJOR_VERSION}-A4.pdf

  echo "Fetching Spock diff patches..."
  git clone --depth=1 --branch "$SPOCK_BRANCH" "$PG_SPOCK_REPO" /tmp/spock
  cp /tmp/spock/patches/pg${PG_MAJOR_VERSION}*.diff ~/rpmbuild/SOURCES/ || echo "No diff patches found for Spock"

  echo "🔧 Installing RPM build dependencies..."
  dnf builddep -y ~/rpmbuild/SPECS/postgresql-${PG_MAJOR_VERSION}.spec
}

build() {
  echo "Building RPM and SRPM..."
  rpmbuild -ba ~/rpmbuild/SPECS/postgresql-${PG_MAJOR_VERSION}.spec \
  --define "pgmajorversion ${PG_MAJOR_VERSION}"

}

post_build() {
  echo "📤 Copying built RPMs to /output..."
  mkdir -p /output
  cp -v ~/rpmbuild/RPMS/*/*.rpm /output/ || echo "No binary RPMs found"
  cp -v ~/rpmbuild/SRPMS/*.src.rpm /output/ || echo "No SRPM found"
}

