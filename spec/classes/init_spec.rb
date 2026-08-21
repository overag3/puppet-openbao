# frozen_string_literal: true

require 'spec_helper'

describe 'openbao' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:hcl_content) { catalogue.resource('File', '/etc/openbao/openbao.hcl')[:content] }
      let(:unit_content) { catalogue.resource('Systemd::Unit_file', 'openbao.service')[:content] }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it { is_expected.to contain_class('openbao::repo').that_comes_before('Class[openbao::install]') }
        it { is_expected.to contain_class('openbao::install').that_comes_before('Class[openbao::config]') }
        it { is_expected.to contain_class('openbao::config').that_notifies('Class[openbao::service]') }
        it { is_expected.to contain_class('openbao::install').that_notifies('Class[openbao::service]') }

        it { is_expected.to contain_group('openbao').with_system(true) }
        it { is_expected.to contain_user('openbao').with_system(true).with_gid('openbao').with_shell('/bin/false') }

        it { is_expected.to contain_package('openbao').with_ensure('installed') }
        it { is_expected.not_to contain_archive('/tmp/openbao_2.6.1_linux_amd64.tar.gz') }
        it { is_expected.not_to contain_file_capability('openbao_binary_capability') }

        # A repository install has no binary of its own to point the fact at, and a host
        # coming back from an archive install must not keep the one it used to have.
        it do
          expect(subject).to contain_file('/opt/puppetlabs/facter/facts.d/openbao_bin_path.txt')
            .with_ensure('absent')
        end

        it { is_expected.to contain_file('/etc/openbao').with_ensure('directory').with_owner('root').with_group('openbao').with_mode('0750') }
        it { is_expected.to contain_file('/var/lib/openbao').with_ensure('directory').with_owner('openbao').with_mode('0700') }

        it do
          expect(subject).to contain_file('/etc/openbao/openbao.hcl')
            .with_owner('root')
            .with_group('openbao')
            .with_mode('0640')
        end

        it 'renders the server configuration as HCL' do
          expect(hcl_content).to eq(<<~HCL)
            storage "file" {
              path = "/var/lib/openbao"
            }

            listener "tcp" {
              address = "127.0.0.1:8200"
              tls_disable = true
            }
          HCL
        end

        it { is_expected.to contain_file('/etc/openbao/openbao.env').with_content(sensitive("# This file is managed by Puppet\n\n")) }

        # Rendered secrets stay out of the logs, the reports and the provider's errors.
        it 'marks both generated files as sensitive' do
          expect(catalogue.resource('File', '/etc/openbao/openbao.hcl').sensitive_parameters).to include(:content)
          expect(catalogue.resource('File', '/etc/openbao/openbao.env').sensitive_parameters).to include(:content)
        end

        it { is_expected.to contain_systemd__unit_file('openbao.service') }

        it 'points the unit at the server subcommand' do
          expect(unit_content).to include('ExecStart=/usr/bin/bao server -config=/etc/openbao/openbao.hcl')
          expect(unit_content).to include('Type=notify')
          expect(unit_content).to include('User=openbao')
          expect(unit_content).to include('EnvironmentFile=-/etc/openbao/openbao.env')
          expect(unit_content).to include('AmbientCapabilities=CAP_IPC_LOCK')
          expect(unit_content).to include('MemorySwapMax=0')
          expect(unit_content).to include('RuntimeDirectory=openbao')
          expect(unit_content).not_to include('ReadWritePaths=')
        end

        it { is_expected.to contain_service('openbao').with_ensure('running').with_enable(true) }
      end

      case os_facts[:os]['family']
      when 'Debian'
        it { is_expected.to contain_apt__source('openbao') }
        it { is_expected.not_to contain_yumrepo('openbao') }
      when 'RedHat'
        it { is_expected.to contain_yumrepo('openbao') }
        it { is_expected.not_to contain_apt__source('openbao') }
      end

      context 'with manage_repo => false' do
        let(:params) { { manage_repo: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('openbao::repo') }
        it { is_expected.not_to contain_apt__source('openbao') }
        it { is_expected.not_to contain_yumrepo('openbao') }
        it { is_expected.to contain_package('openbao') }
      end

      context 'with install_method => archive' do
        let(:params) { { install_method: 'archive', version: '2.6.1' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package('openbao') }
        it { is_expected.not_to contain_class('openbao::repo') }

        it do
          expect(subject).to contain_archive('/tmp/openbao_2.6.1_linux_amd64.tar.gz')
            .with_source('https://github.com/openbao/openbao/releases/download/v2.6.1/openbao_2.6.1_linux_amd64.tar.gz')
            .with_extract(true)
            .with_extract_path('/usr/local/bin')
            .with_extract_command('tar xzf %s --unlink-first bao')
            .with_creates('/usr/local/bin/bao')
            .that_comes_before('File[openbao_binary]')
        end

        it { is_expected.to contain_file('openbao_binary').with_path('/usr/local/bin/bao').with_mode('0755').with_owner('root') }

        it 'records the managed binary for the openbao_version fact' do
          expect(subject).to contain_file('/opt/puppetlabs/facter/facts.d/openbao_bin_path.txt')
            .with_ensure('file')
            .with_content("openbao_bin_path=/usr/local/bin/bao\n")
        end

        it { is_expected.to contain_class('file_capability') }

        it do
          expect(subject).to contain_file_capability('openbao_binary_capability')
            .with_file('/usr/local/bin/bao')
            .with_capability('cap_ipc_lock=ep')
        end

        it 'points the unit at the extracted binary' do
          expect(unit_content).to include('ExecStart=/usr/local/bin/bao server -config=/etc/openbao/openbao.hcl')
        end
      end

      # The upgrade contract of archive installs, requesting 2.6.1: only an older
      # installed binary clears `creates` and triggers the download. A pre-release
      # counts as older than its final release.
      {
        'a newer binary (2.7.0)' => ['2.7.0', '/usr/local/bin/bao'],
        'an older binary (2.5.0)' => ['2.5.0', nil],
        'a pre-release of the requested version' => ['2.6.1-beta20250528', nil],
      }.each do |description, (installed, creates)|
        context "with install_method => archive and #{description} installed" do
          let(:facts) { os_facts.merge(openbao_version: installed) }
          let(:params) { { install_method: 'archive', version: '2.6.1' } }

          it { is_expected.to contain_archive('/tmp/openbao_2.6.1_linux_amd64.tar.gz').with_creates(creates) }
        end
      end

      context 'with install_method => archive and a checksum' do
        let(:params) do
          {
            install_method: 'archive',
            download_checksum: 'a3f1c0de4b5e6f7089abcdef0123456789abcdef0123456789abcdef01234567',
            download_checksum_type: 'sha256',
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          expect(subject).to contain_archive('/tmp/openbao_2.6.1_linux_amd64.tar.gz')
            .with_checksum('a3f1c0de4b5e6f7089abcdef0123456789abcdef0123456789abcdef01234567')
            .with_checksum_type('sha256')
        end
      end

      context 'with install_method => archive and disable_mlock => true' do
        let(:params) { { install_method: 'archive', disable_mlock: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_file_capability('openbao_binary_capability') }

        it 'drops CAP_IPC_LOCK from the unit' do
          expect(unit_content).to include("CapabilityBoundingSet=CAP_SYSLOG\n")
          expect(unit_content).not_to include('AmbientCapabilities')
        end
      end

      context 'with restart_on_change => false' do
        let(:params) { { restart_on_change: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('openbao::config').that_comes_before('Class[openbao::service]') }
        it { is_expected.not_to contain_class('openbao::config').that_notifies('Class[openbao::service]') }
        it { is_expected.not_to contain_class('openbao::install').that_notifies('Class[openbao::service]') }
      end

      context 'with manage_package => false' do
        let(:params) { { manage_package: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package('openbao') }
        it { is_expected.to contain_user('openbao') }
        it { is_expected.to contain_file('/etc/openbao/openbao.hcl') }
        it { is_expected.not_to contain_file_capability('openbao_binary_capability') }
        it { is_expected.to contain_file('/opt/puppetlabs/facter/facts.d/openbao_bin_path.txt').with_ensure('absent') }
      end

      context 'with manage_package => false and manage_file_capabilities => true' do
        let(:params) { { manage_package: false, manage_file_capabilities: true, bin_name: 'openbao' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('file_capability') }
        it { is_expected.to contain_file_capability('openbao_binary_capability').with_file('/usr/bin/openbao') }
      end

      context 'with install_method => archive and a renamed binary' do
        let(:params) { { install_method: 'archive', bin_name: 'openbao' } }

        it { is_expected.to compile.and_raise_error(%r{bin_name cannot be 'openbao'}) }
      end

      context 'with an unsupported archive format' do
        let(:params) { { install_method: 'archive', download_extension: 'zip' } }

        # Only the tar formats are accepted, at the type level: unzip has no equivalent
        # of tar's --unlink-first, so a zip upgrade would fail with "Text file busy"
        # while the service runs.
        it { is_expected.to compile.and_raise_error(%r{parameter 'download_extension' expects}) }
      end

      context 'with a version that carries the tag prefix' do
        let(:params) { { version: 'v2.6.1' } }

        # The version is interpolated into the download URL, which prefixes the `v`
        # itself, and handed to SemVer() for the upgrade decision. Both want the bare
        # number, so the type refuses the rest at the declaration rather than on the
        # second run of whichever host happens to have a binary already.
        it { is_expected.to compile.and_raise_error(%r{parameter 'version' expects}) }
      end

      context 'with a version that is not a full semantic version' do
        let(:params) { { version: '2.6' } }

        it { is_expected.to compile.and_raise_error(%r{parameter 'version' expects}) }
      end

      context 'with a pre-release version' do
        let(:params) { { install_method: 'archive', version: '2.7.0-beta20250528' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_archive('/tmp/openbao_2.7.0-beta20250528_linux_amd64.tar.gz') }
      end

      context 'with config_format => json and raw_config' do
        let(:params) { { config_format: 'json', raw_config: 'plugin "secret" "aws" {}' } }

        it { is_expected.to compile.and_raise_error(%r{raw_config would corrupt a JSON configuration file}) }
      end

      context 'with config_format => json' do
        let(:params) { { config_format: 'json', enable_ui: true } }

        it { is_expected.to compile.with_all_deps }

        it 'renders the configuration as JSON' do
          content = catalogue.resource('File', '/etc/openbao/openbao.json')[:content]
          expect(JSON.parse(content)).to eq(
            'ui' => true,
            'storage' => { 'file' => { 'path' => '/var/lib/openbao' } },
            'listener' => { 'tcp' => { 'address' => '127.0.0.1:8200', 'tls_disable' => true } },
          )
        end

        it 'points the unit at the JSON file' do
          expect(unit_content).to include('-config=/etc/openbao/openbao.json')
        end
      end

      context 'with a raft cluster configuration' do
        let(:params) do
          {
            'api_addr' => 'https://bao1.example.com:8200',
            'cluster_addr' => 'https://bao1.example.com:8201',
            'enable_ui' => true,
            'disable_mlock' => true,
            'storage' => { 'raft' => { 'path' => '/var/lib/openbao', 'node_id' => 'bao1' } },
            'seal' => { 'awskms' => { 'region' => 'eu-west-1', 'kms_key_id' => 'abcd' } },
            'telemetry' => { 'prometheus_retention_time' => '30s', 'disable_hostname' => true },
            'listener' => [
              { 'tcp' => { 'address' => '0.0.0.0:8200', 'tls_disable' => false } },
              { 'unix' => { 'address' => '/run/openbao/bao.sock' } },
            ],
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/var/lib/openbao').with_ensure('directory') }

        it 'renders every stanza' do
          expect(hcl_content).to eq(<<~HCL)
            ui = true
            api_addr = "https://bao1.example.com:8200"
            cluster_addr = "https://bao1.example.com:8201"
            disable_mlock = true

            storage "raft" {
              path = "/var/lib/openbao"
              node_id = "bao1"
            }

            listener "tcp" {
              address = "0.0.0.0:8200"
              tls_disable = false
            }

            listener "unix" {
              address = "/run/openbao/bao.sock"
            }

            seal "awskms" {
              region = "eu-west-1"
              kms_key_id = "abcd"
            }

            telemetry {
              prometheus_retention_time = "30s"
              disable_hostname = true
            }
          HCL
        end
      end

      context 'with the storage stanza overridden through extra_config' do
        let(:params) { { extra_config: { 'storage' => { 'raft' => { 'path' => '/srv/bao' } } } } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/srv/bao').with_ensure('directory').with_owner('openbao').with_mode('0700') }
        it { is_expected.not_to contain_file('/var/lib/openbao') }

        it 'renders the overridden stanza' do
          expect(hcl_content).to include('storage "raft" {')
        end
      end

      context 'with a Sensitive value nested inside a stanza' do
        let(:params) do
          { storage: { 'postgresql' => { 'connection_url' => sensitive('postgres://user:pw@db/openbao') } } }
        end

        it { is_expected.to compile.with_all_deps }

        it 'writes the unwrapped secret, not the redacted placeholder' do
          expect(hcl_content).to include('connection_url = "postgres://user:pw@db/openbao"')
          expect(hcl_content).not_to include('redacted')
        end
      end

      context 'with a storage backend that keeps no local data' do
        let(:params) { { storage: { 'postgresql' => { 'connection_url' => 'postgres://localhost' } } } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_file('/var/lib/openbao') }

        it 'still renders the backend' do
          expect(hcl_content).to include('storage "postgresql" {')
        end
      end

      context 'with a file storage backend missing its path' do
        let(:params) { { storage: { 'file' => { 'foo' => 'bar' } } } }

        it { is_expected.to compile.and_raise_error(%r{the file storage backend needs a path attribute}) }
      end

      context 'with manage_storage_dir => false' do
        let(:params) { { manage_storage_dir: false, storage: { 'postgresql' => { 'connection_url' => 'postgres://x' } } } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_file('/var/lib/openbao') }
      end

      context 'with extra_config and raw_config' do
        let(:params) do
          {
            extra_config: { 'log_level' => 'debug' },
            raw_config: "plugin \"secret\" \"aws\" {\n  version = \"v1.0.0\"\n}",
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'merges both into the configuration file' do
          expect(hcl_content).to include('log_level = "debug"')
          expect(hcl_content).to end_with("plugin \"secret\" \"aws\" {\n  version = \"v1.0.0\"\n}\n")
        end
      end

      context 'with environment_variables' do
        let(:params) { { environment_variables: { 'BAO_LOG_LEVEL' => 'debug', 'AWS_REGION' => 'eu-west-1' } } }

        it { is_expected.to compile.with_all_deps }

        it do
          expect(subject).to contain_file('/etc/openbao/openbao.env')
            .with_content(sensitive(%(# This file is managed by Puppet\nBAO_LOG_LEVEL="debug"\nAWS_REGION="eu-west-1"\n)))
            .with_mode('0640')
        end
      end

      context 'with an environment variable holding quotes and backslashes' do
        let(:params) { { environment_variables: { 'BAO_X' => 'a "quoted" \\ value' } } }

        it { is_expected.to compile.with_all_deps }

        it do
          expect(subject).to contain_file('/etc/openbao/openbao.env')
            .with_content(sensitive(%(# This file is managed by Puppet\nBAO_X="a \\"quoted\\" \\\\ value"\n)))
        end
      end

      context 'with a Sensitive environment variable' do
        let(:params) do
          { environment_variables: { 'AWS_SECRET_ACCESS_KEY' => sensitive('s3cr3t'), 'AWS_REGION' => 'eu-west-1' } }
        end

        it { is_expected.to compile.with_all_deps }

        it 'writes the unwrapped secret, not the redacted placeholder' do
          content = catalogue.resource('File', '/etc/openbao/openbao.env')[:content]

          expect(content).to include('AWS_SECRET_ACCESS_KEY="s3cr3t"')
          expect(content).not_to include('redacted')
        end
      end

      context 'with an environment variable holding a newline' do
        let(:params) { { environment_variables: { 'BAO_X' => "a\nGOMAXPROCS=64" } } }

        it { is_expected.to compile.and_raise_error(%r{environment variable BAO_X must not contain a newline}) }
      end

      context 'with manage_environment_file => false' do
        let(:params) { { manage_environment_file: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_file('/etc/openbao/openbao.env') }

        it 'omits EnvironmentFile from the unit' do
          expect(unit_content).not_to include('EnvironmentFile')
        end
      end

      context 'with service_read_write_paths and service_options' do
        let(:params) do
          {
            service_read_write_paths: ['/var/lib/openbao', '/var/log/openbao'],
            service_options: '-log-level=debug',
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          expect(unit_content).to include('ReadWritePaths=/var/lib/openbao /var/log/openbao')
          expect(unit_content).to include('ExecStart=/usr/bin/bao server -config=/etc/openbao/openbao.hcl -log-level=debug')
        end
      end

      context 'with manage_service_file => false' do
        let(:params) { { manage_service_file: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_systemd__unit_file('openbao.service') }
        it { is_expected.to contain_service('openbao') }
      end

      context 'with manage_service => false' do
        let(:params) { { manage_service: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_service('openbao') }
      end

      context 'with mode => agent' do
        let(:params) do
          {
            mode: 'agent',
            agent_vault: { 'address' => 'https://openbao.example.com:8200', 'retry' => { 'num_retries' => 5 } },
            agent_auto_auth: {
              'method' => {
                'type' => 'approle',
                'config' => {
                  'role_id_file_path' => '/etc/openbao/role-id',
                  'secret_id_file_path' => '/etc/openbao/secret-id',
                },
              },
              'sink' => { 'type' => 'file', 'config' => { 'path' => '/run/openbao/token' } },
            },
            pid_file: '/run/openbao/agent.pid',
            agent_cache: {},
            agent_api_proxy: { 'use_auto_auth_token' => true },
            agent_listener: { 'tcp' => { 'address' => '127.0.0.1:8100', 'tls_disable' => true } },
            agent_template: [
              { 'source' => '/etc/openbao/app.ctmpl', 'destination' => '/etc/app/secrets.ini' },
              { 'source' => '/etc/openbao/db.ctmpl', 'destination' => '/etc/app/db.ini' },
            ],
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'keeps the openbao service name' do
          expect(subject).to contain_service('openbao')
          expect(subject).to contain_systemd__unit_file('openbao.service')
        end

        it 'runs the agent subcommand' do
          expect(unit_content).to include('ExecStart=/usr/bin/bao agent -config=/etc/openbao/openbao.hcl')
          expect(unit_content).to include('Type=simple')
        end

        it 'does not manage a storage directory' do
          expect(subject).not_to contain_file('/var/lib/openbao')
        end

        it 'renders the agent configuration' do
          expect(hcl_content).to eq(<<~HCL)
            pid_file = "/run/openbao/agent.pid"

            vault {
              address = "https://openbao.example.com:8200"
              retry {
                num_retries = 5
              }
            }

            auto_auth {
              method {
                type = "approle"
                config {
                  role_id_file_path = "/etc/openbao/role-id"
                  secret_id_file_path = "/etc/openbao/secret-id"
                }
              }
              sink {
                type = "file"
                config {
                  path = "/run/openbao/token"
                }
              }
            }

            api_proxy {
              use_auto_auth_token = true
            }

            cache {}

            listener "tcp" {
              address = "127.0.0.1:8100"
              tls_disable = true
            }

            template {
              source = "/etc/openbao/app.ctmpl"
              destination = "/etc/app/secrets.ini"
            }

            template {
              source = "/etc/openbao/db.ctmpl"
              destination = "/etc/app/db.ini"
            }
          HCL
        end
      end

      context 'with mode => agent but no server address' do
        let(:params) { { mode: 'agent' } }

        it { is_expected.to compile.and_raise_error(%r{agent mode requires agent_vault}) }
      end

      context 'with mode => agent and the server address in extra_config' do
        let(:params) { { mode: 'agent', extra_config: { 'vault' => { 'address' => 'https://bao.example.com:8200' } } } }

        it { is_expected.to compile.with_all_deps }
      end

      context 'on an unsupported architecture' do
        let(:facts) { os_facts.merge(os: os_facts[:os].merge('architecture' => 'mips')) }

        context 'with install_method => repo' do
          it { is_expected.to compile.with_all_deps }
        end

        context 'with install_method => archive' do
          let(:params) { { install_method: 'archive' } }

          it { is_expected.to compile.and_raise_error(%r{unsupported architecture mips}) }
        end

        context 'with install_method => archive and an explicit download_url' do
          let(:params) { { install_method: 'archive', download_url: 'https://example.com/bao.tar.gz' } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_archive('/tmp/bao.tar.gz').with_source('https://example.com/bao.tar.gz') }
        end
      end
    end
  end
end
