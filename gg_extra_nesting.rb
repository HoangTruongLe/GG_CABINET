# frozen_string_literal: true

# ===============================================================
# GG_Cabinet Extra Nesting Plugin
# Main loader file (entry point for SketchUp)
# ===============================================================

require 'sketchup.rb'
require 'extensions.rb'

module GG_Cabinet
  module ExtraNesting

    unless file_loaded?(__FILE__)
      # Create extension
      ex = SketchupExtension.new(
        'GG Extra Nesting',
        File.join(File.dirname(__FILE__), 'gg_extra_nesting', 'extra_nesting')
      )

      ex.description = 'Add extra boards to existing nesting without re-nesting everything'
      ex.version     = '0.1.0-dev'
      ex.copyright   = '2025 GG_Cabinet'
      ex.creator     = 'GG_Cabinet Team'

      # Register extension
      Sketchup.register_extension(ex, true)

      file_loaded(__FILE__)
    end

  end
end
