# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

inherit eutils user vcs-snapshot

DESCRIPTION="the multi-purpose NoSQL DB"
HOMEPAGE="http://www.arangodb.org/"

GITHUB_USER="triAGENS"
GITHUB_TAG="v${PV}"

SRC_URI="https://github.com/${GITHUB_USER}/${PN}/archive/${GITHUB_TAG}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="amd64"
IUSE=""

DEPEND=">=sys-libs/readline-6.2_p1
		>=dev-libs/openssl-1.0.1g
		>=dev-lang/go-1.2"
RDEPEND="${DEPEND}"


pkg_setup() {
	ebegin "Creating arangodb user and group"
	enewgroup arangodb
	enewuser arangodb -1 -1 -1 arangodb
	eend $?
}

src_configure() {
	econf --localstatedir="${EPREFIX}"/var --enable-all-in-one-v8 --enable-all-in-one-libev --enable-all-in-one-icu || die "configure failed"
}

src_install() {
	emake DESTDIR="${D}" install

	newinitd "${FILESDIR}"/arangodb.initd arangodb

	fowners arangodb:arangodb /var/lib/arangodb /var/lib/arangodb-apps /var/log/arangodb
}
