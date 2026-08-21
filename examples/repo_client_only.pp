# The `bao` command line client only, with no configuration file and no service.
#
# `openbao::repo` stands on its own and installs nothing: it just sets up the APT or YUM
# repository. This is what an admin workstation or an application server querying a
# remote OpenBao wants, rather than the `openbao` class with everything switched off.
#
# The repository is tuned through the parameters of that class, typically from Hiera:
#
#   openbao::repo::gpgkey_source: 'puppet:///modules/profile/openbao.asc'
#   openbao::repo::apt_pin_priority: 990

# The class contains the APT index refresh on Debian, so the require is all the
# ordering the package needs.
include openbao::repo

package { 'openbao':
  ensure  => installed,
  require => Class['openbao::repo'],
}
