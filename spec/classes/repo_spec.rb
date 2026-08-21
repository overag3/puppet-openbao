# frozen_string_literal: true

require 'spec_helper'

describe 'openbao::repo' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
      end

      case os_facts[:os]['family']
      when 'Debian'
        context 'on Debian, with default parameters' do
          it do
            expect(subject).to contain_apt__source('openbao')
              .with_source_format('sources')
              .with_location(['https://pkgs.openbao.org/deb/'])
              .with_release(['stable'])
              .with_repos(['main'])
              .with_enabled(true)
              .with_architecture(nil)
              .with_keyring('/etc/apt/keyrings/openbao.asc')
              .with_allow_unsigned(nil)
          end

          it 'deploys the upstream signing key before the source' do
            expect(subject).to contain_apt__keyring('openbao.asc')
              .with_dir('/etc/apt/keyrings')
              .with_source('https://openbao.org/assets/openbao-gpg-pub-20240618.asc')
              .with_content(nil)
              .that_comes_before('Apt::Source[openbao]')
          end

          it 'pins the repository with the default APT priority' do
            expect(subject).to contain_apt__pin('openbao')
              .with_originator('OpenBao - Official')
              .with_priority(900)
              .that_comes_before('Apt::Source[openbao]')
          end

          it { is_expected.not_to contain_yumrepo('openbao') }
          it { is_expected.not_to contain_exec('openbao_yumrepo_clean') }

          # The index refresh is part of the class's contract, so that a package with
          # `require => Class['openbao::repo']` is installed after `apt update` ran.
          it { is_expected.to contain_anchor('openbao::repo::apt_update').that_requires('Class[apt::update]') }
        end

        context 'with the signing key given inline' do
          let(:params) { { gpgkey_content: "-----BEGIN PGP PUBLIC KEY BLOCK-----\n" } }

          it { is_expected.to compile.with_all_deps }

          it 'takes precedence over gpgkey_source' do
            expect(subject).to contain_apt__keyring('openbao.asc')
              .with_content("-----BEGIN PGP PUBLIC KEY BLOCK-----\n")
              .with_source(nil)
          end
        end

        context 'with a puppet:/// signing key and a custom keyring path' do
          let(:params) do
            {
              gpgkey_source: 'puppet:///modules/profile/openbao.asc',
              keyring_path: '/etc/apt/trusted.gpg.d/openbao.asc',
            }
          end

          it { is_expected.to compile.with_all_deps }

          it do
            expect(subject).to contain_apt__keyring('openbao.asc')
              .with_dir('/etc/apt/trusted.gpg.d')
              .with_source('puppet:///modules/profile/openbao.asc')
          end

          it { is_expected.to contain_apt__source('openbao').with_keyring('/etc/apt/trusted.gpg.d/openbao.asc') }
        end

        context 'with manage_gpgkey => false' do
          let(:params) { { manage_gpgkey: false } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_apt__keyring('openbao.asc') }

          it 'keeps signature enforcement, expecting the key to come from elsewhere' do
            expect(subject).to contain_apt__source('openbao').with_keyring(nil).with_allow_unsigned(nil)
          end
        end

        context 'with allow_unsigned => true' do
          let(:params) { { manage_gpgkey: false, allow_unsigned: true } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_apt__source('openbao').with_allow_unsigned(true) }
        end

        context 'with a pin priority of its own' do
          let(:params) { { apt_pin_priority: 990 } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_apt__pin('openbao').with_priority(990) }
        end
      when 'RedHat'
        context 'on RedHat, with default parameters' do
          it do
            expect(subject).to contain_yumrepo('openbao')
              .with_descr('OpenBao package repository')
              .with_baseurl('https://pkgs.openbao.org/rpm/$basearch')
              .with_enabled(1)
              .with_gpgcheck(1)
              .with_repo_gpgcheck(0)
              .with_gpgkey('https://openbao.org/assets/openbao-gpg-pub-20240618.asc')
              .with_metadata_expire('300')
              .with_sslverify(1)
              .with_priority(10)
              .with_proxy(nil)
          end

          it { is_expected.not_to contain_file('/etc/pki/rpm-gpg/RPM-GPG-KEY-openbao') }
          it { is_expected.not_to contain_apt__source('openbao') }

          # A repository whose definition changed must not keep serving packages from the
          # cached metadata of the previous one.
          it do
            expect(subject).to contain_exec('openbao_yumrepo_clean')
              .with_refreshonly(true)
              .that_subscribes_to('Yumrepo[openbao]')
          end
        end

        context 'with a mirror served by a private CA' do
          let(:params) { { sslcacert: '/etc/pki/ca-trust/source/anchors/example-root-ca.crt' } }

          it { is_expected.to compile.with_all_deps }

          it do
            expect(subject).to contain_yumrepo('openbao')
              .with_sslverify(1)
              .with_sslcacert('/etc/pki/ca-trust/source/anchors/example-root-ca.crt')
          end
        end

        context 'with a signing key that is not an URL' do
          let(:params) { { gpgkey_source: 'puppet:///modules/profile/openbao.asc' } }

          it { is_expected.to compile.with_all_deps }

          it do
            expect(subject).to contain_file('/etc/pki/rpm-gpg/RPM-GPG-KEY-openbao')
              .with_source('puppet:///modules/profile/openbao.asc')
              .that_comes_before('Yumrepo[openbao]')
          end

          it { is_expected.to contain_yumrepo('openbao').with_gpgkey('file:///etc/pki/rpm-gpg/RPM-GPG-KEY-openbao') }
        end

        context 'with the signing key given inline' do
          let(:params) { { gpgkey_content: "-----BEGIN PGP PUBLIC KEY BLOCK-----\n" } }

          it { is_expected.to compile.with_all_deps }

          it 'takes precedence over gpgkey_source' do
            expect(subject).to contain_file('/etc/pki/rpm-gpg/RPM-GPG-KEY-openbao')
              .with_content("-----BEGIN PGP PUBLIC KEY BLOCK-----\n")
              .with_source(nil)
          end

          it { is_expected.to contain_yumrepo('openbao').with_gpgkey('file:///etc/pki/rpm-gpg/RPM-GPG-KEY-openbao') }
        end

        context 'with manage_gpgkey => false' do
          let(:params) { { manage_gpgkey: false } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_file('/etc/pki/rpm-gpg/RPM-GPG-KEY-openbao') }

          it 'keeps signature enforcement, expecting the key to come from elsewhere' do
            expect(subject).to contain_yumrepo('openbao').with_gpgcheck(1).with_gpgkey(nil)
          end
        end

        context 'with allow_unsigned => true' do
          let(:params) { { manage_gpgkey: false, allow_unsigned: true } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_yumrepo('openbao').with_gpgcheck(0).with_gpgkey(nil) }
        end

        context 'with a priority of its own and a proxy' do
          let(:params) { { yum_priority: 5, proxy: 'http://proxy.example.com:3128' } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_yumrepo('openbao').with_priority(5).with_proxy('http://proxy.example.com:3128') }
        end

        context 'with a priority on the APT scale' do
          let(:params) { { yum_priority: 900 } }

          it { is_expected.not_to compile }
        end
      end

      context 'with the pre-release channel' do
        let(:params) { { release: 'testing', rpm_path: 'rpm-testing' } }

        it { is_expected.to compile.with_all_deps }

        case os_facts[:os]['family']
        when 'Debian'
          it { is_expected.to contain_apt__source('openbao').with_release(['testing']) }
        when 'RedHat'
          it { is_expected.to contain_yumrepo('openbao').with_baseurl('https://pkgs.openbao.org/rpm-testing/$basearch') }
        end
      end

      context 'with enabled => false' do
        let(:params) { { enabled: false } }

        it { is_expected.to compile.with_all_deps }

        case os_facts[:os]['family']
        when 'Debian'
          it { is_expected.to contain_apt__source('openbao').with_enabled(false) }
        when 'RedHat'
          it { is_expected.to contain_yumrepo('openbao').with_enabled(0) }
        end
      end

      context 'on an unsupported operating system family' do
        let(:facts) { os_facts.merge(os: os_facts[:os].merge('family' => 'Suse')) }

        it { is_expected.to compile.and_raise_error(%r{no OpenBao package repository is available for Suse}) }
      end
    end
  end
end
