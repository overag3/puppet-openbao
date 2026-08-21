# An agent authenticating with AppRole and rendering secrets into configuration files.
#
# The agent logs in on its own with the role id and secret id found on disk, writes the
# resulting token to a sink, and keeps the templates in sync as the secrets rotate.
#
# `service_read_write_paths` is not optional here: the generated systemd unit sets
# `ProtectSystem=full`, which mounts /etc read-only, so every template destination
# outside /run/openbao has to be opened up explicitly.

class { 'openbao':
  mode                     => 'agent',
  agent_vault              => {
    'address' => 'https://openbao.example.com:8200',
    'retry'   => { 'num_retries' => 5 },
  },
  agent_auto_auth          => {
    'method' => {
      'type'   => 'approle',
      'config' => {
        'role_id_file_path'                   => '/etc/openbao/role-id',
        'secret_id_file_path'                 => '/etc/openbao/secret-id',
        'remove_secret_id_file_after_reading' => false,
      },
    },
    'sink'   => {
      'type'   => 'file',
      'config' => { 'path' => '/run/openbao/token' },
    },
  },
  agent_template           => [
    {
      'source'      => '/etc/openbao/app.ctmpl',
      'destination' => '/etc/app/secrets.ini',
      'perms'       => '0400',
    },
    {
      'source'      => '/etc/openbao/db.ctmpl',
      'destination' => '/etc/app/db.ini',
      'command'     => 'systemctl reload app',
    },
  ],
  agent_template_config    => {
    'exit_on_retry_failure'         => true,
    'static_secret_render_interval' => '5m',
  },
  service_read_write_paths => ['/etc/app'],
}
