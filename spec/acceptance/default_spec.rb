# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'openbao' do
  context 'with default parameters' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        include openbao
        PUPPET
      end
    end
  end
end
