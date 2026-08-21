# A single node server, with everything at its default.
#
# Installs the `openbao` package from the official repository, stores the data with the
# `file` backend under /var/lib/openbao, listens on 127.0.0.1:8200 without TLS, and
# starts the service.
#
# OpenBao then waits to be initialised, which this module deliberately does not do:
#
#   BAO_ADDR=http://127.0.0.1:8200 bao operator init

include openbao
