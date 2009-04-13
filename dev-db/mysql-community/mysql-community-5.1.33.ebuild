# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-db/mysql-community/mysql-community-5.1.21_beta.ebuild,v 1.3 2008/11/14 09:43:04 robbat2 Exp $

MY_EXTRAS_VER="20070916"
#SERVER_URI="mirror://gentoo/MySQL-${PV%.*}/mysql-${PV//_/-}.tar.gz"
PBXT_VERSION="0.9.8-beta"

inherit mysql
# only to make repoman happy. it is really set in the eclass
IUSE="$IUSE"

# REMEMBER: also update eclass/mysql*.eclass before committing!
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~ppc ~ppc64 ~s390 ~sh ~sparc ~sparc-fbsd ~x86 ~x86-fbsd"

src_test() {
	make check || die "make check failed"
	if ! use "minimal" ; then
		cd "${S}/mysql-test"
		einfo ">>> Test phase [test]: ${CATEGORY}/${PF}"
		local retstatus
		local t
		local testopts="--force"

		addpredict /this-dir-does-not-exist/t9.MYI

		# mysqladmin start before dir creation
		mkdir "${S}"/mysql-test/var{,/log}

		# Ensure that parallel runs don't die
		export MTR_BUILD_THREAD="$((${RANDOM} % 100))"

		# sandbox make ndbd zombie
		#X#hasq "sandbox" ${FEATURES} && testopts="${testopts} --skip-ndb"

		#X#if [[ ${UID} -eq 0 ]] ; then
		#X#	einfo "Disabling IM tests due to failure as root"
		#X#	mysql_disable_test  "im_cmd_line"          "fail as root"
		#X#	mysql_disable_test  "im_daemon_life_cycle" "fail as root"
		#X#	mysql_disable_test  "im_instance_conf"     "fail as root"
		#X#	mysql_disable_test  "im_life_cycle"        "fail as root"
		#X#	mysql_disable_test  "im_options"           "fail as root"
		#X#	mysql_disable_test  "im_utils"             "fail as root"
		#X#	mysql_disable_test  "trigger"              "fail as root"
		#X#fi

		#use "extraengine" && mysql_disable_test "federated" "fail with extraengine"

		#mysql_disable_test "view" "Already fixed: fail because now we are in year 2007"

		# from Makefile.am:
		retstatus=1
		./mysql-test-run.pl ${testopts} --mysqld=--binlog-format=mixed \
		&& ./mysql-test-run.pl ${testopts} --mysqld=--binlog-format=row \
		&& ./mysql-test-run.pl ${testopts} --ps-protocol --mysqld=--binlog-format=row \
		&& ./mysql-test-run.pl ${testopts} --ps-protocol --mysqld=--binlog-format=mixed \
		&& retstatus=0

		# Just to be sure ;)
		pkill -9 -f "${S}/ndb" 2>/dev/null
		pkill -9 -f "${S}/sql" 2>/dev/null
		[[ $retstatus -eq 0 ]] || die "make test failed"
	else
		einfo "Skipping server tests due to minimal build."
	fi
}
