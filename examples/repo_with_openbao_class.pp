# Tuning the repository while the `openbao` class still manages the service.
#
# The `openbao` class contains `openbao::repo` and orders it before the installation, so
# only its defaults need overriding. Hiera is the way to do that:
#
#   openbao::repo::release: 'testing'
#   openbao::repo::rpm_path: 'rpm-testing'
#   openbao::repo::apt_pin_priority: 990
#
# The resource-like declaration below does the same without Hiera, but only because it is
# evaluated before the `openbao` class; across two classes it is a duplicate declaration
# error. Adding `Class['openbao::repo'] -> Class['openbao']` would be a dependency cycle,
# the class already ordering the two internally.

class { 'openbao::repo':
  apt_pin_priority => 990,
}

include openbao
