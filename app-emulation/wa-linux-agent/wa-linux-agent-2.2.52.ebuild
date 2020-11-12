# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{6,7,8,9} )

inherit udev distutils-r1 eutils systemd

#MY_PN="WALinuxAgent"
#MY_PV="WALinuxAgent-${PV}"
#MY_P="${MY_PN}-${MY_PV}"

DESCRIPTION="Windows Azure Linux Agent"
HOMEPAGE="https://github.com/Azure/WALinuxAgent"
SRC_URI="${HOMEPAGE}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
RESTRICT="mirror"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~x86"
KEYWORDS="amd64"
IUSE="+udev systemd"

# waagent declares no reliance on 'eix', but then calls it unconditionally on
# Gentoo when 'checkPackageInstalled' or 'checkPackageUpdateable' are called.
DEPEND=""
RDEPEND="
	app-admin/sudo
	app-portage/eix
	sys-apps/grep
	sys-apps/iproute2
	sys-apps/sed
	sys-apps/shadow
	sys-apps/util-linux
	sys-block/parted
	>=dev-lang/python-2.6
	>=dev-libs/openssl-1.0.0:*
	>=net-misc/openssh-5.3"
	#dev-python/pyasn1 # Referenced in Dockerfile, but doesn't seem to be used...
BDEPEND=""

S="${WORKDIR}/WALinuxAgent-${PV}"

src_prepare() {
	# do not install tests
	rm -rf tests

	# allow root login
	# use ed25519 instead of rsa
	sed -i \
		-e '/Provisioning.DeleteRootPassword/s/=.*$/=n/' \
		-e '/Provisioning.SshHostKeyPairType/s/=.*$/=ed25519/' \
		-e '/AutoUpdate.Enabled/s/=.*$/=n/' \
		"${S}"/config/waagent.conf || die

	# install init.d / logrotate in gentoo way
	sed -i \
		-e '/set_logrotate_files(data_files)/d' \
		-e 's/set_sysv_files(data_files)/print/g' \
		-e 's@/etc/udev/rules.d/@/lib/udev/rules.d/@g' \
		"${S}"/setup.py || die

	# use dhcpcd instead of dhcp that fails to start
	# "Unable to set up timer: out of range"
	sed -i -e 's/pidof dhclient/pidof dhcpcd/' \
		"${S}"/azurelinuxagent/common/osutil/default.py || die

	default
}

python_install_all() {
	newinitd "${FILESDIR}"/waagent.initd waagent
	systemd_dounit init/waagent.service

	insinto "/etc"
	doins config/waagent.conf

	insinto /etc/logrotate.d
	newins config/waagent.logrotate waagent

	keepdir /var/lib/waagent

	distutils-r1_python_install_all
}
