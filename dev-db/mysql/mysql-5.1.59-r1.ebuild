# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-db/mysql/mysql-5.1.59.ebuild,v 1.1 2011/09/30 02:46:36 jmbsvicetto Exp $

EAPI="2"

MY_EXTRAS_VER="20110721-0450Z"
# PBXT
PBXT_VERSION='1.0.11-6-pre-ga'
# XtraDB
PERCONA_VER='5.1.45-10' XTRADB_VER='1.0.6-10'

# Build type
BUILD="autotools"

inherit toolchain-funcs mysql-v2

SPXV="sphinx-2.0.2-beta"
SRC_URI="${SRC_URI} http://sphinxsearch.com/files/${SPXV}.tar.gz"
# only to make repoman happy. it is really set in the eclass
#IUSE="$IUSE sphinx"
IUSE="big-tables debug embedded minimal +perl selinux -ssl static test sphinx"

# REMEMBER: also update eclass/mysql*.eclass before committing!
KEYWORDS="~alpha amd64 ~arm ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc x86 ~sparc-fbsd ~x86-fbsd ~ppc-macos ~x64-macos ~x86-solaris"

# When MY_EXTRAS is bumped, the index should be revised to exclude these.
# This is often broken still
EPATCH_EXCLUDE=''

# Most of these are in the eclass
DEPEND="|| ( >=sys-devel/gcc-3.4.6 >=sys-devel/gcc-apple-4.0 )
		>=sys-devel/libtool-2.2.10"
RDEPEND="${RDEPEND} 
	sphinx? ( >=app-misc/sphinx-2.0.2_beta )"

src_install() {
        mysql-v2_src_install
        dodir /usr/share/php/sphinx
        insinto /usr/share/php/sphinx
                doins ${WORKDIR}/${SPXV}/api/sphinxapi.php
}


# Please do not add a naive src_unpack to this ebuild
# If you want to add a single patch, copy the ebuild to an overlay
# and create your own mysql-extras tarball, looking at 000_index.txt
src_prepare() {
	sed -i \
		-e '/^noinst_PROGRAMS/s/basic-t//g' \
		"${S}"/unittest/mytap/t/Makefile.am
	if use sphinx ; then
		if use ssl ; then
			eerror "You can't use ssl and sphinx use flags at the same time"
			eerror "Please add 'dev-db/mysql -ssl' in /etc/portage/package.use"
		fi
		einfo "Installing Sphinx Storage Engine ..."
		cp -dprR ${WORKDIR}/${SPXV}/mysqlse ${WORKDIR}/mysql/storage/sphinx
		cd ${WORKDIR}/mysql
		einfo "BUILD/autorun.sh ..."
		automake --add-missing --force  --copy storage/sphinx/Makefile
#		BUILD/autorun.sh 
	fi
	mysql-v2_src_prepare
}

