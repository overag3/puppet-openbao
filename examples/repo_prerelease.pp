# Following the pre-release channel instead of the stable one.
#
# `release` names the APT suite and `rpm_path` the RPM directory; both move together, a
# node being either on one channel or the other. These are the names OpenBao's own
# downloads page generates for a pre-release version.
#
# The channel only exists while a pre-release is actually published — otherwise both
# paths are absent and apt or dnf fails to reach the repository.

class { 'openbao::repo':
  release  => 'testing',
  rpm_path => 'rpm-testing',
}
