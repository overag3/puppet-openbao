# A repository reached through an HTTP proxy, with the package manager priorities raised
# above their defaults.
#
# The two families do not mean the same thing by "priority", so they get one parameter
# each: `apt_pin_priority`, where the highest value wins, and `yum_priority`, where the
# lowest wins on a 1-99 scale. Their defaults already keep OpenBao ahead of a same-named
# package from elsewhere; the values below only push it further.
#
# Like `proxy` and `architecture`, each is ignored on the family it does not apply to, so
# one class declaration covers a mixed estate.

class { 'openbao::repo':
  apt_pin_priority => 990,
  yum_priority     => 5,
  proxy            => 'http://proxy.example.com:3128',
  architecture     => ['amd64'],
}
