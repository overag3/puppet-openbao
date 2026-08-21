# A node of a Raft cluster, listening with TLS and unsealed automatically by AWS KMS.
#
# Every node of the cluster gets this same manifest; `node_id` and the advertised
# addresses are what tell them apart. The first node still has to be initialised, and the
# others joined to it, with `bao operator raft join`.
#
# The TLS material is expected to be provisioned separately, outside of `config_dir`:
# `purge_config_dir` is off here, but the module would otherwise recurse into that
# directory and rewrite the permissions of the key.

class { 'openbao':
  api_addr              => "https://${facts['networking']['fqdn']}:8200",
  cluster_addr          => "https://${facts['networking']['fqdn']}:8201",
  enable_ui             => true,
  # Raft keeps its data in a memory mapped file, which does not go well with mlock
  disable_mlock         => true,
  storage               => {
    'raft' => {
      'path'    => '/var/lib/openbao',
      'node_id' => $facts['networking']['hostname'],
    },
  },
  listener              => {
    'tcp' => {
      'address'       => '0.0.0.0:8200',
      'tls_cert_file' => '/etc/openbao/tls/tls.crt',
      'tls_key_file'  => '/etc/openbao/tls/tls.key',
    },
  },
  seal                  => {
    'awskms' => {
      'region'     => 'eu-west-1',
      'kms_key_id' => 'alias/openbao-unseal',
    },
  },
  telemetry             => {
    'prometheus_retention_time' => '30s',
    'disable_hostname'          => true,
  },
  # Read by the systemd unit, so the seal can pick up its credentials
  environment_variables => {
    'AWS_ROLE_ARN' => 'arn:aws:iam::123456789012:role/openbao-unseal',
  },
}
