# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-php5/pecl-memcache/pecl-memcache-3.0.4.ebuild,v 1.2 2010/01/04 18:33:16 robbat2 Exp $

EAPI="1"
PHP_EXT_NAME="memcache"
PHP_EXT_INI="yes"
PHP_EXT_ZENDEXT="no"
DOCS="README"

inherit php-ext-pecl-r1 php-ext-base-r1

KEYWORDS="~amd64 ~hppa ~ppc ~ppc64 ~sparc ~x86"

DESCRIPTION="PHP extension for using memcached."
LICENSE="PHP-3"
SLOT="0"
IUSE="+session"

DEPEND="sys-libs/zlib"
RDEPEND="${DEPEND}"

# upstream does not ship any testsuite, so the PHPize test-runner fails.
RESTRICT='test'

need_php_by_category

pkg_setup() {
	use session && require_php_with_use session
}

src_compile() {
	my_conf="--enable-memcache --with-zlib-dir=/usr $(use_enable session memcache-session)"
	php-ext-pecl-r1_src_compile
}

src_install() {
	php-ext-pecl-r1_src_install

	php-ext-base-r1_addtoinifiles "memcache.allow_failover" "true"
	php-ext-base-r1_addtoinifiles "memcache.max_failover_attempts" "20"
	php-ext-base-r1_addtoinifiles "memcache.chunk_size" "32768"
	php-ext-base-r1_addtoinifiles "memcache.default_port" "11211"
	php-ext-base-r1_addtoinifiles "memcache.hash_strategy" "consistent"
	php-ext-base-r1_addtoinifiles "memcache.hash_function" "crc32"
	php-ext-base-r1_addtoinifiles "memcache.redundancy" "1"
	php-ext-base-r1_addtoinifiles "memcache.session_redundancy" "2"
	php-ext-base-r1_addtoinifiles "memcache.protocol" "ascii"
}
