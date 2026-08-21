# frozen_string_literal: true

# @summary Remove undef values from a data structure, at every level of nesting.
#
# `delete_undef_values` and the `skip_undef` argument of `stdlib::to_json_pretty` only
# look at the top level, leaving nested `null` values that OpenBao refuses to start on.
#
# Sensitive values are unwrapped along the way, both renderers writing the literal
# "Sensitive [value redacted]" placeholder otherwise.
Puppet::Functions.create_function(:'openbao::compact') do
  # @param data The data structure to clean up.
  # @return [Variant[Hash, Array]] the same structure without any undef value.
  dispatch :compact do
    param 'Variant[Hash, Array]', :data
    return_type 'Variant[Hash, Array]'
  end

  def compact(data)
    case data
    when Hash
      data.each_with_object({}) do |(key, value), result|
        value = unwrap(value)
        next if undef?(value)

        result[key] = compact_value(value)
      end
    when Array
      data.map { |value| unwrap(value) }
          .reject { |value| undef?(value) }
          .map { |value| compact_value(value) }
    end
  end

  def compact_value(value)
    (value.is_a?(Hash) || value.is_a?(Array)) ? compact(value) : value
  end

  def unwrap(value)
    value.is_a?(Puppet::Pops::Types::PSensitiveType::Sensitive) ? value.unwrap : value
  end

  def undef?(value)
    value.nil? || value == :undef
  end
end
