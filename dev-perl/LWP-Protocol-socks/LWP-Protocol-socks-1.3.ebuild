# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-perl/LWP-Authen-Wsse/LWP-Authen-Wsse-0.05.ebuild,v 1.1 2008/08/01 14:22:48 tove Exp $
EAPI=5
MODULE_AUTHOR=SCR
inherit perl-module

DESCRIPTION="Library for enabling Socks support in LWP"

LICENSE="|| ( Artistic GPL-2 )"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

DEPEND="dev-lang/perl"
RDEPEND=${DEPEND}
SRC_TEST=do
