# @summary Create the OpenBao user and group and install the OpenBao binary.
#
# @api private
#
class openbao::install {
  assert_private()

  if $openbao::manage_group {
    group { $openbao::group:
      ensure => present,
      system => true,
    }
  }

  if $openbao::manage_user {
    user { $openbao::user:
      ensure => present,
      system => true,
      gid    => $openbao::group,
      shell  => '/bin/false',
    }

    if $openbao::manage_group {
      Group[$openbao::group] -> User[$openbao::user]
    }
  }

  if $openbao::manage_package {
    case $openbao::install_method {
      'repo': {
        package { $openbao::package_name:
          ensure => $openbao::package_ensure,
        }
      }

      'archive': {
        # Only the `bao` member of the upstream tarball can be extracted; renaming the
        # binary stays available with manage_package => false.
        if $openbao::bin_name != 'bao' {
          fail("openbao: install_method 'archive' extracts the 'bao' member of the upstream tarball, so bin_name cannot be '${openbao::bin_name}'")
        }

        if $openbao::download_url {
          $real_download_url = $openbao::download_url
        } else {
          # Architecture as it appears in the release archive names. Only the computed
          # URL needs it, so other architectures still work through download_url.
          case $facts['os']['architecture'] {
            /^(x86_64|amd64)$/:  { $arch = 'amd64' }
            /^(aarch64|arm64)$/: { $arch = 'arm64' }
            default:             { fail("openbao: unsupported architecture ${facts['os']['architecture']}") }
          }

          $real_download_url = "${openbao::download_url_base}v${openbao::version}/${openbao::package_name}_${openbao::version}_${openbao::os}_${arch}.${openbao::download_extension}"
        }

        # Only an installed binary older than the requested version clears `creates` and
        # triggers the download. The comparison follows semantic versioning, so a
        # pre-release is upgraded to its final release.
        $archive_creates = if $facts['openbao_version'] and SemVer($facts['openbao_version']) < SemVer($openbao::version) {
          undef
        } else {
          $openbao::openbao_binary
        }

        if $openbao::manage_download_dir {
          file { $openbao::download_dir:
            ensure => directory,
          }
        }

        # Only the binary is extracted; the tarball also holds CHANGELOG.md, LICENSE and
        # README.md. --unlink-first lets tar replace a running binary, which truncating
        # in place would refuse with "Text file busy". checksum_verify already defaults
        # to true, so an undef checksum is what turns the verification off.
        archive { "${openbao::download_dir}/${basename($real_download_url)}":
          ensure          => present,
          source          => $real_download_url,
          checksum        => $openbao::download_checksum,
          checksum_type   => $openbao::download_checksum_type,
          extract         => true,
          extract_path    => $openbao::bin_dir,
          extract_command => "tar xzf %s --unlink-first ${openbao::bin_name}",
          creates         => $archive_creates,
          cleanup         => true,
          before          => File['openbao_binary'],
        }

        file { 'openbao_binary':
          path  => $openbao::openbao_binary,
          owner => 'root',
          group => 'root',
          mode  => '0755',
        }
      }

      default: {
        fail("openbao: unsupported install_method ${openbao::install_method}")
      }
    }
  }

  # Points the openbao_version fact at the managed binary rather than at the first `bao`
  # in the agent's PATH. Only an archive install has one of its own, and the file goes
  # with it, or the fact would outlive the binary it describes.
  file { '/opt/puppetlabs/facter/facts.d/openbao_bin_path.txt':
    ensure  => ($openbao::manage_package and $openbao::install_method == 'archive') ? {
      true    => file,
      default => absent,
    },
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "openbao_bin_path=${openbao::openbao_binary}\n",
  }

  # OpenBao locks its memory unless disable_mlock is set, which needs CAP_IPC_LOCK. The
  # packaged systemd unit does not grant it, hence the default of
  # manage_file_capabilities.
  if $openbao::manage_file_capabilities and !$openbao::disable_mlock {
    # Provides setcap, and orders itself before every File_capability resource.
    include file_capability

    file_capability { 'openbao_binary_capability':
      ensure     => present,
      file       => $openbao::openbao_binary,
      capability => 'cap_ipc_lock=ep',
    }

    if $openbao::manage_package {
      case $openbao::install_method {
        'repo':  { Package[$openbao::package_name] ~> File_capability['openbao_binary_capability'] }
        default: { File['openbao_binary'] ~> File_capability['openbao_binary_capability'] }
      }
    }
  }
}
