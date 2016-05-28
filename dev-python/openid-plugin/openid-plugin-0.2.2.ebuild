# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-python/cosmolopy/cosmolopy-0.1.103.ebuild,v 1.1 2011/05/13 04:46:10 bicatali Exp $

EAPI=5

PYTHON_DEPEND="2"
SUPPORT_PYTHON_ABIS="1"
RESTRICT_PYTHON_ABIS="3.* *-jython"

inherit distutils

MY_PN=authopenid-plugin
MY_P=${MY_PN}-${PV}
S="${WORKDIR}/Dalius-${MY_PN}-v${PV}/"
DESCRIPTION="Fork of authopenid-plugin; Support prettier account names, and better cooexistence with other login modules"
HOMEPAGE="https://bitbucket.org/Dalius/authopenid-plugin"
SRC_URI="https://bitbucket.org/Dalius/authopenid-plugin/get/v${PV}.tar.bz2"
LICENSE="TRAC"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND="www-apps/trac
	dev-python/python-openid"
RDEPEND=""