# Official test instructions:
# USE='berkdb -cluster embedded extraengine perl ssl community' \
# FEATURES='test userpriv -usersandbox' \
# ebuild mysql-X.X.XX.ebuild \
# digest clean package
src_test() {
	# Bug #213475 - MySQL _will_ object strenously if your machine is named
	# localhost. Also causes weird failures.
	[[ "${HOSTNAME}" == "localhost" ]] && die "Your machine must NOT be named localhost"

	emake check || die "make check failed"
	if ! use "minimal" ; then
		if [[ $UID -eq 0 ]]; then
			die "Testing with FEATURES=-userpriv is no longer supported by upstream. Tests MUST be run as non-root."
		fi
		has usersandbox $FEATURES && eerror "Some tests may fail with FEATURES=usersandbox"
		cd "${S}"
		einfo ">>> Test phase [test]: ${CATEGORY}/${PF}"
		local retstatus_unit
		local retstatus_ns
		local retstatus_ps
		local t
		addpredict /this-dir-does-not-exist/t9.MYI

		# Ensure that parallel runs don't die
		export MTR_BUILD_THREAD="$((${RANDOM} % 100))"

		# archive_gis really sucks a lot, but it's only relevant for the
		# USE=extraengines case
		case ${PV} in
			5.0.42)
			mysql-v2_disable_test "archive_gis" "Totally broken in 5.0.42"
			;;

			5.0.4[3-9]|5.0.[56]*|5.0.70|5.0.87)
			[ "$(tc-endian)" == "big" ] && \
			mysql-v2_disable_test \
				"archive_gis" \
				"Broken in 5.0.43-70 and 5.0.87 on big-endian boxes only"
			;;
		esac

		# This was a slight testcase breakage when the read_only security issue
		# was fixed.
		case ${PV} in
			5.0.54|5.0.51*)
			mysql-v2_disable_test \
				"read_only" \
				"Broken in 5.0.51-54, output in wrong order"
			;;
		esac

		# Ditto to read_only
		[ "${PV}" == "5.0.51a" ] && \
			mysql-v2_disable_test \
				"view" \
				"Broken in 5.0.51, output in wrong order"

		# x86-specific, OOM issue with some subselects on low memory servers
		[ "${PV}" == "5.0.54" ] && \
			[ "${ARCH/x86}" != "${ARCH}" ] && \
			mysql-v2_disable_test \
				"subselect" \
				"Testcase needs tuning on x86 for oom condition"

		# Broke with the YaSSL security issue that didn't affect Gentoo.
		[ "${PV}" == "5.0.56" ] && \
			for t in openssl_1 rpl_openssl rpl_ssl ssl \
				ssl_8k_key ssl_compress ssl_connect ; do \
				mysql-v2_disable_test \
					"$t" \
					"OpenSSL tests broken on 5.0.56"
			done

		# New test was broken in first time
		# Upstream bug 41066
		# http://bugs.mysql.com/bug.php?id=41066
		[ "${PV}" == "5.0.72" ] && \
			mysql-v2_disable_test \
				"status2" \
				"Broken in 5.0.72, new test is broken, upstream bug #41066"

		# The entire 5.0 series has pre-generated SSL certificates, they have
		# mostly expired now. ${S}/mysql-tests/std-data/*.pem
		# The certs really SHOULD be generated for the tests, so that they are
		# not expiring like this. We cannot do so ourselves as the tests look
		# closely as the cert path data, and we do not have the CA key to regen
		# ourselves. Alternatively, upstream should generate them with at least
		# 50-year validity.
		#
		# Known expiry points:
		# 4.1.*, 5.0.0-5.0.22, 5.1.7: Expires 2013/09/09
		# 5.0.23-5.0.77, 5.1.7-5.1.22?: Expires 2009/01/27
		# 5.0.78-5.0.90, 5.1.??-5.1.42: Expires 2010/01/28
		#
		# mysql-test/std_data/untrusted-cacert.pem is MEANT to be
		# expired/invalid.
		case ${PV} in
			5.0.*|5.1.*|5.4.*|5.5.*)
				for t in openssl_1 rpl_openssl rpl.rpl_ssl rpl.rpl_ssl1 ssl ssl_8k_key \
					ssl_compress ssl_connect rpl.rpl_heartbeat_ssl ; do \
					mysql-v2_disable_test \
						"$t" \
						"These OpenSSL tests break due to expired certificates"
				done
			;;
		esac

		# These are also failing in MySQL 5.1 for now, and are believed to be
		# false positives:
		#
		# main.mysql_comment, main.mysql_upgrade, main.information_schema,
		# funcs_1.is_columns_mysql funcs_1.is_tables_mysql funcs_1.is_triggers:
		# fails due to USE=-latin1 / utf8 default
		#
		# main.mysql_client_test:
		# segfaults at random under Portage only, suspect resource limits.
		#
		# main.not_partition:
		# Failure reason unknown at this time, must resolve before package.mask
		# removal FIXME
		case ${PV} in
			5.1.*|5.4.*|5.5.*)
			for t in main.mysql_client_test main.mysql_comments \
				main.mysql_upgrade  \
				main.information_schema \
				main.not_partition funcs_1.is_columns_mysql \
				funcs_1.is_tables_mysql funcs_1.is_triggers; do
				mysql-v2_disable_test  "$t" "False positives in Gentoo"
			done
			;;
		esac

		# New failures in 5.1.50/5.1.51, reported by jmbsvicetto.
		# These tests are picking up a 'connect-timeout' config from somewhere,
		# which is not valid, and since it does not have 'loose-' in front of
		# it, it's causing a failure
		case ${PV} in
			5.1.5*|5.4.*|5.5.*|6*)
			for t in rpl.rpl_mysql_upgrade main.log_tables_upgrade ; do
				mysql-v2_disable_test  "$t" \
					"False positives in Gentoo: connect-timeout"
			done
			;;
		esac

		use profiling && use community \
		|| mysql-v2_disable_test main.profiling \
			"Profiling test needs profiling support"

		if [ "${PN}" == "mariadb" ]; then
			for t in \
				parts.part_supported_sql_func_ndb \
				parts.partition_auto_increment_ndb ; do
					mysql-v2_disable_test $t "ndb not supported in mariadb"
			done
		fi

		# This fail with XtraDB in place of normal InnoDB
		# TODO: test if they are broken with the rest of the Percona patches
		if xtradb_patch_available && use xtradb ; then
			for t in main.innodb innodb.innodb_bug51378 \
				main.information_schema_db main.mysqlshow \
				main.innodb-autoinc main.innodb_bug21704 \
				main.innodb_bug44369 main.innodb_bug46000 \
				main.index_merge_innodb \
				innodb.innodb innodb.innodb_misc1 innodb.innodb_bug52663 \
				innodb.innodb-autoinc innodb.innodb-autoinc-44030 \
				innodb.innodb_bug21704 innodb.innodb_bug44369 \
				innodb.innodb_bug46000 innodb.innodb_bug48024 \
				innodb.innodb_bug49164 innodb.innodb_bug51920 \
				innodb.innodb_bug54044 \
				; do
					mysql-v2_disable_test $t "tests broken in xtradb"
			done
		fi

		# bug 332565
		if ! use extraengine ; then
			for t in main.range ; do
				mysql-v2_disable_test $t "Test $t requires USE=extraengine"
			done
		fi

		# create directories because mysqladmin might make out of order
		mkdir -p "${S}"/mysql-test/var-{ps,ns}{,/log}

		# We run the test protocols seperately
		emake test-unit
		retstatus_unit=$?
		[[ $retstatus_unit -eq 0 ]] || eerror "test-unit failed"

		emake test-ns force="--force --vardir=${S}/mysql-test/var-ns"
		retstatus_ns=$?
		[[ $retstatus_ns -eq 0 ]] || eerror "test-ns failed"
		has usersandbox $FEATURES && eerror "Some tests may fail with FEATURES=usersandbox"

		emake test-ps force="--force --vardir=${S}/mysql-test/var-ps"
		retstatus_ps=$?
		[[ $retstatus_ps -eq 0 ]] || eerror "test-ps failed"
		has usersandbox $FEATURES && eerror "Some tests may fail with FEATURES=usersandbox"

		# TODO:
		# When upstream enables the pr and nr testsuites, we need those as well.

		# Cleanup is important for these testcases.
		pkill -9 -f "${S}/ndb" 2>/dev/null
		pkill -9 -f "${S}/sql" 2>/dev/null
		failures=""
		[[ $retstatus_unit -eq 0 ]] || failures="${failures} test-unit"
		[[ $retstatus_ns -eq 0 ]] || failures="${failures} test-ns"
		[[ $retstatus_ps -eq 0 ]] || failures="${failures} test-ps"
		has usersandbox $FEATURES && eerror "Some tests may fail with FEATURES=usersandbox"
		[[ -z "$failures" ]] || die "Test failures: $failures"
		einfo "Tests successfully completed"
	else
		einfo "Skipping server tests due to minimal build."
	fi
}


