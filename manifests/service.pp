# @summary Manage the OpenBao service.
#
# @api private
#
class openbao::service {
  assert_private()

  if $openbao::manage_service {
    service { $openbao::service_name:
      ensure   => $openbao::service_ensure,
      enable   => $openbao::service_enable,
      provider => $openbao::service_provider,
    }
  }
}
