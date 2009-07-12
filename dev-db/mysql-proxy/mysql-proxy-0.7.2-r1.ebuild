# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-db/mysql-proxy/mysql-proxy-0.6.1.ebuild,v 1.1 2008/02/07 19:44:00 wschlich Exp $

inherit eutils

DESCRIPTION="A Proxy for the MySQL Client/Server protocol"
HOMEPAGE="http://forge.mysql.com/wiki/MySQL_Proxy"
SRC_URI="mirror://mysql/Downloads/MySQL-Proxy/${P}.tar.gz"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="lua examples"
DEPEND=">=dev-libs/libevent-1.0
	>=dev-libs/glib-2.0
	>=virtual/mysql-4.0
	lua? ( >=dev-lang/lua-5.1 )"

src_compile() {
	econf \
		--with-mysql \
		$(use_with lua) \
		|| die "econf failed"
	emake || die "emake failed"
}
src_install() {
    emake -j1 DESTDIR="${D}" install
	if useq lua; then
		insinto /usr/$(get_libdir)/${PN}/lua/
		doins lib/*.lua
#		doins lib/.libs/lpeg.so
		doins "${FILESDIR}/${PV}/rw-splittingcv.lua"
#		insinto /usr/${LIBDIR}/${PN}/lua/proxy
#		doins lib/proxy/*.lua
#		insinto /usr/share/${PN}
#		doins lib/*.lua
#		insinto /usr/share/${PN}/proxy
#		doins lib/proxy/*.lua
		if useq examples; then
			insinto /usr/share/${PN}/examples
			doins examples/*.lua
		fi
	fi
	dodoc README INSTALL NEWS
	newinitd "${FILESDIR}/${PV}/${PN}.initd" ${PN}
	newconfd "${FILESDIR}/${PV}/${PN}.confd" ${PN}
}

ssrc_install() {
	into /usr
	dolib.so src/.libs/libmysql-chassis.so.0.0.0
	dolib.so src/.libs/libmysql-proxy.so.0.0.0
	dosbin src/.libs/mysql-proxy
	insinto /usr/lib/mysql-proxy/plugins/
	doins plugins/replicant/.libs/libreplicant.so
	doins plugins/admin/.libs/libadmin.so
	doins plugins/debug/.libs/libdebug.so
	doins plugins/proxy/.libs/libproxy.so
}

pkg_postinst() {
	einfo
	einfo "You might want to have a look at"
	einfo "http://dev.mysql.com/tech-resources/articles/proxy-gettingstarted.html"
	einfo "on how to get started with MySQL Proxy."
	einfo
}
