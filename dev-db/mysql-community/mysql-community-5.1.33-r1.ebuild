# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-db/mysql-community/mysql-community-5.1.21_beta.ebuild,v 1.3 2008/11/14 09:43:04 robbat2 Exp $

#SERVER_URI="mirror://gentoo/MySQL-${PV%.*}/mysql-${PV//_/-}.tar.gz"
PBXT_VERSION="0.9.8-beta"
MY_EXTRAS_VER="20070916"

inherit mysql
# only to make repoman happy. it is really set in the eclass
IUSE="$IUSE sphinx"


SRC_URI="${SRC_URI} http://sphinxsearch.com/downloads/sphinx-0.9.9-rc2.tar.gz"

# REMEMBER: also update eclass/mysql*.eclass before committing!
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~ppc ~ppc64 ~s390 ~sh ~sparc ~sparc-fbsd ~x86 ~x86-fbsd"

mysql_src_unpack() {
        # Initialize the proper variables first
        mysql_init_vars
        unpack ${A}
	mv -f "${WORKDIR}/${MY_SOURCEDIR}" "${S}"
        cd "${S}"

	epatch "${FILESDIR}/105_all_mysql_config_cleanup-5.0.60.patch"
	if use sphinx ; then
		einfo "Installing Sphinx Storage Engine ..."
		cp -dprR ${WORKDIR}/sphinx-0.9.9-rc2/mysqlse ${WORKDIR}/mysql/storage/sphinx
		cd ${WORKDIR}/mysql
		einfo "BUILD/autorun.sh ..."
		BUILD/autorun.sh 2> /dev/null 
	fi

        # Additional checks, remove bundled zlib
        rm -f "${S}/zlib/"*.[ch]
        sed -i -e "s/zlib\/Makefile dnl/dnl zlib\/Makefile/" "${S}/configure.in"
        rm -f "scripts/mysqlbug"

        # Make charsets install in the right place
        find . -name 'Makefile.am' \
                -exec sed --in-place -e 's!$(pkgdatadir)!'${MY_SHAREDSTATEDIR}'!g' {} \;

        if mysql_version_is_at_least "4.1" ; then
                # Remove what needs to be recreated, so we're sure it's actually done
                find . -name Makefile \
                        -o -name Makefile.in \
                        -o -name configure \
                        -exec rm -f {} \;
                rm -f "ltmain.sh"
                rm -f "scripts/mysqlbug"
        fi

        local rebuilddirlist d

        if mysql_version_is_at_least "5.1.12" ; then
                rebuilddirlist="."
                # TODO: check this with a cmake expert
                cmake \
                        -DCMAKE_C_COMPILER=$(type -P $(tc-getCC)) \
                        -DCMAKE_CXX_COMPILER=$(type -P $(tc-getCXX)) \
                        "storage/innobase"
        else
                rebuilddirlist=". innobase"
        fi

        for d in ${rebuilddirlist} ; do
                einfo "Reconfiguring dir '${d}'"
                pushd "${d}" &>/dev/null
                AT_GNUCONF_UPDATE="yes" eautoreconf
                popd &>/dev/null
        done

        if mysql_check_version_range "4.1 to 5.0.99.99" \
        && use berkdb ; then
                [[ -w "bdb/dist/ltmain.sh" ]] && cp -f "ltmain.sh" "bdb/dist/ltmain.sh"
                cp -f "/usr/share/aclocal/libtool.m4" "bdb/dist/aclocal/libtool.ac" \
                || die "Could not copy libtool.m4 to bdb/dist/"
                #These files exist only with libtool-2*, and need to be included.
                if [ -f '/usr/share/aclocal/ltsugar.m4' ]; then
                        cat "/usr/share/aclocal/ltsugar.m4" >>  "bdb/dist/aclocal/libtool.ac"
                        cat "/usr/share/aclocal/ltversion.m4" >>  "bdb/dist/aclocal/libtool.ac"
                        cat "/usr/share/aclocal/lt~obsolete.m4" >>  "bdb/dist/aclocal/libtool.ac"
                        cat "/usr/share/aclocal/ltoptions.m4" >>  "bdb/dist/aclocal/libtool.ac"
                fi
                pushd "bdb/dist" &>/dev/null
                sh s_all \
                || die "Failed bdb reconfigure"
                popd &>/dev/null
        fi
}

