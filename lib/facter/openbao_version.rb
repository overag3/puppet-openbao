# frozen_string_literal: true

# Fact: openbao_version
#
# Purpose: Retrieve the version of the installed bao binary
#
Facter.add(:openbao_version) do
  # The module only supports Linux, so spare every other agent the PATH walk and the fork.
  confine kernel: 'Linux'

  setcode do
    # Prefer the binary openbao::install records in the openbao_bin_path external fact:
    # the first `bao` in PATH may be a stale copy, or miss a custom bin_dir entirely.
    managed = Facter.value(:openbao_bin_path)
    bao = if managed && File.executable?(managed)
            managed
          else
            Facter::Util::Resolution.which('bao')
          end

    if bao
      output = Facter::Util::Resolution.exec("\"#{bao}\" version")
      # Keep the pre-release part: v2.7.0-beta1 must not report itself as v2.7.0.
      match = output&.match(%r{OpenBao v(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)})
      match&.captures&.first
    end
  end
end
