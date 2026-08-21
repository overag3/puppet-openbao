# @summary Set up the official OpenBao package repository.
#
# The repositories are the ones advertised on https://openbao.org/downloads. No signing
# key is shipped with this module: by default both APT and YUM are pointed at the key
# published by OpenBao and fetch it themselves.
#
# The class stands on its own, so the repository can be configured without letting the
# `openbao` class manage the service.
#
# @param base_url
#   Base URL of the OpenBao package repositories.
# @param release
#   APT suite to use. `stable` for releases, `testing` for pre-releases.
# @param component
#   APT component to use.
# @param rpm_path
#   Path component of the RPM repository. `rpm` for releases, `rpm-testing` for
#   pre-releases.
# @param description
#   Human readable description of the repository.
# @param architecture
#   Architectures to restrict the APT source to. Left to APT by default.
# @param enabled
#   Whether the repository is enabled.
# @param apt_pin_priority
#   APT pin priority of the repository, written to `/etc/apt/preferences.d`. The highest
#   value wins, over a default of 500 for every available version, and 1000 is the
#   threshold above which APT also downgrades.
# @param yum_priority
#   Priority of the yum repository, written as a `priority` option in its `.repo` file.
#   The *lowest* value wins, on a 1-99 scale where every other repository sits at 99, and
#   same-named packages from the losing repositories are excluded outright.
# @param pin_originator
#   `Origin` value the APT pin matches. The default matches the Release file of the
#   official repository; override it together with `base_url` when pinning a mirror that
#   publishes a different `Origin`.
# @param metadata_expire
#   How long dnf considers the repository metadata fresh, in seconds. The default keeps
#   newly published releases visible quickly; raise it for slow or rate limited
#   mirrors. YUM only.
# @param proxy
#   HTTP proxy used to reach the repository. YUM only.
# @param sslcacert
#   Certificate authority dnf verifies the repository host against, for a mirror served
#   with a private CA. The file is expected to be deployed by other means. YUM only: APT
#   reads the system trust store.
# @param manage_gpgkey
#   Whether this module deploys the signing key of the repository. With `false` the key is
#   expected from elsewhere and verification stays on, so installs fail until it is there.
#   To skip verification instead, see `allow_unsigned`.
# @param allow_unsigned
#   Whether to accept packages without a valid signature (`Trusted: yes` on Debian,
#   `gpgcheck=0` on RedHat). Opting out of the chain of trust lets anyone able to tamper
#   with the transport install packages as root. Last resort only.
# @param gpgkey_source
#   Where to fetch the signing key from, as anything `Stdlib::Filesource` allows — an
#   internal mirror URL or a `puppet:///` source included. Ignored when `gpgkey_content`
#   is set.
# @param gpgkey_content
#   The ASCII armoured signing key itself, for hosts that cannot reach the key server.
#   Takes precedence over `gpgkey_source`.
# @param keyring_path
#   Where the signing key is written: the keyring referenced by `Signed-By:` on Debian,
#   and on RedHat a path only used for keys that are not an `http(s)` URL, dnf fetching
#   those itself.
#
class openbao::repo (
  Stdlib::Absolutepath $keyring_path,
  Stdlib::HTTPUrl $base_url                     = 'https://pkgs.openbao.org',
  String[1] $release                            = 'stable',
  String[1] $component                          = 'main',
  String[1] $rpm_path                           = 'rpm',
  String[1] $description                        = 'OpenBao package repository',
  Optional[Array[String[1], 1]] $architecture   = undef,
  Boolean $enabled                              = true,
  Integer $apt_pin_priority                     = 900,
  Integer[1, 99] $yum_priority                  = 10,
  String[1] $pin_originator                     = 'OpenBao - Official',
  String[1] $metadata_expire                    = '300',
  Optional[Stdlib::HTTPUrl] $proxy              = undef,
  Optional[Stdlib::Absolutepath] $sslcacert     = undef,
  Boolean $manage_gpgkey                        = true,
  Boolean $allow_unsigned                       = false,
  Stdlib::Filesource $gpgkey_source             = 'https://openbao.org/assets/openbao-gpg-pub-20240618.asc',
  Optional[String[1]] $gpgkey_content           = undef,
) {
  if $manage_gpgkey {
    # An inline key wins over a key to fetch, so that setting only one of the two
    # parameters is enough.
    if $gpgkey_content {
      $key_content = $gpgkey_content
      $key_source = undef
    } else {
      $key_content = undef
      $key_source = $gpgkey_source
    }
  } else {
    $key_content = undef
    $key_source = undef
  }

  case $facts['os']['family'] {
    'Debian': {
      # apt::source only notifies Class['apt::update'], which orders nothing relative to
      # package installs. apt::update is private and cannot be contained, so an anchor
      # brings it inside this class and `require => Class['openbao::repo']` is enough.
      # lint:ignore:anchor_resource
      anchor { 'openbao::repo::apt_update': }
      # lint:endignore
      Class['apt::update'] -> Anchor['openbao::repo::apt_update']

      # apt::source ignores its own `key` parameter in deb822 mode, where the keyring is
      # referenced by path.
      if $manage_gpgkey {
        apt::keyring { basename($keyring_path):
          dir     => dirname($keyring_path),
          source  => $key_source,
          content => $key_content,
          before  => Apt::Source['openbao'],
        }

        $keyring = $keyring_path
      } else {
        $keyring = undef
      }

      # Careful: `false` writes `Trusted: no`, which marks every package as
      # unauthenticated. Only `undef` keeps the apt default of enforcing signatures.
      $apt_allow_unsigned = $allow_unsigned ? {
        true    => true,
        default => undef,
      }

      # apt::source ignores its own `pin` parameter in deb822 mode.
      apt::pin { 'openbao':
        originator => $pin_originator,
        priority   => $apt_pin_priority,
        before     => Apt::Source['openbao'],
      }

      apt::source { 'openbao':
        # deb822 format, as documented upstream, which wants arrays
        source_format  => 'sources',
        comment        => $description,
        location       => ["${base_url}/deb/"],
        release        => [$release],
        repos          => [$component],
        architecture   => $architecture,
        enabled        => $enabled,
        keyring        => $keyring,
        allow_unsigned => $apt_allow_unsigned,
      }
    }

    'RedHat': {
      if $key_source =~ Stdlib::HTTPUrl {
        # dnf downloads and imports the key itself
        $gpgkey = $key_source
      } elsif $manage_gpgkey {
        file { $keyring_path:
          ensure  => file,
          owner   => 'root',
          group   => 'root',
          mode    => '0644',
          source  => $key_source,
          content => $key_content,
          before  => Yumrepo['openbao'],
        }

        $gpgkey = "file://${keyring_path}"
      } else {
        $gpgkey = undef
      }

      yumrepo { 'openbao':
        descr           => $description,
        baseurl         => "${base_url}/${rpm_path}/\$basearch",
        enabled         => bool2num($enabled),
        gpgcheck        => bool2num(!$allow_unsigned),
        repo_gpgcheck   => 0,
        gpgkey          => $gpgkey,
        priority        => $yum_priority,
        proxy           => $proxy,
        metadata_expire => $metadata_expire,
        sslverify       => 1,
        sslcacert       => $sslcacert,
      }
      # A repository whose definition changed must not keep serving packages from the
      # metadata of the previous one until metadata_expire elapses.
      ~> exec { 'openbao_yumrepo_clean':
        command     => 'dnf clean metadata --disablerepo="*" --enablerepo="openbao"',
        refreshonly => true,
        returns     => [0, 1],
        path        => ['/bin', '/usr/bin'],
        cwd         => '/',
      }
    }

    default: {
      fail("openbao: no OpenBao package repository is available for ${facts['os']['family']}, use install_method => 'archive'")
    }
  }
}
