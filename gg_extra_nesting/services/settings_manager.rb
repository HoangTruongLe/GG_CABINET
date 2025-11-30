# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # Service for managing nesting settings
    # Reads from N1, allows user overrides, stores in DB
    # Phase 2.5: Settings Management
    class SettingsManager
      attr_reader :settings

      # Common tool diameters in mm
      COMMON_TOOL_DIAMETERS = [2, 3, 4, 5, 6, 8, 10, 12].freeze
      TOOL_DIA_TOLERANCE = 0.5 # mm

      # Default settings
      DEFAULTS = {
        # Dimensions (mm)
        sheet_width: 2440.0,
        sheet_height: 1220.0,
        tool_diameter: 6.0,
        clearance: 2.0,
        border_gap: 10.0,

        # Behavior
        allow_rotation: false,
        allow_nesting_inside: false,

        # Sources (for tracking where values came from)
        sheet_width_source: 'default',
        sheet_height_source: 'default',
        tool_diameter_source: 'default',
        clearance_source: 'default',
        border_gap_source: 'default'
      }.freeze

      def initialize
        @settings = DEFAULTS.dup
        @n1_root = nil
        @db = Database.instance

        # Load settings from DB
        load_from_db
      end

      # =================================================================
      # N1 Detection & Reading
      # =================================================================

      # Find N1 nesting root in model
      def find_n1_root(model = Sketchup.active_model)
        @n1_root = model.entities.find do |entity|
          entity.is_a?(Sketchup::Group) &&
          entity.get_attribute('ABF', 'is-nesting-root') == true
        end

        @n1_root
      end

      # Read all settings from N1
      def read_from_n1(n1_root = nil)
        n1_root ||= find_n1_root
        return nil unless n1_root

        @n1_root = n1_root

        # Read sheet dimensions from N1
        read_sheet_dimensions_from_n1

        # Read tool diameter and clearance from board spacing
        read_tool_settings_from_n1

        # Read border gap from N1
        read_border_gap_from_n1

        @settings
      end

      # Read sheet dimensions from N1 bounds
      def read_sheet_dimensions_from_n1
        return unless @n1_root

        bounds = @n1_root.bounds
        width = bounds.width / 1.mm
        height = bounds.height / 1.mm

        # Only update if not user-overridden
        if @settings[:sheet_width_source] != 'user'
          @settings[:sheet_width] = width.round(1)
          @settings[:sheet_width_source] = 'n1'
        end

        if @settings[:sheet_height_source] != 'user'
          @settings[:sheet_height] = height.round(1)
          @settings[:sheet_height_source] = 'n1'
        end
      end

      # Calculate tool diameter and clearance from board spacing in N1
      def read_tool_settings_from_n1
        return unless @n1_root

        # Find all boards in N1
        boards = find_boards_in_n1

        return if boards.count < 2

        # Calculate spacing between adjacent boards
        spacing = calculate_board_spacing(boards)

        return unless spacing && spacing > 0

        # Spacing = tool_diameter + clearance
        # Try to match common tool diameters
        tool_dia = guess_tool_diameter(spacing)
        clearance = spacing - tool_dia

        # Only update if not user-overridden
        if @settings[:tool_diameter_source] != 'user'
          @settings[:tool_diameter] = tool_dia.round(1)
          @settings[:tool_diameter_source] = 'n1'
        end

        if @settings[:clearance_source] != 'user'
          @settings[:clearance] = clearance.round(1)
          @settings[:clearance_source] = 'n1'
        end
      end

      # Read border gap from N1
      def read_border_gap_from_n1
        return unless @n1_root

        # Find boards and calculate distance to N1 boundary
        boards = find_boards_in_n1
        return if boards.empty?

        n1_bounds = @n1_root.bounds

        # Find minimum distance from any board to N1 boundary
        min_gap = boards.map do |board|
          board_bounds = board.bounds
          calculate_border_gap(board_bounds, n1_bounds)
        end.min

        return unless min_gap && min_gap > 0

        # Only update if not user-overridden
        if @settings[:border_gap_source] != 'user'
          @settings[:border_gap] = min_gap.round(1)
          @settings[:border_gap_source] = 'n1'
        end
      end

      # =================================================================
      # User Overrides
      # =================================================================

      # Set sheet dimensions (user override)
      def set_sheet_dimensions(width, height)
        @settings[:sheet_width] = width.to_f.round(1)
        @settings[:sheet_height] = height.to_f.round(1)
        @settings[:sheet_width_source] = 'user'
        @settings[:sheet_height_source] = 'user'

        save_to_db
      end

      # Set tool diameter (user override)
      def set_tool_diameter(diameter)
        @settings[:tool_diameter] = diameter.to_f.round(1)
        @settings[:tool_diameter_source] = 'user'

        save_to_db
      end

      # Set clearance (user override)
      def set_clearance(clearance)
        @settings[:clearance] = clearance.to_f.round(1)
        @settings[:clearance_source] = 'user'

        save_to_db
      end

      # Set border gap (user override)
      def set_border_gap(gap)
        @settings[:border_gap] = gap.to_f.round(1)
        @settings[:border_gap_source] = 'user'

        save_to_db
      end

      # Set rotation behavior
      def set_allow_rotation(allow)
        @settings[:allow_rotation] = !!allow
        save_to_db
      end

      # Set nesting inside behavior
      def set_allow_nesting_inside(allow)
        @settings[:allow_nesting_inside] = !!allow
        save_to_db
      end

      # Reset setting to N1 or default value
      def reset_setting(key)
        case key
        when :sheet_width, :sheet_height
          @settings["#{key}_source".to_sym] = 'default'
          read_sheet_dimensions_from_n1 if @n1_root
        when :tool_diameter, :clearance
          @settings["#{key}_source".to_sym] = 'default'
          read_tool_settings_from_n1 if @n1_root
        when :border_gap
          @settings["#{key}_source".to_sym] = 'default'
          read_border_gap_from_n1 if @n1_root
        when :allow_rotation, :allow_nesting_inside
          @settings[key] = DEFAULTS[key]
        end

        save_to_db
      end

      # Reset all settings
      def reset_all
        @settings = DEFAULTS.dup
        read_from_n1 if @n1_root
        save_to_db
      end

      # =================================================================
      # Helper Methods
      # =================================================================

      # Find all boards in N1
      def find_boards_in_n1
        return [] unless @n1_root

        boards = []

        @n1_root.entities.each do |entity|
          if entity.is_a?(Sketchup::Group) &&
             entity.get_attribute('ABF', 'is-board') == true
            boards << entity
          end
        end

        boards
      end

      # Calculate spacing between adjacent boards
      def calculate_board_spacing(boards)
        return nil if boards.count < 2

        # Sort boards by X position
        sorted = boards.sort_by { |b| b.bounds.min.x }

        # Calculate spacing between consecutive boards
        spacings = []

        sorted.each_cons(2) do |board1, board2|
          # Distance = board2.min.x - board1.max.x
          gap = (board2.bounds.min.x - board1.bounds.max.x) / 1.mm
          spacings << gap if gap > 0
        end

        return nil if spacings.empty?

        # Return average spacing
        spacings.sum / spacings.count
      end

      # Guess tool diameter from total spacing
      def guess_tool_diameter(total_spacing)
        # Spacing = tool_diameter + clearance
        # Typical clearance is 1-3mm
        # Try to match common tool diameters

        COMMON_TOOL_DIAMETERS.each do |tool_dia|
          # Assume clearance is rest of spacing
          clearance = total_spacing - tool_dia

          # Clearance should be positive and reasonable (0.5mm to 5mm)
          if clearance >= 0.5 && clearance <= 5.0
            return tool_dia
          end
        end

        # If no common diameter matches, assume 50/50 split
        # or use largest common diameter that fits
        max_tool = COMMON_TOOL_DIAMETERS.select { |d| d < total_spacing }.max
        max_tool || (total_spacing / 2.0)
      end

      # Calculate border gap from board to N1 boundary
      def calculate_border_gap(board_bounds, n1_bounds)
        # Calculate minimum distance from board edges to N1 edges
        gaps = [
          (board_bounds.min.x - n1_bounds.min.x) / 1.mm,  # Left gap
          (n1_bounds.max.x - board_bounds.max.x) / 1.mm,  # Right gap
          (board_bounds.min.y - n1_bounds.min.y) / 1.mm,  # Front gap
          (n1_bounds.max.y - board_bounds.max.y) / 1.mm   # Back gap
        ]

        gaps.select { |g| g > 0 }.min || 0
      end

      # =================================================================
      # Database Persistence
      # =================================================================

      # Save settings to database
      def save_to_db
        @db.save('settings', 'nesting_settings', @settings)
      end

      # Load settings from database
      def load_from_db
        saved = @db.load('settings', 'nesting_settings')

        if saved
          @settings.merge!(saved)
        end
      end

      # =================================================================
      # Getters (convenience methods)
      # =================================================================

      def sheet_width
        @settings[:sheet_width]
      end

      def sheet_height
        @settings[:sheet_height]
      end

      def tool_diameter
        @settings[:tool_diameter]
      end

      def clearance
        @settings[:clearance]
      end

      def border_gap
        @settings[:border_gap]
      end

      def allow_rotation?
        @settings[:allow_rotation]
      end

      def allow_nesting_inside?
        @settings[:allow_nesting_inside]
      end

      # Get total spacing (tool_diameter + clearance)
      def total_spacing
        tool_diameter + clearance
      end

      # Get usable sheet area (accounting for border gaps)
      def usable_width
        sheet_width - (2 * border_gap)
      end

      def usable_height
        sheet_height - (2 * border_gap)
      end

      # =================================================================
      # Validation
      # =================================================================

      def valid?
        validation_errors.empty?
      end

      def validation_errors
        errors = []

        errors << "Sheet width must be > 0" if sheet_width <= 0
        errors << "Sheet height must be > 0" if sheet_height <= 0
        errors << "Tool diameter must be > 0" if tool_diameter <= 0
        errors << "Clearance must be >= 0" if clearance < 0
        errors << "Border gap must be >= 0" if border_gap < 0

        # Check if usable area is reasonable
        if usable_width <= 0
          errors << "Border gap too large (no usable width)"
        end

        if usable_height <= 0
          errors << "Border gap too large (no usable height)"
        end

        errors
      end

      # =================================================================
      # Display & Debug
      # =================================================================

      def print_settings
        puts "=" * 70
        puts "NESTING SETTINGS"
        puts "=" * 70
        puts ""
        puts "Sheet Dimensions:"
        puts "  Width: #{sheet_width} mm (#{@settings[:sheet_width_source]})"
        puts "  Height: #{sheet_height} mm (#{@settings[:sheet_height_source]})"
        puts "  Usable Width: #{usable_width.round(1)} mm"
        puts "  Usable Height: #{usable_height.round(1)} mm"
        puts ""
        puts "Tool Settings:"
        puts "  Tool Diameter: #{tool_diameter} mm (#{@settings[:tool_diameter_source]})"
        puts "  Clearance: #{clearance} mm (#{@settings[:clearance_source]})"
        puts "  Total Spacing: #{total_spacing} mm"
        puts ""
        puts "Borders:"
        puts "  Border Gap: #{border_gap} mm (#{@settings[:border_gap_source]})"
        puts ""
        puts "Nesting Behavior:"
        puts "  Allow Rotation: #{allow_rotation? ? 'Yes' : 'No'}"
        puts "  Allow Nesting Inside: #{allow_nesting_inside? ? 'Yes' : 'No'}"
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

      # =================================================================
      # Serialization
      # =================================================================

      def to_hash
        {
          sheet_width: sheet_width,
          sheet_height: sheet_height,
          tool_diameter: tool_diameter,
          clearance: clearance,
          border_gap: border_gap,
          total_spacing: total_spacing,
          usable_width: usable_width,
          usable_height: usable_height,
          allow_rotation: allow_rotation?,
          allow_nesting_inside: allow_nesting_inside?,
          sources: {
            sheet_width: @settings[:sheet_width_source],
            sheet_height: @settings[:sheet_height_source],
            tool_diameter: @settings[:tool_diameter_source],
            clearance: @settings[:clearance_source],
            border_gap: @settings[:border_gap_source]
          },
          valid: valid?,
          validation_errors: validation_errors
        }
      end

      # =================================================================
      # Class Methods (convenience)
      # =================================================================

      class << self
        # Quick read from N1
        def read_from_n1(model = Sketchup.active_model)
          manager = new
          manager.read_from_n1
          manager
        end

        # Get current settings
        def current
          manager = new
          manager.load_from_db
          manager
        end

        # Quick print
        def print_current
          current.print_settings
        end
      end
    end

  end
end
