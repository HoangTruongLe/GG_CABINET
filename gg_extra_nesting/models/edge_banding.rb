# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # EdgeBanding model - represents edge banding on a board edge
    # Phase 3: Complete implementation
    class EdgeBanding
      attr_reader :id, :name, :thickness, :color

      def initialize(id, name, thickness, color)
        @id = id.to_i
        @name = name.to_s
        @thickness = thickness.to_f  # mm
        @color = color.to_s          # Hex color (e.g., "#b36ea9")
      end

      # =================================================================
      # Parsing from Board Attributes
      # =================================================================

      # Parse edge banding types from board
      # Returns hash: { id => EdgeBanding, ... }
      def self.parse_from_board(board)
        attr = board.entity.get_attribute('ABF', 'edge-band-types')
        return {} unless attr

        parse_array(attr)
      end

      # Parse edge banding attribute array
      # Format: [id, name, thickness, color, separator, ...]
      def self.parse_array(array)
        return {} unless array.is_a?(Array)
        return {} if array.empty?

        array.each_slice(5).each_with_object({}) do |chunk, edge_bandings|
          # Last element in each chunk is just a separator and can be ignored.
          id, name, thickness, color = chunk
          next if [id, name, thickness, color].any?(&:nil?)

          edge_bandings[id.to_i] = new(id, name, thickness, color)
        end
      end

      # =================================================================
      # Side Face Edge Banding Detection
      # =================================================================

      # Get edge banding ID from side face
      def self.get_edge_band_id(side_face)
        return nil unless side_face.entity

        side_face.entity.get_attribute('ABF', 'edge-band-id')
      end

      # Check if side face has edge banding
      def self.has_edge_banding?(side_face)
        !get_edge_band_id(side_face).nil?
      end

      # =================================================================
      # Validation
      # =================================================================

      def valid?
        @id >= 0 &&
        !@name.empty? &&
        @thickness > 0 &&
        !@color.empty?
      end

      # =================================================================
      # Color Helpers
      # =================================================================

      # Convert hex color to SketchUp color
      def sketchup_color
        return nil unless @color.start_with?('#')

        hex = @color[1..-1]
        return nil unless hex.length == 6

        r = hex[0..1].to_i(16)
        g = hex[2..3].to_i(16)
        b = hex[4..5].to_i(16)

        Sketchup::Color.new(r, g, b)
      end

      # =================================================================
      # Display & Debug
      # =================================================================

      def to_s
        "EdgeBanding(id: #{@id}, name: '#{@name}', thickness: #{@thickness}mm, color: #{@color})"
      end

      def inspect
        to_s
      end

      def print_info
        puts "Edge Banding:"
        puts "  ID: #{@id}"
        puts "  Name: #{@name}"
        puts "  Thickness: #{@thickness} mm"
        puts "  Color: #{@color}"
        puts "  Valid: #{valid?}"
      end

      # =================================================================
      # Serialization
      # =================================================================

      def to_hash
        {
          id: @id,
          name: @name,
          thickness: @thickness,
          color: @color,
          valid: valid?
        }
      end
    end

  end
end
