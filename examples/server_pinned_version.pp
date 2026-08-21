# A server pinned to an exact package version, installed from the OpenBao repository.
#
# With `install_method => 'repo'` (the default), `package_ensure` becomes the `ensure`
# value of the package. The repository keeps every published release, so naming one holds
# the node there — downgrading it if needed — instead of following the latest.
#
# `version` is not set here: it only matters for `install_method => 'archive'`, see
# `server_archive_install.pp`.

class { 'openbao':
  package_ensure => '2.6.1',
}
