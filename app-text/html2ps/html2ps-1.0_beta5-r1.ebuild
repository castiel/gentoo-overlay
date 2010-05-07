# Copyright 1999-2005 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit eutils

MY_PV=${PV/_beta/b}

DESCRIPTION="HTML to PostScript converter"
HOMEPAGE="http://user.it.uu.se/~jan/html2ps.html"
SRC_URI="http://user.it.uu.se/~jan/${PN}-${MY_PV}.tar.gz"
KEYWORDS="~amd64 ~x86"
SLOT="0"
LICENSE="GPL-2"

S=${WORKDIR}/${PN}-${MY_PV}

DEPEND="dev-lang/perl
	dev-perl/libwww-perl
	png? ( media-gfx/imagemagick )
	tcltk? ( dev-lang/tk )"

IUSE="tcltk"

src_unpack() {
	unpack ${A}
	epatch "${FILESDIR}/${P}-conf.patch"
	epatch "${FILESDIR}/${P}-perl.patch"
}

src_install () {
	dobin html2ps 
	doman html2ps.1 html2psrc.5
	dodoc COPYING README html2ps.html sample
	insinto /etc ; doins html2psrc
	if use tcltk; then
		dobin contrib/xhtml2ps/xhtml2ps
		newdoc contrib/xhtml2ps/README README.xhtml2ps	
	fi
}
