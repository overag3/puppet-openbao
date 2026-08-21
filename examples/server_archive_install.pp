# A server installed from the upstream release tarball instead of the package repository.
#
# Useful on distributions OpenBao publishes no repository for. The tarball is fetched
# from the GitHub releases, and only its `bao` member is extracted into `bin_dir`.
#
# `version` pins a floor, not an exact release: the archive is only fetched when the
# installed binary is older, so a node already running a newer one is left alone.
# Downgrading means an exact `package_ensure` with `install_method => 'repo'`, see
# `server_pinned_version.pp`.
#
# The module grants `cap_ipc_lock=ep` to the extracted binary so OpenBao can lock its
# memory, pulling in the `file_capability` class for `setcap` on its own.

# Storage, listener and bin_dir keep their defaults: the file backend under
# /var/lib/openbao, a TLS-less loopback listener, and /usr/local/bin.
class { 'openbao':
  install_method => 'archive',
  version        => '2.6.1',
}
