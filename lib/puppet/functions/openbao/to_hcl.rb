# frozen_string_literal: true

require 'json'

# @summary Render a configuration Hash as an HCL document.
#
# Values are mapped as follows:
#
# * a scalar, or an Array of scalars, becomes an `key = value` attribute;
# * a Hash becomes a `key { ... }` block;
# * a Hash under one of the labelled keys (`listener`, `storage`, ...) becomes a
#   `key "label" { ... }` block, the single key of the Hash being the label;
# * an Array of Hashes repeats the block.
#
# Blocks carrying two labels, such as `plugin "secret" "aws" {}`, cannot be expressed
# this way; use the `raw_config` parameter of the `openbao` class for those.
Puppet::Functions.create_function(:'openbao::to_hcl') do
  # @param config The configuration to render.
  # @return [String] the HCL document.
  dispatch :to_hcl do
    param 'Hash', :config
    return_type 'String'
  end

  # Keys whose Hash value is a label rather than a nested block.
  def labelled_blocks
    @labelled_blocks ||= %w[listener storage ha_storage seal kms_library service_registration env_template entropy].freeze
  end

  def to_hcl(config)
    body = render_body(config, 0)
    body.empty? ? '' : "#{body}\n"
  end

  def render_body(hash, depth)
    indent = '  ' * depth
    attributes = []
    blocks = []

    hash.each do |key, value|
      name = key.to_s

      if value.is_a?(Hash)
        blocks.concat(render_block(name, value, depth))
      elsif array_of_hashes?(value)
        value.each { |item| blocks.concat(render_block(name, item, depth)) }
      else
        attributes << "#{indent}#{name} = #{render_value(value)}"
      end
    end

    parts = attributes.empty? ? [] : [attributes.join("\n")]
    parts.concat(blocks)
    parts.join(depth.zero? ? "\n\n" : "\n")
  end

  def render_block(name, value, depth)
    if labelled?(name, value)
      value.map { |label, body| wrap_block("#{name} #{render_value(label.to_s)}", body, depth) }
    else
      [wrap_block(name, value, depth)]
    end
  end

  def wrap_block(header, body, depth)
    indent = '  ' * depth
    inner = render_body(body, depth + 1)

    return "#{indent}#{header} {}" if inner.empty?

    "#{indent}#{header} {\n#{inner}\n#{indent}}"
  end

  def labelled?(name, value)
    labelled_blocks.include?(name) && !value.empty? && value.values.all?(Hash)
  end

  def array_of_hashes?(value)
    value.is_a?(Array) && !value.empty? && value.all?(Hash)
  end

  def render_value(value)
    case value
    when nil then 'null'
    when true, false, Numeric then value.to_s
    when Array then "[#{value.map { |item| render_value(item) }.join(', ')}]"
    when Hash then "{ #{value.map { |key, item| "#{key} = #{render_value(item)}" }.join(', ')} }"
    else value.to_s.to_json
    end
  end
end
