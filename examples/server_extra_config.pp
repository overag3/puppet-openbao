# A server using the two escape hatches, for settings this module exposes no parameter
# for.
#
# `extra_config` is merged over the generated configuration, so it can add stanzas and
# override anything the parameters produced.
#
# `raw_config` is appended to the file verbatim. It is the only way to express a block
# carrying two labels, such as `plugin "secret" "aws" {}`, which the HCL renderer cannot
# build from a Hash. It is refused with `config_format => 'json'`, where appending text
# would corrupt the file.

class { 'openbao':
  storage      => {
    'raft' => { 'path' => '/var/lib/openbao' },
  },
  extra_config => {
    'user_lockout' => {
      'userpass' => {
        'lockout_threshold'     => 5,
        'lockout_duration'      => '10m',
        'lockout_counter_reset' => '10m',
      },
    },
  },
  raw_config   => @(HCL),
    plugin "secret" "aws" {
      image     = "ghcr.io/openbao/openbao-plugin-secrets-aws"
      version   = "v1.0.0"
      sha256sum = "9fdd8be7947e4a4caf7cce4f0e02695081b6c85178aa912df5d37be97363144c"
    }
    | HCL
}