configure_51_sphinx() {
        # TODO: !!!! readd --without-readline
        # the failure depend upon config/ac-macros/readline.m4 checking into
        # readline.h instead of history.h
        myconf="${myconf} $(use_with ssl ssl /usr)"
        myconf="${myconf} --enable-assembler"
        myconf="${myconf} --with-geometry"
        myconf="${myconf} --with-readline"
        myconf="${myconf} --with-zlib-dir=/usr/"
        myconf="${myconf} --without-pstack"
        myconf="${myconf} --with-plugindir=/usr/$(get_libdir)/mysql/plugin"

        # This is an explict die here, because if we just forcibly disable it, then the
        # user's data is not accessible.
        use max-idx-128 && die "Bug #336027: upstream has a corruption issue with max-idx-128 presently"
        #use max-idx-128 && myconf="${myconf} --with-max-indexes=128"
        if [ "${MYSQL_COMMUNITY_FEATURES}" == "1" ]; then
                myconf="${myconf} $(use_enable community community-features)"
                if use community; then
                        myconf="${myconf} $(use_enable profiling)"
                else
                        myconf="${myconf} --disable-profiling"
                fi
        fi

        # Scan for all available plugins
        local plugins_avail="$(
        LANG=C \
        find "${S}" \
                \( \
                -name 'plug.in' \
                -o -iname 'configure.in' \
                -o -iname 'configure.ac' \
                \) \
                -print0 \
        | xargs -0 sed -r -n \
                -e '/^MYSQL_STORAGE_ENGINE/{
                        s~MYSQL_STORAGE_ENGINE\([[:space:]]*\[?([-_a-z0-9]+)\]?.*,~\1 ~g ;
                        s~^([^ ]+).*~\1~gp;
                }' \
        | tr -s '\n' ' '
        )"

        # 5.1 introduces a new way to manage storage engines (plugins)
        # like configuration=none
        # This base set are required, and will always be statically built.
        local plugins_sta="csv myisam myisammrg heap"
        local plugins_dyn=""
        local plugins_dis="example ibmdb2i"

        if use sphinx ; then
                plugins_sta="${plugins_sta} sphinx"
        fi

        # These aren't actually required by the base set, but are really useful:
        plugins_sta="${plugins_sta} archive blackhole"

        # default in 5.5.4
        if mysql_version_is_at_least "5.5.4" ; then
                plugins_sta="${plugins_sta} partition"
        fi
        # Now the extras
        if use extraengine ; then
                # like configuration=max-no-ndb, archive and example removed in 5.1.11
                # not added yet: ibmdb2i
                # Not supporting as examples: example,daemon_example,ftexample
                plugins_sta="${plugins_sta} partition"
                if [[ "${PN}" != "mariadb" ]] ; then
                        elog "Before using the Federated storage engine, please be sure to read"
                        elog "http://dev.mysql.com/doc/refman/5.1/en/federated-limitations.html"
                        plugins_dyn="${plugins_sta} federated"
                else
                        elog "MariaDB includes the FederatedX engine. Be sure to read"
                        elog "http://askmonty.org/wiki/index.php/Manual:FederatedX_storage_engine"
                        plugins_dyn="${plugins_sta} federatedx"
                fi
        else
                plugins_dis="${plugins_dis} partition federated"
        fi

        # Upstream specifically requests that InnoDB always be built:
        # - innobase, innodb_plugin
        # Build falcon if available for 6.x series.
        for i in innobase falcon ; do
                [ -e "${S}"/storage/${i} ] && plugins_sta="${plugins_sta} ${i}"
        done
        for i in innodb_plugin ; do
                [ -e "${S}"/storage/${i} ] && plugins_dyn="${plugins_dyn} ${i}"
        done

        # like configuration=max-no-ndb
        if ( use cluster || [[ "${PN}" == "mysql-cluster" ]] ) ; then
                plugins_sta="${plugins_sta} ndbcluster partition"
                plugins_dis="${plugins_dis//partition}"
                myconf="${myconf} --with-ndb-binlog"
        else
                plugins_dis="${plugins_dis} ndbcluster"
        fi

        if [[ "${PN}" == "mariadb" ]] ; then
                # In MariaDB, InnoDB is packaged in the xtradb directory, so it's not
                # caught above.
                # This is not optional, without it several upstream testcases fail.
                # Also strongly recommended by upstream.
                if [[ "${PV}" < "5.2.0" ]] ; then
                        myconf="${myconf} --with-maria-tmp-tables"
                        plugins_sta="${plugins_sta} maria"
                else
                        myconf="${myconf} --with-aria-tmp-tables"
                        plugins_sta="${plugins_sta} aria"
                fi

                [ -e "${S}"/storage/innobase ] || [ -e "${S}"/storage/xtradb ] ||
                        die "The ${P} package doesn't provide innobase nor xtradb"

                for i in innobase xtradb ; do
                        [ -e "${S}"/storage/${i} ] && plugins_sta="${plugins_sta} ${i}"
                done

                myconf="${myconf} $(use_with libevent)"

                if mysql_version_is_at_least "5.2" ; then
                        #This should include sphinx, but the 5.2.4 archive forgot the plug.in file
                        #for i in oqgraph sphinx ; do
                        for i in oqgraph ; do
                                use ${i} \
                                && plugins_dyn="${plugins_dyn} ${i}" \
                                || plugins_dis="${plugins_dis} ${i}"
                        done
                fi
        fi

        if pbxt_available && [[ "${PBXT_NEWSTYLE}" == "1" ]]; then
                use pbxt \
                && plugins_dyn="${plugins_dyn} pbxt" \
                || plugins_dis="${plugins_dis} pbxt"
        fi

        use static && \
        plugins_sta="${plugins_sta} ${plugins_dyn}" && \
        plugins_dyn=""

        einfo "Available plugins: ${plugins_avail}"
        einfo "Dynamic plugins: ${plugins_dyn}"
        einfo "Static plugins: ${plugins_sta}"
        einfo "Disabled plugins: ${plugins_dis}"

        # These are the static plugins
        myconf="${myconf} --with-plugins=${plugins_sta// /,}"
        # And the disabled ones
        for i in ${plugins_dis} ; do
                myconf="${myconf} --without-plugin-${i}"
        done
}

