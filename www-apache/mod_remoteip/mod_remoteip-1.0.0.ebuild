# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/www-apache/mod_remoteip/mod_remoteip-1.10.1.ebuild,v 1.2 2008/01/31 18:48:36 hollow Exp $

inherit apache-module eutils

KEYWORDS="~amd64 ~x86"

DESCRIPTION="mod_remoteip"
HOMEPAGE="http://people.apache.org/~wrowe/"
SRC_URI="http://mark.burazin.net/mod_remoteip/${P/-/-}.tar.bz2"

LICENSE="BSD"
SLOT="0"
IUSE=""

DEPEND=""
RDEPEND=""

APACHE2_MOD_CONF="10_${PN}"
APACHE2_MOD_DEFINE="REMOTEIP"

need_apache2

S="${WORKDIR}"/${PN}

src_unpack() {
	unpack ${A}
	cd "${S}"
}

src_install() {
	keepdir /var/log/apache2/remoteip
	apache-module_src_install
}
