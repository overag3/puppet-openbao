# Examples

Standalone manifests, each one applying on its own:

```console
# puppet apply --modulepath /etc/puppetlabs/code/environments/production/modules \
    examples/server_single_node.pp
```

They are meant to be read as much as run: start from the one closest to what you need,
then look up the parameters it uses in [REFERENCE.md](../REFERENCE.md).

## Server

| Example | What it shows |
|---|---|
| [`server_single_node.pp`](server_single_node.pp) | Everything at its default: one node, `file` storage, no TLS |
| [`server_raft_cluster.pp`](server_raft_cluster.pp) | Raft cluster node, TLS listener, AWS KMS auto-unseal, telemetry |
| [`server_multiple_listeners.pp`](server_multiple_listeners.pp) | Several listeners at once, TCP and unix socket |
| [`server_archive_install.pp`](server_archive_install.pp) | Installing from the upstream tarball instead of a package |
| [`server_pinned_version.pp`](server_pinned_version.pp) | Holding a node at an exact package version |
| [`server_extra_config.pp`](server_extra_config.pp) | The `extra_config` and `raw_config` escape hatches |
| [`server_json_config.pp`](server_json_config.pp) | Writing the configuration as JSON rather than HCL |

## Agent

| Example | What it shows |
|---|---|
| [`agent_approle_template.pp`](agent_approle_template.pp) | AppRole auto-auth rendering secrets into files |
| [`agent_caching_proxy.pp`](agent_caching_proxy.pp) | Local caching proxy in front of a remote server |

## Repository (`openbao::repo`)

`openbao::repo` stands on its own: it configures the APT or YUM repository and installs
nothing. The `openbao` class contains it, so when the service is managed too, these
parameters are set from Hiera (`openbao::repo::release: 'testing'`) rather than by
declaring the class a second time.

| Example | What it shows |
|---|---|
| [`repo_defaults.pp`](repo_defaults.pp) | The repository alone, everything at its default |
| [`repo_client_only.pp`](repo_client_only.pp) | The `bao` CLI alone, repository plus package, no service |
| [`repo_prerelease.pp`](repo_prerelease.pp) | Following the pre-release channel |
| [`repo_internal_mirror.pp`](repo_internal_mirror.pp) | An internal mirror, with the signing key served by Puppet |
| [`repo_airgapped_key.pp`](repo_airgapped_key.pp) | Passing the signing key inline, for hosts that cannot fetch it |
| [`repo_priority_and_proxy.pp`](repo_priority_and_proxy.pp) | Pin priority, HTTP proxy and architecture restriction |
| [`repo_with_openbao_class.pp`](repo_with_openbao_class.pp) | Tuning the repository while `openbao` still manages the service |

## Notes

* None of these initialise or unseal OpenBao — that stays a deliberate manual step.
* The agent examples write their token to `/run/openbao`, which the generated systemd
  unit creates through `RuntimeDirectory=openbao`.
* Anything OpenBao has to write outside of `/run/openbao` and the storage directory needs
  to be listed in `service_read_write_paths`, because the unit sets `ProtectSystem=full`.
* Every example here is compiled by `spec/hosts/examples_spec.rb`, so they cannot drift
  from the parameters. The suite picks one distribution per OS family rather than all
  nine supported ones: the manifests only ever branch on the family, so the extra
  compilations would cost minutes to prove the same thing.
