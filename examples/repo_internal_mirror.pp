# A repository mirrored inside the perimeter, for nodes with no direct internet access.
#
# `base_url` replaces the host but keeps the layout, so the mirror is expected to expose
# `<base_url>/deb/` and `<base_url>/<rpm_path>/$basearch` exactly like the upstream one.
#
# The signing key is served from the Puppet master rather than fetched from openbao.org;
# anything `Stdlib::Filesource` accepts works here. Where it lands is `keyring_path`,
# which already defaults per OS family.

# A mirror served with a certificate from a private CA needs `sslcacert` on the RedHat
# side, pointing at a file deployed by other means. APT has no equivalent parameter: it
# reads the system trust store, which the same profile is expected to have populated.

class { 'openbao::repo':
  base_url      => 'https://mirror.example.com/openbao',
  gpgkey_source => 'puppet:///modules/profile/openbao-gpg-pub-20240618.asc',
  description   => 'OpenBao package repository (internal mirror)',
  sslcacert     => '/etc/pki/ca-trust/source/anchors/example-root-ca.crt',
}
