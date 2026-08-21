# frozen_string_literal: true

require 'spec_helper'

describe 'openbao::to_hcl' do
  it { is_expected.to run.with_params({}).and_return('') }

  it 'renders scalars as attributes' do
    is_expected.to run.with_params(
      'ui' => true,
      'disable_cache' => false,
      'log_level' => 'debug',
      'plugin_file_uid' => 0,
    ).and_return(<<~HCL)
      ui = true
      disable_cache = false
      log_level = "debug"
      plugin_file_uid = 0
    HCL
  end

  it 'renders arrays of scalars inline' do
    is_expected.to run.with_params('disable_keep_alives' => %w[auto-auth-token caching])
                      .and_return(%(disable_keep_alives = ["auto-auth-token", "caching"]\n))
  end

  it 'escapes strings' do
    is_expected.to run.with_params('cluster_name' => 'a "quoted" \\ name')
                      .and_return(%(cluster_name = "a \\"quoted\\" \\\\ name"\n))
  end

  it 'renders a labelled key as a block label' do
    is_expected.to run.with_params('storage' => { 'raft' => { 'path' => '/var/lib/openbao' } }).and_return(<<~HCL)
      storage "raft" {
        path = "/var/lib/openbao"
      }
    HCL
  end

  it 'renders an unlabelled hash as a plain block' do
    is_expected.to run.with_params('telemetry' => { 'disable_hostname' => true }).and_return(<<~HCL)
      telemetry {
        disable_hostname = true
      }
    HCL
  end

  it 'renders an empty hash as an empty block' do
    is_expected.to run.with_params('cache' => {}).and_return("cache {}\n")
  end

  it 'repeats a block for every element of an array of hashes' do
    is_expected.to run.with_params(
      'template' => [
        { 'source' => '/a.ctmpl', 'destination' => '/a' },
        { 'source' => '/b.ctmpl', 'destination' => '/b' },
      ],
    ).and_return(<<~HCL)
      template {
        source = "/a.ctmpl"
        destination = "/a"
      }

      template {
        source = "/b.ctmpl"
        destination = "/b"
      }
    HCL
  end

  it 'repeats a labelled block for every element of an array of hashes' do
    is_expected.to run.with_params(
      'listener' => [
        { 'tcp' => { 'address' => '127.0.0.1:8200' } },
        { 'unix' => { 'address' => '/run/bao.sock' } },
      ],
    ).and_return(<<~HCL)
      listener "tcp" {
        address = "127.0.0.1:8200"
      }

      listener "unix" {
        address = "/run/bao.sock"
      }
    HCL
  end

  it 'renders several labels declared under a single labelled key' do
    is_expected.to run.with_params(
      'listener' => {
        'tcp' => { 'address' => '127.0.0.1:8200' },
        'unix' => { 'address' => '/run/bao.sock' },
      },
    ).and_return(<<~HCL)
      listener "tcp" {
        address = "127.0.0.1:8200"
      }

      listener "unix" {
        address = "/run/bao.sock"
      }
    HCL
  end

  it 'emits attributes before blocks and nests without blank lines' do
    is_expected.to run.with_params(
      'auto_auth' => {
        'method' => { 'config' => { 'role' => 'app' }, 'type' => 'kubernetes' },
      },
      'ui' => true,
    ).and_return(<<~HCL)
      ui = true

      auto_auth {
        method {
          type = "kubernetes"
          config {
            role = "app"
          }
        }
      }
    HCL
  end

  it 'renders kms_library as a labelled block' do
    is_expected.to run.with_params('kms_library' => { 'pkcs11' => { 'library' => '/usr/lib/softhsm.so' } })
                      .and_return(<<~HCL)
                        kms_library "pkcs11" {
                          library = "/usr/lib/softhsm.so"
                        }
                      HCL
  end

  it 'falls back to a plain block when a labelled key does not hold labels' do
    is_expected.to run.with_params('seal' => { 'disabled' => true }).and_return(<<~HCL)
      seal {
        disabled = true
      }
    HCL
  end
end
