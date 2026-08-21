# puppet-openbao

Puppet module to install and configure [OpenBao](https://openbao.org/), the open
source fork of HashiCorp Vault, either as a **server** or as an **agent**.

## Table of Contents

1. [Description](#description)
1. [Setup](#setup)
1. [Usage](#usage)
    * [Server](#server)
    * [Agent](#agent)
    * [Installation methods](#installation-methods)
    * [Configuration format](#configuration-format)
    * [Escape hatches](#escape-hatches)
1. [Examples](#examples)
1. [Reference](#reference)
1. [Limitations](#limitations)
1. [Testing](#testing)

## Description

The module manages everything needed to run OpenBao on a Linux host:

* the official OpenBao package repository (APT and YUM/DNF), or a release tarball
  downloaded from GitHub;
* the `openbao` user and group;
* the configuration file, generated from Puppet data structures and rendered as HCL or
  JSON;
* the environment file read by the service;
* the storage directory of the `file` and `raft` backends;
* a systemd unit, hardened along the lines of the one shipped by the official packages;
* the service itself.

It does **not** initialise or unseal OpenBao, and it does not manage secrets, policies
or authentication backends.

## Setup

```puppet
include openbao
```

This installs the `openbao` package from the official repository, configures a single
node using the `file` storage backend, has it listen on `127.0.0.1:8200` without TLS,
and starts the service. OpenBao then waits to be initialised:

```console
# BAO_ADDR=http://127.0.0.1:8200 bao operator init
```

## Usage

### Server

A node of a Raft cluster, listening with TLS:

```puppet
class { 'openbao':
  api_addr     => "https://${facts['networking']['fqdn']}:8200",
  cluster_addr => "https://${facts['networking']['fqdn']}:8201",
  # Raft keeps its data in a memory mapped file, which does not play well with mlock
  disable_mlock => true,
  storage      => {
    'raft' => {
      'path'    => '/var/lib/openbao',
      'node_id' => $facts['networking']['hostname'],
    },
  },
  listener     => {
    'tcp' => {
      'address'       => '0.0.0.0:8200',
      'tls_cert_file' => '/etc/openbao/tls/tls.crt',
      'tls_key_file'  => '/etc/openbao/tls/tls.key',
    },
  },
}
```

[`examples/server_raft_cluster.pp`](examples/server_raft_cluster.pp) — compiled by the
test suite on one distribution of each OS family — extends this with auto-unseal through
AWS KMS, telemetry and the credentials in `environment_variables`.

Several listeners are declared with an Array:

```puppet
listener => [
  { 'tcp'  => { 'address' => '0.0.0.0:8200' } },
  { 'unix' => { 'address' => '/run/openbao/bao.sock' } },
]
```

### Agent

The agent authenticates on its own and renders templates or exposes a local proxy.
`agent_vault` is mandatory in this mode:

```puppet
class { 'openbao':
  mode            => 'agent',
  agent_vault     => { 'address' => 'https://openbao.example.com:8200' },
  agent_auto_auth => {
    'method' => {
      'type'   => 'approle',
      'config' => {
        'role_id_file_path'   => '/etc/openbao/role-id',
        'secret_id_file_path' => '/etc/openbao/secret-id',
      },
    },
    'sink'   => {
      'type'   => 'file',
      'config' => { 'path' => '/run/openbao/token' },
    },
  },
  agent_template  => [
    { 'source' => '/etc/openbao/app.ctmpl', 'destination' => '/etc/app/secrets.ini' },
  ],
  # The generated unit sets ProtectSystem=full, which mounts /etc read-only, so every
  # template destination outside /run/openbao has to be opened up explicitly
  service_read_write_paths => ['/etc/app'],
}
```

[`examples/agent_approle_template.pp`](examples/agent_approle_template.pp) and
[`examples/agent_caching_proxy.pp`](examples/agent_caching_proxy.pp) — both compiled
by the test suite — add retries, several templates, and the caching API proxy with its
local listener.

The unit declares `RuntimeDirectory=openbao`, so `/run/openbao` exists while the service
runs, owned by the OpenBao user — the natural place for an auto-auth token sink or a
unix listener socket.

The service is called `openbao` in both modes, so a host runs either a server or an
agent, not both.

### Installation methods

| `install_method` | What it does |
|---|---|
| `repo` (default) | Configures the official OpenBao repository (`https://pkgs.openbao.org`) and installs the `openbao` package. The binary lands in `/usr/bin/bao`. |
| `archive` | Downloads `openbao_<version>_<os>_<arch>.tar.gz` from the GitHub releases and extracts `bao` into `bin_dir` (`/usr/local/bin` by default). |

The repository keeps every published version, so pinning is just a matter of setting
`package_ensure` — the node is held on that exact version, downgrading it if needed:

```puppet
class { 'openbao':
  package_ensure => '2.6.1',
}
```

With `install_method => 'archive'`, the pin is carried by `version` instead, and it acts
as a floor rather than an exact release: the tarball is only fetched when the installed
binary is older than the requested version, so a node already running a newer release is
left alone and is never downgraded.

Only Debian and RedHat based distributions have an OpenBao repository. Anywhere else,
use `install_method => 'archive'`. `manage_repo => false` keeps the package installation
but leaves the repository to you, and `manage_package => false` skips the installation
altogether when the binary is provided by other means.

### The repository on its own

The repository is configured by `openbao::repo`, a class that stands on its own and
carries its own parameters. Including it configures the APT or YUM repository and
installs nothing, which is what a host that only needs the `bao` command line client to
talk to a remote server wants — no configuration file, no service:

```puppet
include openbao::repo

package { 'openbao':
  ensure  => installed,
  require => Class['openbao::repo'],
}
```

To run OpenBao rather than just talk to it, use the `openbao` class, which includes
`openbao::repo` itself. The HSM/PKCS#11 flavour is a matter of `package_name`, not of a
separate declaration:

```puppet
class { 'openbao':
  package_name => 'openbao-hsm',
}
```

When the `openbao` class includes it, the repository is tuned through that class's
parameters, typically from Hiera:

```yaml
openbao::repo::release: 'testing'
openbao::repo::rpm_path: 'rpm-testing'
openbao::repo::metadata_expire: '60'
```

The two package managers do not mean the same thing by "priority", so each gets its own
parameter. `apt_pin_priority` writes an APT pin on the repository origin, where the
highest value wins over a default of 500 and anything above 1000 also allows downgrades.
`yum_priority` writes the `priority` option of the repository, where the *lowest* value
wins on a 1-99 scale and every other repository sits at 99. Both default to a value that
keeps OpenBao ahead of a same-named package from elsewhere -- 900 and 10 -- and both are
range checked, so a value from the wrong scale fails the catalogue instead of quietly
doing the opposite of what it reads like:

```yaml
openbao::repo::apt_pin_priority: 990
openbao::repo::yum_priority: 5
```

No signing key is shipped with this module: APT and DNF are pointed at the key published
by OpenBao and fetch it themselves. Hosts without access to `openbao.org` can be given a
mirror URL, a `puppet:///` source, or the key itself — `gpgkey_content` takes precedence
over `gpgkey_source`, so only one of the two needs to be set:

```yaml
openbao::repo::gpgkey_source: 'puppet:///modules/profile/openbao.asc'
```

`openbao::repo::manage_gpgkey: false` only tells the module not to deploy the key:
signature verification stays on, so APT and DNF will refuse to install packages until
the key is provided by other means (a baseline profile, the image). Actually accepting
unsigned packages is a separate, explicit opt-out — `openbao::repo::allow_unsigned:
true` — which disables the chain of trust entirely (`Trusted: yes` on APT, `gpgcheck=0`
on YUM) and should stay a last resort.

`install_method => 'archive'` also grants `cap_ipc_lock=ep` to the binary so that
OpenBao can lock its memory. The module includes the `file_capability` class itself for
that, which installs `setcap`. Set `manage_file_capabilities => false` to opt out, or to
`true` to grant the capability to a binary installed by other means.

### Configuration format

`config_format` selects how the configuration is written. Both formats are understood by
OpenBao, and the file is named after the format (`openbao.hcl` or `openbao.json`).

```puppet
class { 'openbao':
  config_format => 'json',
}
```

HCL is the default and is generally more readable. JSON is a safe fallback for deeply
nested or unusual structures, since it needs no interpretation of what is a block and
what is an attribute.

### Escape hatches

`extra_config` is merged over the generated configuration and covers stanzas this module
does not expose as a parameter:

```puppet
extra_config => {
  'user_lockout' => { 'userpass' => { 'lockout_threshold' => 5 } },
}
```

`raw_config` is appended verbatim, for HCL constructs the renderer cannot express — such
as blocks carrying two labels. It is refused with `config_format => 'json'`, where it
would corrupt the file:

```puppet
raw_config => @(HCL),
  plugin "secret" "aws" {
    image   = "ghcr.io/openbao/openbao-plugin-secrets-aws"
    version = "v1.0.0"
  }
  | HCL
```

## Examples

The [`examples/`](examples/) directory holds a standalone manifest per scenario — single
node, Raft cluster, archive install, pinned version, escape hatches, JSON output, agent
with templates, agent as a caching proxy, and the CLI client on its own. Each one applies
as is:

```console
# puppet apply --modulepath /etc/puppetlabs/code/environments/production/modules \
    examples/server_raft_cluster.pp
```

See [`examples/README.md`](examples/README.md) for the index.

## Reference

See [REFERENCE.md](REFERENCE.md), generated with
[puppet-strings](https://github.com/puppetlabs/puppet-strings).

## Limitations

* Only systemd based distributions are supported.
* The module never initialises nor unseals OpenBao.
* `manage_storage_dir` handles the `file` and `raft` backends only, and the parent of
  the storage path must already exist. Other backends are simply left alone.
* The generated unit sets `ProtectSystem=full`, which mounts `/usr`, `/boot` and `/etc`
  read-only. Anything OpenBao has to write outside of `/run/openbao` and the storage
  directory — agent template destinations in particular — needs to be listed in
  `service_read_write_paths`.
* `install_method => 'archive'` extracts the `bao` member of the upstream tarball, so
  `bin_name` has to keep its default there; renaming stays available with
  `manage_package => false`.
* Archive upgrades are decided by the `openbao_version` fact. The module records the
  managed binary's path for the fact during the first run, so from then on the
  comparison describes `bin_dir`/`bin_name` itself; only the very first run falls back
  to the first `bao` found in `PATH`.
* Installing a new OpenBao version or changing the configuration restarts the service,
  which seals a server: plan the unseal (or rely on auto-unseal) when changing
  `version`, `package_ensure` or the configuration. `restart_on_change => false` keeps
  Puppet from restarting the service at all; changes then wait for a restart the
  operator schedules.
* `purge_config_dir => true` makes Puppet recurse into `config_dir`, and recursion also
  applies the directory owner, group and mode to every file below it. Keep TLS material
  and anything else with its own permissions outside of `config_dir`.
* With `install_method => 'repo'`, the package's `postinst` generates a self-signed
  certificate in `/opt/openbao/tls` and creates `/opt/openbao/data`. Neither is used by
  the configuration this module writes; point `tls_cert_file`/`tls_key_file` at that
  certificate if you want it, or ignore it.
* The generated systemd unit is written to `/etc/systemd/system/openbao.service` and
  therefore takes precedence over the one shipped by the package. Set
  `manage_service_file => false` to use the packaged unit instead — it hardcodes
  `bao server -config=/etc/openbao/openbao.hcl`, so `config_format` has to stay `hcl`
  and `mode` has to stay `server`.

## Testing

First, `bundle install`.

To run RSpec unit tests: `bundle exec rake spec`

To run RSpec unit tests, syntax checks, puppet-lint, metadata lint and rubocop:
`bundle exec rake test`

To run Beaker acceptance tests: `BEAKER_setfile=<setfile> bundle exec rake beaker`,
where `<setfile>` describes the container the tests run in, e.g.
`debian12-64{image=debian:12}` or `almalinux9-64{image=almalinux:9}`.

The same tasks can also be run without a local Ruby through
[voxbox](https://github.com/voxpupuli/voxbox), the Vox Pupuli container image that
carries every tool needed (Ruby, rake tasks, linters).
