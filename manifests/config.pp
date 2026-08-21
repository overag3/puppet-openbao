# @summary Render the OpenBao configuration, environment file and systemd unit.
#
# @api private
#
class openbao::config {
  assert_private()

  if $openbao::manage_config_dir {
    # Owned by root so that the service reads its configuration through the group but
    # never rewrites it.
    file { $openbao::config_dir:
      ensure  => directory,
      owner   => 'root',
      group   => $openbao::group,
      mode    => '0750',
      purge   => $openbao::purge_config_dir,
      recurse => $openbao::purge_config_dir,
    }
  }

  # Options OpenBao accepts in both modes, merged with the mode specific ones below.
  $common_config = {
    'pid_file'             => $openbao::pid_file,
    'log_level'            => $openbao::log_level,
    'log_format'           => $openbao::log_format,
    'log_file'             => $openbao::log_file,
    'log_rotate_duration'  => $openbao::log_rotate_duration,
    'log_rotate_bytes'     => $openbao::log_rotate_bytes,
    'log_rotate_max_files' => $openbao::log_rotate_max_files,
  }

  case $openbao::mode {
    'server': {
      $mode_config = {
        'ui'                           => $openbao::enable_ui,
        'cluster_name'                 => $openbao::cluster_name,
        'api_addr'                     => $openbao::api_addr,
        'cluster_addr'                 => $openbao::cluster_addr,
        'disable_mlock'                => $openbao::disable_mlock,
        'disable_cache'                => $openbao::disable_cache,
        'default_lease_ttl'            => $openbao::default_lease_ttl,
        'max_lease_ttl'                => $openbao::max_lease_ttl,
        'default_max_request_duration' => $openbao::default_max_request_duration,
        'plugin_directory'             => $openbao::plugin_directory,
        'plugin_file_uid'              => $openbao::plugin_file_uid,
        'plugin_file_permissions'      => $openbao::plugin_file_permissions,
        'raw_storage_endpoint'         => $openbao::raw_storage_endpoint,
        'introspection_endpoint'       => $openbao::introspection_endpoint,
        'storage'                      => $openbao::storage,
        'ha_storage'                   => $openbao::ha_storage,
        'listener'                     => $openbao::listener,
        'seal'                         => $openbao::seal,
        'telemetry'                    => $openbao::telemetry,
        'service_registration'         => $openbao::service_registration,
      }
    }

    'agent': {
      $mode_config = {
        'disable_idle_connections' => $openbao::agent_disable_idle_connections,
        'disable_keep_alives'      => $openbao::agent_disable_keep_alives,
        'vault'                    => $openbao::agent_vault,
        'auto_auth'                => $openbao::agent_auto_auth,
        'api_proxy'                => $openbao::agent_api_proxy,
        'cache'                    => $openbao::agent_cache,
        'listener'                 => $openbao::agent_listener,
        'template'                 => $openbao::agent_template,
        'template_config'          => $openbao::agent_template_config,
        'exec'                     => $openbao::agent_exec,
        'env_template'             => $openbao::agent_env_template,
        'telemetry'                => $openbao::agent_telemetry,
      }
    }

    default: {
      fail("openbao: unsupported mode ${openbao::mode}")
    }
  }

  # The effective configuration, also consulted by the storage directory handling below.
  # The scrub is recursive: a `null` left inside a stanza makes OpenBao refuse to start.
  $config = openbao::compact($common_config + $mode_config + $openbao::extra_config)

  if $openbao::manage_config_file {
    if $openbao::mode == 'agent' and !('vault' in $config) {
      fail('openbao: agent mode requires agent_vault (or a "vault" key in extra_config)')
    }

    if $openbao::raw_config and $openbao::config_format == 'json' {
      fail('openbao: raw_config would corrupt a JSON configuration file, use config_format => "hcl"')
    }

    $rendered_config = $openbao::config_format ? {
      'json'  => stdlib::to_json_pretty($config),
      default => openbao::to_hcl($config),
    }

    $config_content = $openbao::raw_config ? {
      undef   => $rendered_config,
      default => "${rendered_config}\n${openbao::raw_config}\n",
    }

    # Sensitive keeps the rendered secrets out of the logs, the reports, the diffs and
    # the provider's own error messages.
    file { $openbao::config_file:
      ensure  => file,
      owner   => 'root',
      group   => $openbao::group,
      mode    => $openbao::config_mode,
      content => Sensitive($config_content),
    }
  }

  if $openbao::manage_environment_file {
    # The values are double-quoted to survive systemd's EnvironmentFile parsing; a
    # newline would smuggle extra lines into the file, hence the hard failure.
    # openbao::compact unwraps Sensitive values, which the renderers would otherwise
    # write as the "Sensitive [value redacted]" placeholder.
    $environment_content = openbao::compact($openbao::environment_variables).map |$key, $value| {
      $string_value = String($value)

      if "\n" in $string_value {
        fail("openbao: the value of environment variable ${key} must not contain a newline")
      }

      $escaped_value = regsubst($string_value, /(["\\])/, '\\\\\0', 'G')
      "${key}=\"${escaped_value}\""
    }.join("\n")

    file { $openbao::environment_file:
      ensure  => file,
      owner   => 'root',
      group   => $openbao::group,
      mode    => '0640',
      content => Sensitive("# This file is managed by Puppet\n${environment_content}\n"),
    }
  }

  # The storage directory holds the encrypted data and has to be writable by the OpenBao
  # user. It is read from the merged configuration, so an extra_config override drives
  # the directory handling as well.
  if $openbao::mode == 'server' and $openbao::manage_storage_dir {
    $storage_config = pick_default($config['storage'], {})

    # Only the file and raft backends keep data on the node; the others are left alone.
    if 'file' in $storage_config {
      $storage_backend = 'file'
    } elsif 'raft' in $storage_config {
      $storage_backend = 'raft'
    } else {
      $storage_backend = undef
    }

    if $storage_backend {
      $storage_path = $storage_config[$storage_backend]['path']

      unless $storage_path {
        fail("openbao: the ${storage_backend} storage backend needs a path attribute")
      }

      file { $storage_path:
        ensure => directory,
        owner  => $openbao::user,
        group  => $openbao::group,
        mode   => '0700',
      }
    }
  }

  if $openbao::manage_service_file {
    $unit_environment_file = $openbao::manage_environment_file ? {
      true    => $openbao::environment_file,
      default => undef,
    }

    $unit_parameters = {
      'mode'              => $openbao::mode,
      'binary'            => $openbao::openbao_binary,
      'config_file'       => $openbao::config_file,
      'user'              => $openbao::user,
      'group'             => $openbao::group,
      'environment_file'  => $unit_environment_file,
      'read_write_paths'  => $openbao::service_read_write_paths,
      'runtime_directory' => $openbao::service_name,
      'mlock_enabled'     => !$openbao::disable_mlock,
      'num_procs'         => $openbao::num_procs,
      'service_options'   => $openbao::service_options,
    }

    case $openbao::service_provider {
      'systemd', undef: {
        systemd::unit_file { "${openbao::service_name}.service":
          content => epp('openbao/openbao.service.epp', $unit_parameters),
        }
      }

      default: {
        fail("openbao: manage_service_file is only supported with systemd, not ${openbao::service_provider}")
      }
    }
  }
}
