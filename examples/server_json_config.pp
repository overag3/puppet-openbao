# A server whose configuration is written as JSON rather than HCL.
#
# OpenBao understands both. HCL is the default and reads better; JSON is the safe choice
# for deeply nested or unusual structures, since it needs no interpretation of what is a
# block and what is an attribute.
#
# The file is named after the format, so this one lands in /etc/openbao/openbao.json and
# the generated systemd unit points at it.

class { 'openbao':
  config_format => 'json',
  enable_ui     => true,
}
