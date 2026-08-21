# frozen_string_literal: true

require 'spec_helper'

# The examples ship inside the published module, so they have to keep compiling as the
# parameters evolve. A :host example group compiles its pre_condition verbatim, which is
# exactly the content of an example manifest.
describe 'openbao examples' do
  let(:node) { 'openbao.example.com' }

  on_supported_os.group_by { |_os, os_facts| os_facts[:os]['family'] }
                 .map { |_family, entries| entries.first }.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      Dir[File.expand_path('../../examples/*.pp', __dir__)].sort.each do |example|
        context File.basename(example) do
          let(:pre_condition) { File.read(example) }

          it { is_expected.to compile.with_all_deps }
        end
      end
    end
  end
end
