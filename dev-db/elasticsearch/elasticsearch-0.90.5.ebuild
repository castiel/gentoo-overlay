EAPI=4

inherit autotools eutils java-pkg-opt-2

DESCRIPTION="Elastic Search"
HOMEPAGE="http://www.elasticsearch.org/"
SRC_URI="http://download.elasticsearch.org/elasticsearch/elasticsearch/${P}.tar.gz"

SLOT="0"
LICENSE="GPL-2"
KEYWORDS="amd64 x86 amd64-linux x86-linux"
IUSE=""

RDEPEND=" >=virtual/jre-1.6 "
ES_INSTALL_DIR="/usr/share/elasticsearch"

src_install() {
	dodoc LICENSE.txt NOTICE.txt README.textile
	dodir "${ES_INSTALL_DIR}"
	insinto "${ES_INSTALL_DIR}"
	doins bin/elasticsearch.in.sh
        insinto "${ES_INSTALL_DIR}"/bin
        dobin bin/elasticsearch
        insinto "${ES_INSTALL_DIR}"/lib
        doins lib/*
	doins lib/sigar/libsigar-amd64-linux.so
	doins lib/sigar/libsigar-x86-linux.so

	newconfd ${FILESDIR}/elasticsearch.cnf elasticsearch
	newinitd ${FILESDIR}/elasticsearch.init elasticsearch
	doenvd ${FILESDIR}/70elastic
	
	dodir /etc/elasticsearch || die
	insinto /etc/elasticsearch
	doins config/elasticsearch.yml
	doins config/logging.yml

}
