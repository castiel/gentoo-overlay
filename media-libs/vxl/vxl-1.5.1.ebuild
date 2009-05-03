# Copyright 1999-2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

DESCRIPTION="A multi-platform collection of C++ software libraries for Computer
Vision and Image Understanding."
HOMEPAGE="http://vxl.sourceforge.net"
SRC_URI="mirror://sourceforge/vxl/${P}.tgz
		doc? ( mirror://sourceforge/vxl/${P}-doc.tgz )"

LICENSE="as-is"
SLOT="0"
KEYWORDS="~x86"
IUSE="contrib contribvidl2 conversions geometry imaging numerics serialisation
utilities examples gel mul oul oxl prip rpl sharedlibs targetjr tbl testing
unmaintained vgui doc"

RDEPEND=""
DEPEND="${RDEPEND}
	>=dev-util/cmake-2.0"

MYBUILDDIR=${WORKDIR}/build
src_unpack(){
	mkdir ${MYBUILDDIR}
	unpack ${A}
}

src_compile(){
	cd ${MYBUILDDIR}
	DOPTS=""
	if use unmaintained; then
		DOPTS="${DOPTS} -DBUILD_UNMAINTAINED_LIBRARIES=YES"
	else
		DOPTS="${DOPTS} -DBUILD_UNMAINTAINED_LIBRARIES=NO"		
	fi
	if use vgui; then
		DOPTS="${DOPTS} -DBUILD_VGUI=YES"
	fi
	if use oul; then
		DOPTS="${DOPTS} -DBUILD_OUL=YES"
	fi
	if use oxl; then
		DOPTS="${DOPTS} -DBUILD_OXL=YES"
	fi
	if use prip; then
		DOPTS="${DOPTS} -DBUILD_PRIP=YES"
	fi
	if use rpl; then
		DOPTS="${DOPTS} -DBUILD_RPL=YES"
	fi
	if use targetjr; then
		DOPTS="${DOPTS} -DBUILD_TARGETJR=YES"
	fi
	if use tbl; then
		DOPTS="${DOPTS} -DBUILD_TBL=YES"
	fi
	if use contrib; then
		DOPTS="${DOPTS} -DBUILD_CONTRIB=YES"
	fi
	if use contribvidl2; then
		DOPTS="${DOPTS} -DBUILD_CONTRIB_VIDL2=YES"
	fi
	if use conversions; then
		DOPTS="${DOPTS} -DBUILD_CONVERSIONS=YES"
	fi
	if use geometry; then
		DOPTS="${DOPTS} -DBUILD_CORE_GEOMETRY=YES"
	fi
	if use imaging; then
		DOPTS="${DOPTS} -DBUILD_CORE_IMAGING=YES"
	fi
	if use numerics; then
		DOPTS="${DOPTS} -DBUILD_CORE_NUMERICS=YES"
	fi
	if use serialisation; then
		DOPTS="${DOPTS} -DBUILD_CORE_SERIALISATION=YES"
	fi
	if use utilities; then
		DOPTS="${DOPTS} -DBUILD_CORE_UTILITIES=YES"
	fi
	if use examples; then
		DOPTS="${DOPTS} -DBUILD_EXAMPLES=YES"
	fi
	if use gel; then
		DOPTS="${DOPTS} -DBUILD_GEL=YES"
	fi
	if use sharedlibs; then
		DOPTS="${DOPTS} -DBUILD_SHARED_LIBS=YES"
	fi
	if use testing; then
		DOPTS="${DOPTS} -DBUILD_TESTING=YES"
	fi
	
	cmake ../${P} -DCMAKE_INSTALL_PREFIX:PATH=/usr ${DOPTS} || die "cmake failed"
	emake || die "emake failed"
}

src_install(){
	cd ${MYBUILDDIR}
	make DESTDIR=${D} install || die

	if use doc; then
		dohtml -r ${WORKDIR}/www
		dohtml -r ${WORKDIR}/Doxy
	fi
}
