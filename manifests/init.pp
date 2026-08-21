# @summary Install and configure OpenBao, in `server` or `agent` mode.
#
# @param mode
#   Whether to run OpenBao as a `server` or as an `agent`. This selects both the
#   generated configuration layout and the subcommand used by the systemd unit.
# @param version
#   Version of OpenBao to install, as upstream numbers its releases and without the `v`
#   the tags carry. Builds the download URL of `install_method => 'archive'`, and drives
#   its upgrades through the `openbao_version` fact. A pre-release suffix is accepted and
#   counts as older than the final release of the same number.
# @param user
#   User the OpenBao process runs as.
# @param manage_user
#   Whether this module should create `user`. Note that the official packages already
#   create the `openbao` user in their `preinst` script.
# @param group
#   Group the OpenBao process runs as.
# @param manage_group
#   Whether this module should create `group`.
# @param install_method
#   How to install OpenBao. `repo` installs the `openbao` package from the official
#   OpenBao package repositories (see `openbao::repo`), `archive` downloads the release
#   tarball from GitHub and extracts the `bao` binary into `bin_dir`.
# @param manage_package
#   Whether this module installs OpenBao at all. Set to `false` when the binary is
#   provided by other means; `openbao::install` then only manages the user and group.
# @param package_name
#   Name of the package to install. Use `openbao-hsm` for the HSM/PKCS#11 flavour.
# @param package_ensure
#   `ensure` value for the package. Set it to a version string (for example `2.6.1`) to
#   pin a release; the repository keeps every published version.
# @param bin_dir
#   Directory holding the OpenBao binary. Defaults to `/usr/local/bin` for archive
#   installs and to `/usr/bin` (where the packages put it) otherwise.
# @param bin_name
#   Name of the OpenBao binary. `install_method => 'archive'` extracts the `bao` member
#   of the upstream tarball and therefore requires the default.
# @param manage_repo
#   Whether to configure the official OpenBao package repository, through the
#   `openbao::repo` class, whose own parameters tune it. Only relevant when
#   `install_method` is `repo`.
# @param download_url
#   Full URL of the release archive, overriding the URL computed from `version`.
# @param download_url_base
#   Base URL the release archive is downloaded from.
# @param download_checksum
#   Checksum of the release archive, verified after the download, and `undef` to skip the
#   verification. Copy it from the `openbao_<version>_<os>_<arch>.tar.gz` line of the
#   `checksums.txt` upstream publishes per release — it therefore assumes a pinned
#   `version`, and a value per architecture on a mixed estate.
# @param download_checksum_type
#   Digest `download_checksum` is expressed in.
# @param download_extension
#   Extension of the release archive. Only `tar.gz` and `tgz` are accepted — what
#   upstream publishes; zip is refused because `unzip` cannot replace a running binary
#   on upgrades.
# @param download_dir
#   Directory the release archive is downloaded into.
# @param manage_download_dir
#   Whether to create `download_dir`.
# @param os
#   Operating system part of the release archive name. Derived from the `kernel` fact.
# @param manage_file_capabilities
#   Whether to grant `cap_ipc_lock=ep` to the binary so that OpenBao can `mlock` its
#   memory, which pulls in the `file_capability` class for `setcap`. On by default for
#   managed archive installs only, and ignored when `disable_mlock` is true.
# @param config_format
#   Format of the generated configuration file, `hcl` or `json`. Both are understood by
#   OpenBao; `json` is a safe choice for deeply nested or unusual structures.
# @param config_dir
#   Directory holding the OpenBao configuration.
# @param config_filename
#   Name of the generated configuration file.
# @param config_mode
#   Mode of the generated configuration file.
# @param manage_config_dir
#   Whether to manage `config_dir`.
# @param manage_config_file
#   Whether to generate the configuration file.
# @param purge_config_dir
#   Whether to remove unmanaged files from `config_dir`. Off by default: the packages
#   ship files there. Purging implies recursion, which applies the directory owner, group
#   and mode to every file below, so keep TLS material outside of `config_dir`.
# @param extra_config
#   Additional configuration, for stanzas this module does not expose as a parameter. The
#   merge is top level only: a key of the same name replaces the generated stanza
#   outright instead of adding to it, so restate the whole stanza.
# @param raw_config
#   Raw configuration appended verbatim at the end of the file. Only allowed with
#   `config_format => 'hcl'` (it would corrupt a JSON file), for constructs the HCL
#   renderer cannot express (such as the two-label `plugin "secret" "aws" {}` block).
# @param manage_environment_file
#   Whether to manage the environment file read by the systemd unit.
# @param environment_file
#   Path of the environment file.
# @param environment_variables
#   Variables written to `environment_file`, for `BAO_*` settings or the credentials of an
#   auto-unseal backend — hence values may be `Sensitive`, and are unwrapped on the way to
#   the file. They are double-quoted there; newlines are refused.
# @param listener
#   Server mode. `listener` stanza(s). A Hash is a single listener keyed by its type, an
#   Array of Hashes declares several of them.
# @param storage
#   Server mode. `storage` stanza, keyed by backend type.
# @param manage_storage_dir
#   Server mode. Whether to create the directory referenced by the `file` or `raft`
#   storage backend. The parent directory must already exist. Backends that keep no
#   local data are simply left alone.
# @param ha_storage
#   Server mode. `ha_storage` stanza, keyed by backend type.
# @param seal
#   Server mode. `seal` stanza, keyed by seal type, for auto-unsealing.
# @param telemetry
#   Server mode. `telemetry` stanza.
# @param service_registration
#   Server mode. `service_registration` stanza, keyed by provider.
# @param enable_ui
#   Server mode. Whether to serve the web UI (`ui`).
# @param api_addr
#   Server mode. Full URL advertised to clients for request forwarding.
# @param cluster_addr
#   Server mode. Full URL advertised to other nodes for cluster traffic.
# @param cluster_name
#   Server mode. Identifier for the cluster.
# @param disable_mlock
#   Server mode. Whether to disable the memory lock. Required for the `raft` backend on
#   some platforms; also drives the capability handling described in
#   `manage_file_capabilities`.
# @param disable_cache
#   Server mode. Whether to disable all caches.
# @param default_lease_ttl
#   Server mode. Default lease duration for tokens and secrets.
# @param max_lease_ttl
#   Server mode. Maximum lease duration for tokens and secrets.
# @param default_max_request_duration
#   Server mode. Maximum request duration before cancellation.
# @param plugin_directory
#   Server mode. Directory external plugins are loaded from.
# @param plugin_file_uid
#   Server mode. Expected owner UID of the plugin directory and its contents.
# @param plugin_file_permissions
#   Server mode. Expected permissions of the plugin directory and its contents.
# @param log_level
#   Log verbosity, one of `trace`, `debug`, `info`, `warn` or `error`.
# @param log_format
#   Log format, `standard` or `json`.
# @param log_file
#   Path OpenBao writes its log to, in addition to standard output.
# @param log_rotate_duration
#   How often the log file is rotated.
# @param log_rotate_bytes
#   Size after which the log file is rotated.
# @param log_rotate_max_files
#   Number of rotated log files to keep.
# @param pid_file
#   Path of the PID file, in both modes.
# @param raw_storage_endpoint
#   Server mode. Whether to enable the `sys/raw` endpoint.
# @param introspection_endpoint
#   Server mode. Whether to enable the `sys/internal/inspect` endpoint.
# @param agent_vault
#   Agent mode. `vault` stanza describing how to reach the OpenBao server. Required in
#   agent mode unless supplied through `extra_config`.
# @param agent_auto_auth
#   Agent mode. `auto_auth` stanza with its `method` and `sink` blocks.
# @param agent_api_proxy
#   Agent mode. `api_proxy` stanza.
# @param agent_cache
#   Agent mode. `cache` stanza. An empty Hash is enough to enable caching.
# @param agent_listener
#   Agent mode. `listener` stanza(s), same shape as the server `listener` parameter.
# @param agent_template
#   Agent mode. `template` stanza(s). An Array declares several templates.
# @param agent_template_config
#   Agent mode. `template_config` stanza, tuning the template engine globally.
# @param agent_exec
#   Agent mode. `exec` stanza, for running a child process with rendered secrets.
# @param agent_env_template
#   Agent mode. `env_template` stanza(s), keyed by environment variable name.
# @param agent_telemetry
#   Agent mode. `telemetry` stanza.
# @param agent_disable_idle_connections
#   Agent mode. Features for which idle connection pooling is disabled.
# @param agent_disable_keep_alives
#   Agent mode. Features for which HTTP keep-alives are disabled.
# @param service_name
#   Name of the systemd service, in both modes.
# @param manage_service
#   Whether to manage the service resource.
# @param restart_on_change
#   Whether a changed configuration, environment file, systemd unit or binary restarts the
#   service. On by default; set it to `false` on servers without auto-unseal, where a
#   restart leaves OpenBao sealed until an operator unseals it.
# @param service_ensure
#   Desired state of the service.
# @param service_enable
#   Whether the service starts at boot.
# @param service_provider
#   Service provider to use.
# @param manage_service_file
#   Whether to write the systemd unit, in `/etc/systemd/system` where it takes precedence
#   over the packaged one. On by default: the packaged unit hardcodes
#   `bao server -config=/etc/openbao/openbao.hcl`, wrong in agent mode and on any other
#   configuration path.
# @param service_options
#   Extra command line arguments appended to `bao <mode>`.
# @param service_read_write_paths
#   Paths added to the `ReadWritePaths=` directive of the unit, needed for anything
#   OpenBao writes outside of `/run/<service_name>` and the storage directory — agent
#   template destinations in particular, `ProtectSystem=full` mounting `/etc` read-only.
# @param num_procs
#   Value of `GOMAXPROCS` in the unit, limiting how many CPUs OpenBao uses.
#
class openbao (
  # Generic
  Enum['server', 'agent'] $mode                                   = 'server',
  Pattern[/\A\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?\z/] $version         = '2.6.1',
  String[1] $user                                                 = 'openbao',
  Boolean $manage_user                                            = true,
  String[1] $group                                                = 'openbao',
  Boolean $manage_group                                           = true,

  # Installation
  Enum['repo', 'archive'] $install_method                         = 'repo',
  Boolean $manage_package                                         = true,
  String[1] $package_name                                         = 'openbao',
  String[1] $package_ensure                                       = 'installed',
  Stdlib::Absolutepath $bin_dir                                   = $install_method ? {
    'archive' => '/usr/local/bin',
    default   => '/usr/bin',
  },
  String[1] $bin_name                                             = 'bao',
  Boolean $manage_repo                                            = true,
  Optional[Stdlib::HTTPUrl] $download_url                         = undef,
  Stdlib::HTTPUrl $download_url_base                              = 'https://github.com/openbao/openbao/releases/download/',
  Optional[String[1]] $download_checksum                          = undef,
  Enum['sha256', 'sha512'] $download_checksum_type                = 'sha256',
  Enum['tar.gz', 'tgz'] $download_extension                       = 'tar.gz',
  Stdlib::Absolutepath $download_dir                              = '/tmp',
  Boolean $manage_download_dir                                    = false,
  String[1] $os                                                   = downcase($facts['kernel']),
  Boolean $manage_file_capabilities                               = ($manage_package and $install_method == 'archive'),

  # Configuration
  Enum['hcl', 'json'] $config_format                              = 'hcl',
  Stdlib::Absolutepath $config_dir                                = '/etc/openbao',
  String[1] $config_filename                                      = "openbao.${config_format}",
  Stdlib::Filemode $config_mode                                   = '0640',
  Boolean $manage_config_dir                                      = true,
  Boolean $manage_config_file                                     = true,
  Boolean $purge_config_dir                                       = false,
  Hash $extra_config                                              = {},
  Optional[String[1]] $raw_config                                 = undef,
  Boolean $manage_environment_file                                = true,
  Stdlib::Absolutepath $environment_file                          = "${config_dir}/openbao.env",
  Hash[String[1], Variant[String, Integer, Boolean, Sensitive[String]]] $environment_variables = {},

  # Server configuration
  Variant[Hash, Array[Hash]] $listener                            = {
    'tcp' => { 'address' => '127.0.0.1:8200', 'tls_disable' => true },
  },
  Hash $storage                                                   = {
    'file' => { 'path' => '/var/lib/openbao' },
  },
  Boolean $manage_storage_dir                                     = true,
  Optional[Hash] $ha_storage                                      = undef,
  Optional[Hash] $seal                                            = undef,
  Optional[Hash] $telemetry                                       = undef,
  Optional[Hash] $service_registration                            = undef,
  Optional[Boolean] $enable_ui                                    = undef,
  Optional[Stdlib::HTTPUrl] $api_addr                             = undef,
  Optional[Stdlib::HTTPUrl] $cluster_addr                         = undef,
  Optional[String[1]] $cluster_name                               = undef,
  Optional[Boolean] $disable_mlock                                = undef,
  Optional[Boolean] $disable_cache                                = undef,
  Optional[String[1]] $default_lease_ttl                          = undef,
  Optional[String[1]] $max_lease_ttl                              = undef,
  Optional[String[1]] $default_max_request_duration               = undef,
  Optional[Stdlib::Absolutepath] $plugin_directory                = undef,
  Optional[Integer] $plugin_file_uid                              = undef,
  Optional[String[1]] $plugin_file_permissions                    = undef,
  Optional[Enum['trace', 'debug', 'info', 'warn', 'error']] $log_level = undef,
  Optional[Enum['standard', 'json']] $log_format                  = undef,
  Optional[Stdlib::Absolutepath] $log_file                        = undef,
  Optional[String[1]] $log_rotate_duration                        = undef,
  Optional[Integer] $log_rotate_bytes                             = undef,
  Optional[Integer] $log_rotate_max_files                         = undef,
  Optional[Stdlib::Absolutepath] $pid_file                        = undef,
  Optional[Boolean] $raw_storage_endpoint                         = undef,
  Optional[Boolean] $introspection_endpoint                       = undef,

  # Agent configuration
  Optional[Hash] $agent_vault                                     = undef,
  Optional[Hash] $agent_auto_auth                                 = undef,
  Optional[Hash] $agent_api_proxy                                 = undef,
  Optional[Hash] $agent_cache                                     = undef,
  Optional[Variant[Hash, Array[Hash]]] $agent_listener            = undef,
  Optional[Variant[Hash, Array[Hash]]] $agent_template            = undef,
  Optional[Hash] $agent_template_config                           = undef,
  Optional[Hash] $agent_exec                                      = undef,
  Optional[Hash] $agent_env_template                              = undef,
  Optional[Hash] $agent_telemetry                                 = undef,
  Optional[Array[String[1]]] $agent_disable_idle_connections      = undef,
  Optional[Array[String[1]]] $agent_disable_keep_alives           = undef,

  # Service
  String[1] $service_name                                         = 'openbao',
  Boolean $manage_service                                         = true,
  Boolean $restart_on_change                                      = true,
  Stdlib::Ensure::Service $service_ensure                         = 'running',
  Boolean $service_enable                                         = true,
  Optional[String[1]] $service_provider                           = $facts['service_provider'],
  Boolean $manage_service_file                                    = true,
  Optional[String[1]] $service_options                            = undef,
  Array[Stdlib::Absolutepath] $service_read_write_paths           = [],
  Integer[1] $num_procs                                           = pick($facts.dig('processors', 'count'), 1),
) {
  $config_file = "${config_dir}/${config_filename}"
  $openbao_binary = "${bin_dir}/${bin_name}"

  contain openbao::install
  contain openbao::config
  contain openbao::service

  Class['openbao::install']
  -> Class['openbao::config']
  -> Class['openbao::service']

  # A changed configuration and a new binary (package upgrade or archive download) have
  # to restart the service, or the old release and configuration would keep running. A
  # server without auto-unseal comes back sealed, hence the restart_on_change opt-out.
  if $restart_on_change {
    Class['openbao::config'] ~> Class['openbao::service']
    Class['openbao::install'] ~> Class['openbao::service']
  }

  if $install_method == 'repo' and $manage_repo {
    contain openbao::repo
    Class['openbao::repo'] -> Class['openbao::install']
  }
}
