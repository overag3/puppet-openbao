# frozen_string_literal: true

require 'spec_helper'

describe 'openbao::compact' do
  it { is_expected.to run.with_params({}).and_return({}) }
  it { is_expected.to run.with_params([]).and_return([]) }

  it 'removes undef values at the top level' do
    is_expected.to run.with_params('ui' => true, 'api_addr' => nil).and_return('ui' => true)
  end

  it 'removes undef values nested inside a hash' do
    is_expected.to run.with_params(
      'storage' => { 'raft' => { 'path' => '/var/lib/openbao', 'node_id' => nil } },
    ).and_return('storage' => { 'raft' => { 'path' => '/var/lib/openbao' } })
  end

  it 'removes undef values nested inside an array' do
    is_expected.to run.with_params(
      'listener' => [{ 'tcp' => { 'address' => '127.0.0.1:8200', 'tls_cert_file' => nil } }],
    ).and_return('listener' => [{ 'tcp' => { 'address' => '127.0.0.1:8200' } }])
  end

  it 'removes undef elements from an array' do
    is_expected.to run.with_params('disable_keep_alives' => ['caching', nil]).and_return('disable_keep_alives' => ['caching'])
  end

  it 'keeps false and empty structures' do
    is_expected.to run.with_params('tls_disable' => false, 'cache' => {}).and_return('tls_disable' => false, 'cache' => {})
  end

  it 'unwraps Sensitive values nested inside a hash' do
    secret = Puppet::Pops::Types::PSensitiveType::Sensitive.new('hunter2')

    is_expected.to run.with_params(
      'seal' => { 'pkcs11' => { 'pin' => secret } },
    ).and_return('seal' => { 'pkcs11' => { 'pin' => 'hunter2' } })
  end

  it 'unwraps Sensitive values nested inside an array' do
    secret = Puppet::Pops::Types::PSensitiveType::Sensitive.new('hunter2')

    is_expected.to run.with_params('tokens' => [secret]).and_return('tokens' => ['hunter2'])
  end
end
