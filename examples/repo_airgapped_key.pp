# A node that cannot reach the key server at all.
#
# `gpgkey_content` carries the ASCII armoured key itself and takes precedence over
# `gpgkey_source`, so only one of the two ever needs to be set. It is written to the
# `Signed-By:` keyring on Debian, and referenced as a `file://` URL on RedHat.
#
# The heredoc below keeps the example self-contained; in a real codebase the key belongs
# in a profile module or in Hiera:
#
#   gpgkey_content => file('profile/openbao-gpg-pub-20240618.asc'),

$openbao_signing_key = @(ASC)
  -----BEGIN PGP PUBLIC KEY BLOCK-----

  mQINBGZx4nABEACnQllkFhq8bMuf9cgEqtpuJ133TWogetAW21nQUL7mKaPrrSdC
  ... the full contents of https://openbao.org/assets/openbao-gpg-pub-20240618.asc ...
  -----END PGP PUBLIC KEY BLOCK-----
  | ASC

class { 'openbao::repo':
  gpgkey_content => $openbao_signing_key,
}
