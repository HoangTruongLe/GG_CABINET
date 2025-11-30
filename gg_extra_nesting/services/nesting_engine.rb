# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # NestingEngine - Main service for nesting boards into sheets
    # Orchestrates gap finding, placement, and collision detection
    class NestingEngine
      attr_accessor :allow_rotation, :create_new_sheets, :prefer_existing_sheets
      attr_accessor :min_spacing, :optimize_utilization
      attr_reader :nesting_root, :sheets, :placement_results, :progress_callback

      # Default settings
      DEFAULT_MIN_SPACING = 5.0  # mm
      DEFAULT_SHEET_WIDTH = 2440.0  # mm
      DEFAULT_SHEET_HEIGHT = 1220.0  # mm

      def initialize(nesting_root = nil)
        @nesting_root = nesting_root
        @sheets = []
        @placement_results = []

        # Settings
        @allow_rotation = true
        @create_new_sheets = true
        @prefer_existing_sheets = true
        @min_spacing = DEFAULT_MIN_SPACING
        @optimize_utilization = true

        # Progress callback
        @progress_callback = nil

        # Detect existing sheets if nesting_root provided
        detect_sheets if @nesting_root
      end

      # =================================================================
      # Sheet Detection
      # =================================================================

      def detect_sheets
        @sheets = []
        return unless @nesting_root && @nesting_root.entity

        # Find all sheet groups in nesting root
        @nesting_root.entity.entities.grep(Sketchup::Group).each do |group|
          next unless is_sheet_group?(group)

          sheet = Sheet.new(group, @nesting_root)
          @sheets << sheet if sheet.valid?
        end

        @sheets
      end

      def is_sheet_group?(group)
        # Check if group is a nesting sheet
        # Typically marked with ABF attribute or by structure
        group.get_attribute('ABF', 'is-sheet') == true ||
        group.get_attribute('ABF', 'sheet-id')
      end

      # =================================================================
      # Main Nesting Methods
      # =================================================================

      def nest_board(board_2d)
        return failure_result("Board is nil") unless board_2d
        return failure_result("Board is not a TwoDGroup") unless board_2d.is_a?(TwoDGroup)

        # 1. Find candidate sheets (material + thickness match)
        candidate_sheets = find_candidate_sheets(board_2d)

        # 2. Sort sheets by preference
        candidate_sheets = sort_sheets_by_preference(candidate_sheets) if @optimize_utilization

        # 3. Try to place on existing sheets
        candidate_sheets.each do |sheet|
          result = try_place_on_sheet(board_2d, sheet)
          return result if result[:success]
        end

        # 4. Create new sheet if allowed
        if @create_new_sheets
          return create_and_place_on_new_sheet(board_2d)
        end

        # 5. Failed to place
        failure_result("No suitable placement found")
      end

      def nest_boards(boards_2d, &block)
        @progress_callback = block if block_given?
        @placement_results = []

        boards_2d.each_with_index do |board_2d, index|
          # Progress callback
          if @progress_callback
            @progress_callback.call(index + 1, boards_2d.count, board_2d)
          end

          # Nest board
          result = nest_board(board_2d)
          @placement_results << result
        end

        @placement_results
      end

      # =================================================================
      # Sheet Finding
      # =================================================================

      def find_candidate_sheets(board_2d)
        # Filter sheets that match material and thickness
        @sheets.select do |sheet|
          sheet.matches_board?(board_2d) && !sheet.is_full?
        end
      end

      def sort_sheets_by_preference(sheets)
        if @prefer_existing_sheets
          # Prefer sheets with higher utilization (fill existing sheets first)
          sheets.sort_by { |s| -s.utilization }
        else
          # Prefer sheets with lower utilization (spread across sheets)
          sheets.sort_by { |s| s.utilization }
        end
      end

      # =================================================================
      # Placement Logic
      # =================================================================

      def try_place_on_sheet(board_2d, sheet)
        # Determine rotations to try
        rotations = @allow_rotation ? [0, 90, 180, 270] : [0]

        # Try each rotation
        rotations.each do |rotation|
          # Find gap for this rotation
          gap_calculator = GapCalculator.new(sheet)
          gap_calculator.min_spacing = @min_spacing

          gap = gap_calculator.find_gap_for_board(board_2d, rotation)
          next unless gap

          # Validate placement
          if can_place?(board_2d, sheet, gap, rotation)
            # Place board
            place_board(board_2d, sheet, gap, rotation)

            return success_result(board_2d, sheet, gap, rotation, false)
          end
        end

        # No placement found on this sheet
        nil
      end

      def can_place?(board_2d, sheet, gap, rotation)
        return false unless gap
        return false unless sheet.matches_board?(board_2d)

        # Get board dimensions with rotation
        if rotation == 90 || rotation == 270
          board_width = board_2d.height
          board_height = board_2d.width
        else
          board_width = board_2d.width
          board_height = board_2d.height
        end

        # Check gap size
        return false if gap[:width] < board_width
        return false if gap[:height] < board_height

        # Check sheet bounds
        return false unless sheet.within_bounds?(gap[:x], gap[:y], board_width, board_height)

        # Check for collisions with existing boards
        !has_collision?(board_2d, sheet, gap[:x], gap[:y], rotation)
      end

      def has_collision?(board_2d, sheet, x, y, rotation)
        # Create temporary placement to test collision
        test_board = board_2d.dup rescue board_2d

        # Apply temporary position
        test_board.place_at(x, y, rotation)

        # Check overlap with existing boards
        sheet.boards_2d.each do |existing_board|
          next unless existing_board.positioned?

          if test_board.overlaps_with?(existing_board)
            return true  # Collision detected
          end
        end

        false  # No collision
      end

      def place_board(board_2d, sheet, gap, rotation)
        # Place board at gap position with rotation
        board_2d.place_at(gap[:x], gap[:y], rotation)

        # Add board to sheet
        sheet.add_board(board_2d)

        # Apply transformation to SketchUp entity if present
        if board_2d.entity && board_2d.entity.valid?
          board_2d.entity.transformation = board_2d.nesting_transformation
        end
      end

      # =================================================================
      # New Sheet Creation
      # =================================================================

      def create_and_place_on_new_sheet(board_2d)
        # Create new sheet
        sheet = create_new_sheet(board_2d.material_name, board_2d.thickness)
        return failure_result("Failed to create new sheet") unless sheet

        # Add to sheets list
        @sheets << sheet

        # Place board at origin (0, 0)
        gap = { x: 0, y: 0, width: sheet.width, height: sheet.height, area: sheet.area }
        place_board(board_2d, sheet, gap, 0)

        success_result(board_2d, sheet, gap, 0, true)
      end

      def create_new_sheet(material_name, thickness)
        return nil unless @nesting_root && @nesting_root.entity

        # Create new SketchUp group for sheet
        sheet_group = @nesting_root.entity.entities.add_group
        sheet_group.name = "Sheet_#{material_name}_#{thickness}_#{Time.now.to_i}"

        # Set attributes
        sheet_group.set_attribute('ABF', 'is-sheet', true)
        sheet_group.set_attribute('ABF', 'material-name', material_name) if material_name
        sheet_group.set_attribute('ABF', 'thickness', thickness) if thickness
        sheet_group.set_attribute('ABF', 'sheet-id', generate_sheet_id)

        # Create Sheet model
        sheet = Sheet.new(sheet_group, @nesting_root)
        sheet.material_name = material_name
        sheet.thickness_mm = thickness

        # Draw sheet outline (for visualization)
        draw_sheet_outline(sheet_group, DEFAULT_SHEET_WIDTH, DEFAULT_SHEET_HEIGHT)

        sheet
      rescue => e
        puts "Error creating new sheet: #{e.message}"
        nil
      end

      def generate_sheet_id
        "sheet_#{Time.now.to_i}_#{rand(10000)}"
      end

      def draw_sheet_outline(group, width, height)
        # Draw rectangle outline
        points = [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(width.mm, 0, 0),
          Geom::Point3d.new(width.mm, height.mm, 0),
          Geom::Point3d.new(0, height.mm, 0)
        ]

        # Draw edges
        entities = group.entities
        points.each_with_index do |pt, i|
          next_pt = points[(i + 1) % points.length]
          entities.add_line(pt, next_pt)
        end
      rescue => e
        puts "Warning: Could not draw sheet outline: #{e.message}"
      end

      # =================================================================
      # Result Helpers
      # =================================================================

      def success_result(board_2d, sheet, gap, rotation, new_sheet)
        {
          success: true,
          board: board_2d,
          sheet: sheet,
          gap: gap,
          position: { x: gap[:x], y: gap[:y], rotation: rotation },
          new_sheet: new_sheet
        }
      end

      def failure_result(reason)
        {
          success: false,
          reason: reason
        }
      end

      # =================================================================
      # Statistics
      # =================================================================

      def total_boards_nested
        @placement_results.count { |r| r[:success] }
      end

      def total_boards_failed
        @placement_results.count { |r| !r[:success] }
      end

      def new_sheets_created
        @placement_results.count { |r| r[:success] && r[:new_sheet] }
      end

      def average_utilization
        return 0.0 if @sheets.empty?
        total_utilization = @sheets.sum(&:utilization)
        (total_utilization / @sheets.count * 100).round(2)
      end

      def total_area_used
        @sheets.sum(&:used_area)
      end

      def total_area_available
        @sheets.sum(&:area)
      end

      # =================================================================
      # Progress Callback
      # =================================================================

      def on_progress(&block)
        @progress_callback = block
      end

      # =================================================================
      # Display & Debug
      # =================================================================

      def print_summary
        puts "=" * 70
        puts "NESTING ENGINE SUMMARY"
        puts "=" * 70
        puts ""
        puts "Sheets:"
        puts "  Total: #{@sheets.count}"
        puts "  New sheets created: #{new_sheets_created}"
        puts ""
        puts "Boards:"
        puts "  Total processed: #{@placement_results.count}"
        puts "  Successfully nested: #{total_boards_nested}"
        puts "  Failed: #{total_boards_failed}"
        puts ""
        puts "Utilization:"
        puts "  Average: #{average_utilization}%"
        puts "  Total area used: #{total_area_used.round(0)} mm²"
        puts "  Total area available: #{total_area_available.round(0)} mm²"
        puts ""
        puts "Settings:"
        puts "  Allow rotation: #{@allow_rotation}"
        puts "  Create new sheets: #{@create_new_sheets}"
        puts "  Prefer existing sheets: #{@prefer_existing_sheets}"
        puts "  Min spacing: #{@min_spacing} mm"
        puts "  Optimize utilization: #{@optimize_utilization}"
        puts "=" * 70
      end

      def print_placement_results
        puts "\nPlacement Results:"
        @placement_results.each_with_index do |result, i|
          puts "\n#{i + 1}. #{result[:success] ? '✓' : '✗'}"
          if result[:success]
            board = result[:board]
            sheet = result[:sheet]
            pos = result[:position]
            puts "   Board: #{board.width.round(0)} × #{board.height.round(0)} mm"
            puts "   Sheet: #{sheet.classification_key}"
            puts "   Position: (#{pos[:x].round(0)}, #{pos[:y].round(0)}) @ #{pos[:rotation]}°"
            puts "   New sheet: #{result[:new_sheet]}"
          else
            puts "   Reason: #{result[:reason]}"
          end
        end
      end

      def print_sheets_info
        puts "\nSheets Information:"
        @sheets.each_with_index do |sheet, i|
          puts "\n#{i + 1}. #{sheet.classification_key}"
          puts "   Size: #{sheet.width.round(0)} × #{sheet.height.round(0)} mm"
          puts "   Boards: #{sheet.board_count}"
          puts "   Utilization: #{sheet.utilization_percentage}%"
          puts "   Available area: #{sheet.available_area.round(0)} mm²"
        end
      end

      # =================================================================
      # Validation
      # =================================================================

      def validate_nesting
        errors = []

        # Check all boards are placed
        @placement_results.each_with_index do |result, i|
          unless result[:success]
            errors << "Board #{i + 1} failed to place: #{result[:reason]}"
          end
        end

        # Check for overlaps
        @sheets.each_with_index do |sheet, sheet_index|
          sheet.boards_2d.each_with_index do |board1, i|
            sheet.boards_2d[(i + 1)..-1].each_with_index do |board2, j|
              if board1.overlaps_with?(board2)
                errors << "Sheet #{sheet_index + 1}: Board #{i + 1} overlaps with Board #{i + j + 2}"
              end
            end
          end
        end

        errors
      end

      def valid_nesting?
        validate_nesting.empty?
      end

      # =================================================================
      # Class Methods
      # =================================================================

      class << self
        def nest_board(nesting_root, board_2d, options = {})
          engine = new(nesting_root)
          apply_options(engine, options)
          engine.nest_board(board_2d)
        end

        def nest_boards(nesting_root, boards_2d, options = {}, &block)
          engine = new(nesting_root)
          apply_options(engine, options)
          engine.nest_boards(boards_2d, &block)
        end

        def apply_options(engine, options)
          engine.allow_rotation = options[:allow_rotation] if options.key?(:allow_rotation)
          engine.create_new_sheets = options[:create_new_sheets] if options.key?(:create_new_sheets)
          engine.prefer_existing_sheets = options[:prefer_existing_sheets] if options.key?(:prefer_existing_sheets)
          engine.min_spacing = options[:min_spacing] if options[:min_spacing]
          engine.optimize_utilization = options[:optimize_utilization] if options.key?(:optimize_utilization)
        end
      end

    end

  end
end