src_configure() {
        # Make sure the vars are correctly initialized
        mysql_init_vars

        # $myconf is modified by the configure_* functions
        local myconf=""

        if use minimal ; then
                configure_minimal
        else
                configure_common
                if mysql_version_is_at_least "5.1.10" ; then
                        configure_51_sphinx
                else
                        configure_40_41_50
                fi
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

        # bug #283926, with GCC4.4, this is required to get correct behavior.
        append-flags -fno-strict-aliasing

        # bug #335185, #335995, with >= GCC4.3.3 on x86 only, omit-frame-pointer
        # causes a mis-compile.
        # Upstream bugs:
        # http://gcc.gnu.org/bugzilla/show_bug.cgi?id=38562
        # http://bugs.mysql.com/bug.php?id=45205
        use x86 && version_is_at_least "4.3.3" "$(gcc-fullversion)" && \
                append-flags -fno-omit-frame-pointer && \
                filter-flags -fomit-frame-pointer

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
                --with-LIBDIR="$(get_libdir)" \
                ${myconf} || die "econf failed"

        # TODO: Move this before autoreconf !!!
        find . -type f -name Makefile -print0 \
        | xargs -0 -n100 sed -i \
        -e 's|^pkglibdir *= *$(libdir)/mysql|pkglibdir = $(libdir)|;s|^pkgincludedir *= *$(includedir)/mysql|pkgincludedir = $(includedir)|'

        if [[ $EAPI == 2 ]] && [[ "${PBXT_NEWSTYLE}" != "1" ]]; then
                pbxt_patch_available && use pbxt && pbxt_src_configure
        fi
}