src_compile() {
        # Make sure the vars are correctly initialized
        mysql_init_vars

        # $myconf is modified by the configure_* functions
        local myconf=""

        if use minimal ; then
                configure_minimal
        else
                configure_common
                configure_51_sphinx
        fi
        # Bug #114895, bug #110149
        filter-flags "-O" "-O[01]"

        # glib-2.3.2_pre fix, bug #16496
        append-flags "-DHAVE_ERRNO_AS_DEFINE=1"

        # As discovered by bug #246652, doing a double-level of SSP causes NDB to
        # fail badly during cluster startup.
        if [[ $(gcc-major-version) -lt 4 ]]; then
                filter-flags "-fstack-protector-all"
        fi

        CXXFLAGS="${CXXFLAGS} -fno-exceptions -fno-strict-aliasing"
        CXXFLAGS="${CXXFLAGS} -felide-constructors -fno-rtti"
        mysql_version_is_at_least "5.0" \
        && CXXFLAGS="${CXXFLAGS} -fno-implicit-templates"
        export CXXFLAGS

        econf \
                --libexecdir="/usr/sbin" \
                --sysconfdir="${MY_SYSCONFDIR}" \
                --localstatedir="${MY_LOCALSTATEDIR}" \
                --sharedstatedir="${MY_SHAREDSTATEDIR}" \
                --libdir="${MY_LIBDIR}" \
                --includedir="${MY_INCLUDEDIR}" \
                --with-low-memory \
                --with-client-ldflags=-lstdc++ \
                --enable-thread-safe-client \
                --with-comment="Gentoo Linux ${PF}" \
                --without-docs \
                ${myconf} || die "econf failed"

        # TODO: Move this before autoreconf !!!
        find . -type f -name Makefile -print0 \
        | xargs -0 -n100 sed -i \
        -e 's|^pkglibdir *= *$(libdir)/mysql|pkglibdir = $(libdir)|;s|^pkgincludedir *= *$(includedir)/mysql|pkgincludedir = $(includedir)
|'

        emake || die "emake failed"

        mysql_version_is_at_least "5.1.12" && use pbxt && pbxt_src_compile
}
configure_51_sphinx() {
        # TODO: !!!! readd --without-readline
        # the failure depend upon config/ac-macros/readline.m4 checking into
        # readline.h instead of history.h
        myconf="${myconf} $(use_with ssl)"
        myconf="${myconf} --enable-assembler"
        myconf="${myconf} --with-geometry"
        myconf="${myconf} --with-readline"
        myconf="${myconf} --with-row-based-replication"
        myconf="${myconf} --with-zlib=/usr/$(get_libdir)"
        myconf="${myconf} --without-pstack"
        use max-idx-128 && myconf="${myconf} --with-max-indexes=128"

        # 5.1 introduces a new way to manage storage engines (plugins)
        # like configuration=none
        local plugins="csv,myisam,myisammrg,heap"
        if use extraengine ; then
                # like configuration=max-no-ndb, archive and example removed in 5.1.11
                plugins="${plugins},archive,blackhole,example,federated,partition"

                elog "Before using the Federated storage engine, please be sure to read"
                elog "http://dev.mysql.com/doc/refman/5.1/en/federated-limitations.html"
        fi
	if use sphinx ; then
                plugins="${plugins},sphinx"
	fi

        # Upstream specifically requests that InnoDB always be built.
        plugins="${plugins},innobase"

        # like configuration=max-no-ndb
        if use cluster ; then
                plugins="${plugins},ndbcluster"
                myconf="${myconf} --with-ndb-binlog"
        fi

        if mysql_version_is_at_least "5.2" ; then
                plugins="${plugins},falcon"
        fi

        myconf="${myconf} --with-plugins=${plugins}"
}

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
