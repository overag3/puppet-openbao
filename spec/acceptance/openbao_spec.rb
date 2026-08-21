# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'openbao class' do
  context 'with default parameters' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        include openbao
        PUPPET
      end
    end

    # rubocop:disable RSpec/RepeatedExampleGroupBody
    describe user('openbao') do
      it { is_expected.to exist }
    end

    describe group('openbao') do
      it { is_expected.to exist }
    end
    # rubocop:enable RSpec/RepeatedExampleGroupBody

    describe package('openbao') do
      it { is_expected.to be_installed }
    end

    describe file('/usr/bin/bao') do
      it { is_expected.to be_executable }
    end

    describe file('/etc/openbao/openbao.hcl') do
      it { is_expected.to be_file }
      it { is_expected.to be_owned_by 'root' }
      it { is_expected.to be_grouped_into 'openbao' }
      it { is_expected.to be_mode 640 }
      its(:content) { is_expected.to include 'storage "file" {' }
      its(:content) { is_expected.to include 'path = "/var/lib/openbao"' }
      its(:content) { is_expected.to include 'address = "127.0.0.1:8200"' }
    end

    describe file('/var/lib/openbao') do
      it { is_expected.to be_directory }
      it { is_expected.to be_owned_by 'openbao' }
      it { is_expected.to be_mode 700 }
    end

    describe file('/etc/systemd/system/openbao.service') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to include 'ExecStart=/usr/bin/bao server -config=/etc/openbao/openbao.hcl' }
      its(:content) { is_expected.to include 'MemorySwapMax=0' }
      its(:content) { is_expected.to match %r{Environment=GOMAXPROCS=\d+} }
    end

    describe service('openbao') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    # RuntimeDirectory=openbao, which the agent examples use for their token sink
    describe file('/run/openbao') do
      it { is_expected.to be_directory }
      it { is_expected.to be_owned_by 'openbao' }
    end

    describe port(8200) do
      it { is_expected.to be_listening.on('127.0.0.1').with('tcp') }
    end

    # A freshly installed OpenBao is sealed and uninitialised, which `bao status`
    # reports with exit code 2.
    describe command('BAO_ADDR=http://127.0.0.1:8200 bao status') do
      its(:exit_status) { is_expected.to eq 2 }
      its(:stdout) { is_expected.to match %r{Sealed\s+true} }
    end
  end

  context 'with install_method => archive' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'openbao':
          install_method => 'archive',
          version        => '2.6.1',
          config_format  => 'json',
          listener       => {
            'tcp' => { 'address' => '127.0.0.1:8300', 'tls_disable' => true },
          },
          storage        => { 'file' => { 'path' => '/var/lib/openbao' } },
        }
        PUPPET
      end
    end

    describe file('/usr/local/bin/bao') do
      it { is_expected.to be_file }
      it { is_expected.to be_mode 755 }
      it { is_expected.to be_owned_by 'root' }
    end

    describe file('/usr/local/bin/CHANGELOG.md') do
      it { is_expected.not_to exist }
    end

    describe command('getcap /usr/local/bin/bao') do
      its(:stdout) { is_expected.to match %r{/usr/local/bin/bao.*cap_ipc_lock.*ep} }
    end

    describe command('/usr/local/bin/bao version') do
      its(:exit_status) { is_expected.to eq 0 }
      its(:stdout) { is_expected.to match %r{OpenBao v2\.6\.1} }
    end

    describe file('/etc/openbao/openbao.json') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to include '"address": "127.0.0.1:8300"' }
    end

    describe service('openbao') do
      it { is_expected.to be_running }
    end

    describe port(8300) do
      it { is_expected.to be_listening.on('127.0.0.1').with('tcp') }
    end
  end

  context 'with mode => agent' do
    let(:manifest) do
      <<-PUPPET
      class { 'openbao':
        mode            => 'agent',
        service_ensure  => 'stopped',
        service_enable  => false,
        agent_vault     => { 'address' => 'https://openbao.example.com:8200' },
        agent_auto_auth => {
          'method' => {
            'type'   => 'approle',
            'config' => {
              'role_id_file_path'   => '/etc/openbao/role-id',
              'secret_id_file_path' => '/etc/openbao/secret-id',
            },
          },
          'sink'   => { 'type' => 'file', 'config' => { 'path' => '/run/openbao-token' } },
        },
        agent_listener  => { 'tcp' => { 'address' => '127.0.0.1:8100', 'tls_disable' => true } },
      }
      PUPPET
    end

    it_behaves_like 'an idempotent resource'

    describe file('/etc/openbao/openbao.hcl') do
      its(:content) { is_expected.to include 'address = "https://openbao.example.com:8200"' }
      its(:content) { is_expected.to include 'role_id_file_path = "/etc/openbao/role-id"' }
      its(:content) { is_expected.to include 'type = "approle"' }
      its(:content) { is_expected.to include 'address = "127.0.0.1:8100"' }
    end

    describe file('/etc/systemd/system/openbao.service') do
      its(:content) { is_expected.to include 'ExecStart=/usr/bin/bao agent -config=/etc/openbao/openbao.hcl' }
      its(:content) { is_expected.to include 'Type=simple' }
      its(:content) { is_expected.to include 'RuntimeDirectory=openbao' }
    end

    # OpenBao itself accepts the rendered configuration, even though the server it
    # points at does not exist. The agent retries authentication forever, hence the
    # timeout.
    describe command('timeout 5 bao agent -config=/etc/openbao/openbao.hcl 2>&1') do
      its(:stdout) { is_expected.to include 'OpenBao Agent started!' }
      its(:stdout) { is_expected.to include 'Api Address 1: http://127.0.0.1:8100' }
      its(:stdout) { is_expected.not_to include 'error loading configuration' }
    end
  end
end
