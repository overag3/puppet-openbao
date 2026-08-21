# A server reachable both over TCP and through a local unix socket.
#
# An Array of Hashes declares several listeners; a single Hash keyed by the listener type
# is the shortcut for just one. The socket lives in /run/openbao, which the generated
# systemd unit creates through `RuntimeDirectory=openbao`.

class { 'openbao':
  api_addr => "https://${facts['networking']['fqdn']}:8200",
  listener => [
    {
      'tcp' => {
        'address'       => '0.0.0.0:8200',
        'tls_cert_file' => '/etc/openbao/tls/tls.crt',
        'tls_key_file'  => '/etc/openbao/tls/tls.key',
      },
    },
    {
      'unix' => {
        'address' => '/run/openbao/bao.sock',
      },
    },
  ],
}
