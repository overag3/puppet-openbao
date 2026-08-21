# The package repository on its own, with everything at its default.
#
# `openbao::repo` configures the APT or YUM repository and installs nothing. Use it when
# something else in your codebase owns the packages — a profile that pins versions, an
# image build, or a node that only needs the client.
#
# The signing key is not shipped with this module: APT and DNF are pointed at the key
# published by OpenBao and fetch it themselves.

include openbao::repo
