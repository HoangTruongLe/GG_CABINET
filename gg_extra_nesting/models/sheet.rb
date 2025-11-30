# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # Sheet model - represents a nesting sheet containing 2D boards
    # Phase 4 implementation
    class Sheet < PersistentEntity
      attr_reader :nesting_root, :boards_2d, :gaps
      attr_accessor :sheet_id, :material_name, :thickness_mm

      # Standard sheet dimensions (mm)
      DEFAULT_WIDTH = 2440.0
      DEFAULT_HEIGHT = 1220.0

      def initialize(sketchup_group, nesting_root = nil)
        super(sketchup_group)

        unless sketchup_group.is_a?(Sketchup::Group)
          raise ArgumentError, "Sheet must be initialized with a Sketchup::Group"
        end

        @nesting_root = nesting_root
        @boards_2d = []
        @gaps = []

        # Detect sheet properties
        detect_sheet_id
        detect_material_and_thickness
        detect_existing_boards
      end

      # =================================================================
      # Sheet Properties
      # =================================================================

      def detect_sheet_id
        return unless entity_valid?
        @sheet_id = @entity.get_attribute('ABF', 'sheet-id')
      end

      def detect_material_and_thickness
        return unless entity_valid?

        # Try to get from sheet attributes
        @material_name = @entity.get_attribute('ABF', 'material-name')
        @thickness_mm = @entity.get_attribute('ABF', 'thickness')

        # If not found, try to infer from first board on sheet
        if @material_name.nil? || @thickness_mm.nil?
          first_board = detect_first_board
          if first_board
            @material_name ||= first_board.material_name
            @thickness_mm ||= first_board.thickness
          end
        end

        @thickness_mm = @thickness_mm.to_f if @thickness_mm
      end

      def detect_first_board
        return nil unless entity_valid?

        # Find first 2D group on this sheet
        entity_groups.find do |group|
          group.get_attribute('ABF', 'is-2d-group') == true
        end
      end

      # =================================================================
      # Dimensions
      # =================================================================

      def width
        return DEFAULT_WIDTH unless @entity && @entity.valid?
        bounds.width / 1.mm
      end

      def height
        return DEFAULT_HEIGHT unless @entity && @entity.valid?
        bounds.height / 1.mm
      end

      def area
        width * height
      end

      def bounds
        @entity.bounds
      end

      def center
        bounds.center
      end

      # =================================================================
      # Board Management
      # =================================================================

      def detect_existing_boards
        @boards_2d = []
        return unless entity_valid?

        # Find all 2D groups on this sheet
        entity_groups.each do |group|
          next unless group.get_attribute('ABF', 'is-2d-group') == true

          # Try to find corresponding TwoDGroup in database
          two_d_group = find_or_create_two_d_group(group)
          @boards_2d << two_d_group if two_d_group
        end

        @boards_2d
      end

      def find_or_create_two_d_group(sketchup_group)
        # This is a simplified version - in production, you'd look up from database
        # For now, create a new TwoDGroup wrapper
        TwoDGroup.new(sketchup_group)
      rescue => e
        puts "Warning: Could not create TwoDGroup from #{sketchup_group.name}: #{e.message}"
        nil
      end

      def add_board(board_2d)
        return false unless board_2d.is_a?(TwoDGroup)
        return false if @boards_2d.include?(board_2d)

        @boards_2d << board_2d
        invalidate_gaps  # Gaps need to be recalculated
        true
      end

      def remove_board(board_2d)
        removed = @boards_2d.delete(board_2d)
        invalidate_gaps if removed
        removed
      end

      def board_count
        @boards_2d.count
      end

      def has_boards?
        @boards_2d.any?
      end

      # =================================================================
      # Area Utilization
      # =================================================================

      def used_area
        @boards_2d.sum(&:area)
      end

      def available_area
        area - used_area
      end

      def utilization
        return 0.0 if area.zero?
        used_area / area.to_f
      end

      def utilization_percentage
        (utilization * 100).round(2)
      end

      def is_full?(threshold = 0.95)
        utilization >= threshold
      end

      def is_empty?
        @boards_2d.empty?
      end

      # =================================================================
      # Gap Management
      # =================================================================

      def invalidate_gaps
        @gaps = []
        @gaps_calculated = false
      end

      def calculate_gaps
        # This will be implemented by GapCalculator service
        # For now, just mark as calculated
        @gaps_calculated = true
        @gaps
      end

      def gaps
        calculate_gaps unless @gaps_calculated
        @gaps
      end

      def largest_gap
        gaps.max_by { |g| g[:area] }
      end

      def has_gap_for_board?(board_2d, rotation = 0)
        return false unless board_2d

        # Get board dimensions with rotation
        if rotation == 90 || rotation == 270
          needed_width = board_2d.height
          needed_height = board_2d.width
        else
          needed_width = board_2d.width
          needed_height = board_2d.height
        end

        # Check if any gap is large enough
        gaps.any? do |gap|
          gap[:width] >= needed_width && gap[:height] >= needed_height
        end
      end

      def find_gap_for_board(board_2d, rotation = 0, min_spacing = 5.0)
        return nil unless board_2d

        # Get board dimensions with rotation
        if rotation == 90 || rotation == 270
          needed_width = board_2d.height + (min_spacing * 2)
          needed_height = board_2d.width + (min_spacing * 2)
        else
          needed_width = board_2d.width + (min_spacing * 2)
          needed_height = board_2d.height + (min_spacing * 2)
        end

        # Find first gap that fits (gaps are sorted by area, largest first)
        gaps.find do |gap|
          gap[:width] >= needed_width && gap[:height] >= needed_height
        end
      end

      # =================================================================
      # Material & Thickness Matching
      # =================================================================

      def matches_material?(material)
        return true if @material_name.nil?  # No material restriction
        return true if material.nil?        # Board has no material
        @material_name == material
      end

      def matches_thickness?(thickness)
        return true if @thickness_mm.nil?  # No thickness restriction
        return true if thickness.nil?      # Board has no thickness

        # Allow small tolerance (0.5mm)
        (@thickness_mm - thickness.to_f).abs < 0.5
      end

      def matches_board?(board_2d)
        return false unless board_2d

        material_match = matches_material?(board_2d.material_name)
        thickness_match = matches_thickness?(board_2d.thickness)

        material_match && thickness_match
      end

      # =================================================================
      # Placement Validation
      # =================================================================

      def can_fit?(board_2d, rotation = 0, min_spacing = 5.0)
        return false unless board_2d
        return false unless matches_board?(board_2d)

        # Check if board area fits in available area
        return false if board_2d.area > available_area

        # Check if there's a gap that can fit the board
        has_gap_for_board?(board_2d, rotation)
      end

      def within_bounds?(x, y, width, height)
        return false if x < 0 || y < 0
        return false if (x + width) > self.width
        return false if (y + height) > self.height
        true
      end

      # =================================================================
      # Classification
      # =================================================================

      def classification_key
        # Format: "Material_Thickness"
        mat = @material_name || 'nil'
        thick = @thickness_mm || 0.0
        "#{mat}_#{thick}"
      end

      # =================================================================
      # Validation
      # =================================================================

      def valid?
        validation_errors.empty?
      end

      def validation_errors
        errors = []

        errors << "Entity is nil or invalid" unless entity_valid?
        errors << "Width is zero or invalid" if width <= 0
        errors << "Height is zero or invalid" if height <= 0
        errors << "No nesting root reference" unless @nesting_root

        errors
      end

      # =================================================================
      # Display & Debug
      # =================================================================

      def print_info
        puts "=" * 70
        puts "SHEET INFO"
        puts "=" * 70
        puts ""
        puts "Entity: #{@entity ? @entity.name : 'nil'}"
        puts "Sheet ID: #{@sheet_id || 'N/A'}"
        puts ""
        puts "Material:"
        puts "  Name: #{@material_name || 'N/A'}"
        puts "  Thickness: #{@thickness_mm ? "#{@thickness_mm} mm" : 'N/A'}"
        puts "  Classification: #{classification_key}"
        puts ""
        puts "Dimensions:"
        puts "  Width: #{width.round(1)} mm"
        puts "  Height: #{height.round(1)} mm"
        puts "  Area: #{area.round(0)} mm²"
        puts ""
        puts "Boards:"
        puts "  Count: #{board_count}"
        puts "  Used area: #{used_area.round(0)} mm² (#{utilization_percentage}%)"
        puts "  Available area: #{available_area.round(0)} mm²"
        puts "  Is full: #{is_full?}"
        puts "  Is empty: #{is_empty?}"
        puts ""
        puts "Gaps:"
        puts "  Count: #{gaps.count}"
        if largest_gap
          puts "  Largest gap: #{largest_gap[:width].round(0)} × #{largest_gap[:height].round(0)} mm (#{largest_gap[:area].round(0)} mm²)"
        else
          puts "  Largest gap: None"
        end
        puts ""
        puts "Validation:"
        if valid?
          puts "  Status: ✓ VALID"
        else
          puts "  Status: ✗ INVALID"
          puts "  Errors:"
          validation_errors.each { |err| puts "    - #{err}" }
        end
        puts "=" * 70
      end

      def print_boards
        puts "Boards on sheet #{@sheet_id || @entity.name}:"
        if @boards_2d.empty?
          puts "  (No boards)"
        else
          @boards_2d.each_with_index do |board, i|
            puts "  #{i + 1}. #{board.width.round(0)} × #{board.height.round(0)} mm (#{board.area.round(0)} mm²)"
          end
        end
      end

      def print_gaps
        puts "Gaps on sheet #{@sheet_id || @entity.name}:"
        if gaps.empty?
          puts "  (No gaps calculated)"
        else
          gaps.each_with_index do |gap, i|
            puts "  #{i + 1}. Position (#{gap[:x].round(0)}, #{gap[:y].round(0)}) - #{gap[:width].round(0)} × #{gap[:height].round(0)} mm (#{gap[:area].round(0)} mm²)"
          end
        end
      end

      # =================================================================
      # Serialization
      # =================================================================

      def to_hash
        super.merge({
          sheet_id: @sheet_id,
          material_name: @material_name,
          thickness: @thickness_mm,
          classification_key: classification_key,
          width: width,
          height: height,
          area: area,
          board_count: board_count,
          used_area: used_area,
          available_area: available_area,
          utilization: utilization,
          utilization_percentage: utilization_percentage,
          is_full: is_full?,
          is_empty: is_empty?,
          gap_count: gaps.count,
          valid: valid?,
          validation_errors: validation_errors
        })
      end

      private

      def entity_valid?
        @entity && @entity.valid?
      end

      def entity_groups
        return [] unless entity_valid?
        @entity.entities.grep(Sketchup::Group)
      end

    end

  end
end
