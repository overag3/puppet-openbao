# An agent acting as a local caching proxy in front of a remote OpenBao server.
#
# Applications on the node talk to http://127.0.0.1:8100 without holding any credential
# of their own: the agent authenticates once, caches the leases, and attaches its own
# token to the requests it forwards.
#
# An empty `agent_cache` Hash is enough to turn caching on — the stanza only needs to
# exist. The listener is what actually exposes the proxy.

class { 'openbao':
  mode            => 'agent',
  agent_vault     => {
    'address' => 'https://openbao.example.com:8200',
  },
  agent_auto_auth => {
    'method' => {
      'type'   => 'approle',
      'config' => {
        'role_id_file_path'   => '/etc/openbao/role-id',
        'secret_id_file_path' => '/etc/openbao/secret-id',
      },
    },
    'sink'   => {
      'type'   => 'file',
      'config' => { 'path' => '/run/openbao/token' },
    },
  },
  agent_cache     => {},
  agent_api_proxy => {
    'use_auto_auth_token' => true,
  },
  agent_listener  => {
    'tcp' => {
      'address'     => '127.0.0.1:8100',
      'tls_disable' => true,
    },
  },
}
