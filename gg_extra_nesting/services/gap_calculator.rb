# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # GapCalculator - finds empty rectangular spaces in sheets
    # Uses corner-based gap detection algorithm
    class GapCalculator
      attr_accessor :min_gap_size, :min_spacing, :allow_rotation

      # Minimum gap dimensions (mm)
      DEFAULT_MIN_GAP_SIZE = 100.0
      # Minimum spacing between boards (mm)
      DEFAULT_MIN_SPACING = 5.0

      def initialize(sheet = nil)
        @sheet = sheet
        @min_gap_size = DEFAULT_MIN_GAP_SIZE
        @min_spacing = DEFAULT_MIN_SPACING
        @allow_rotation = true
      end

      # =================================================================
      # Main Gap Detection
      # =================================================================

      def find_gaps(sheet = nil)
        target_sheet = sheet || @sheet
        return [] unless target_sheet

        # Start with full sheet as one big gap
        if target_sheet.is_empty?
          return [create_gap(0, 0, target_sheet.width, target_sheet.height)]
        end

        # Find gaps using corner-based algorithm
        gaps = find_gaps_corner_based(target_sheet)

        # Filter by minimum size
        gaps = filter_by_min_size(gaps)

        # Sort by area (largest first)
        gaps.sort_by! { |g| -g[:area] }

        gaps
      end

      # =================================================================
      # Corner-Based Gap Detection
      # =================================================================

      def find_gaps_corner_based(sheet)
        gaps = []

        # Try each existing board's corners
        sheet.boards_2d.each do |board|
          gaps += find_gaps_around_board(board, sheet)
        end

        # Try sheet corners (0,0) and (width,0), (0,height), (width,height)
        gaps += find_gaps_at_sheet_corners(sheet)

        # Remove duplicates and overlapping gaps
        gaps = merge_overlapping_gaps(gaps)

        gaps
      end

      def find_gaps_around_board(board, sheet)
        gaps = []
        return gaps unless board.positioned?

        # Get board position and dimensions
        pos = board.nesting_position
        x = pos[:x]
        y = pos[:y]
        w = board.width
        h = board.height

        # Try 4 corners of the board (with spacing)
        corners = [
          { x: x + w + @min_spacing, y: y },                    # Right edge
          { x: x, y: y + h + @min_spacing },                    # Top edge
          { x: x - @min_gap_size - @min_spacing, y: y },       # Left edge
          { x: x, y: y - @min_gap_size - @min_spacing }        # Bottom edge
        ]

        corners.each do |corner|
          gap = find_max_rectangle_from_point(corner[:x], corner[:y], sheet)
          gaps << gap if gap && gap[:area] > 0
        end

        gaps
      end

      def find_gaps_at_sheet_corners(sheet)
        gaps = []

        # Try all four corners of the sheet
        corners = [
          { x: 0, y: 0 },                           # Bottom-left
          { x: sheet.width - @min_gap_size, y: 0 }, # Bottom-right
          { x: 0, y: sheet.height - @min_gap_size }, # Top-left
          { x: sheet.width - @min_gap_size, y: sheet.height - @min_gap_size } # Top-right
        ]

        corners.each do |corner|
          gap = find_max_rectangle_from_point(corner[:x], corner[:y], sheet)
          gaps << gap if gap && gap[:area] > 0
        end

        gaps
      end

      # =================================================================
      # Max Rectangle Finding
      # =================================================================

      def find_max_rectangle_from_point(start_x, start_y, sheet)
        # Ensure start point is within sheet bounds
        return nil if start_x < 0 || start_y < 0
        return nil if start_x >= sheet.width || start_y >= sheet.height

        # Find maximum width from this point
        max_width = find_max_width_from_point(start_x, start_y, sheet)
        return nil if max_width < @min_gap_size

        # Find maximum height from this point
        max_height = find_max_height_from_point(start_x, start_y, sheet, max_width)
        return nil if max_height < @min_gap_size

        # Create gap rectangle
        create_gap(start_x, start_y, max_width, max_height)
      end

      def find_max_width_from_point(start_x, start_y, sheet)
        # Maximum width is limited by sheet boundary
        max_width = sheet.width - start_x

        # Check for intersecting boards
        sheet.boards_2d.each do |board|
          next unless board.positioned?

          pos = board.nesting_position
          board_x = pos[:x]
          board_y = pos[:y]
          board_w = board.width
          board_h = board.height

          # Check if board intersects this horizontal line
          if line_intersects_rect?(start_x, start_y, start_x + max_width, start_y,
                                   board_x - @min_spacing, board_y - @min_spacing,
                                   board_w + (2 * @min_spacing), board_h + (2 * @min_spacing))

            # Limit width to before this board
            if board_x > start_x
              max_width = [max_width, board_x - start_x - @min_spacing].min
            end
          end
        end

        max_width
      end

      def find_max_height_from_point(start_x, start_y, sheet, width)
        # Maximum height is limited by sheet boundary
        max_height = sheet.height - start_y

        # Check for intersecting boards
        sheet.boards_2d.each do |board|
          next unless board.positioned?

          pos = board.nesting_position
          board_x = pos[:x]
          board_y = pos[:y]
          board_w = board.width
          board_h = board.height

          # Check if board intersects this vertical line within the width
          if rect_intersects_rect?(start_x, start_y, width, max_height,
                                   board_x - @min_spacing, board_y - @min_spacing,
                                   board_w + (2 * @min_spacing), board_h + (2 * @min_spacing))

            # Limit height to before this board
            if board_y > start_y
              max_height = [max_height, board_y - start_y - @min_spacing].min
            end
          end
        end

        max_height
      end

      # =================================================================
      # Geometric Helpers
      # =================================================================

      def line_intersects_rect?(x1, y1, x2, y2, rect_x, rect_y, rect_w, rect_h)
        # Check if horizontal/vertical line intersects rectangle
        # Line from (x1,y1) to (x2,y2)
        # Rectangle at (rect_x, rect_y) with size (rect_w, rect_h)

        # Horizontal line
        if y1 == y2
          y = y1
          return false if y < rect_y || y > rect_y + rect_h
          return false if x2 < rect_x || x1 > rect_x + rect_w
          return true
        end

        # Vertical line
        if x1 == x2
          x = x1
          return false if x < rect_x || x > rect_x + rect_w
          return false if y2 < rect_y || y1 > rect_y + rect_h
          return true
        end

        false
      end

      def rect_intersects_rect?(x1, y1, w1, h1, x2, y2, w2, h2)
        # Check if two rectangles intersect
        return false if x1 + w1 < x2  # rect1 is left of rect2
        return false if x1 > x2 + w2  # rect1 is right of rect2
        return false if y1 + h1 < y2  # rect1 is below rect2
        return false if y1 > y2 + h2  # rect1 is above rect2
        true
      end

      def point_in_board?(x, y, board)
        return false unless board.positioned?

        pos = board.nesting_position
        board_x = pos[:x]
        board_y = pos[:y]
        board_w = board.width
        board_h = board.height

        # Add spacing buffer
        board_x -= @min_spacing
        board_y -= @min_spacing
        board_w += (2 * @min_spacing)
        board_h += (2 * @min_spacing)

        x >= board_x && x <= (board_x + board_w) &&
        y >= board_y && y <= (board_y + board_h)
      end

      # =================================================================
      # Gap Filtering & Merging
      # =================================================================

      def filter_by_min_size(gaps)
        gaps.select do |gap|
          gap[:width] >= @min_gap_size && gap[:height] >= @min_gap_size
        end
      end

      def merge_overlapping_gaps(gaps)
        # Remove gaps that are completely contained in other gaps
        filtered_gaps = []

        gaps.each do |gap1|
          is_contained = gaps.any? do |gap2|
            next false if gap1 == gap2
            gap_contains_gap?(gap2, gap1)
          end

          filtered_gaps << gap1 unless is_contained
        end

        filtered_gaps
      end

      def gap_contains_gap?(outer, inner)
        # Check if outer gap completely contains inner gap
        outer[:x] <= inner[:x] &&
        outer[:y] <= inner[:y] &&
        (outer[:x] + outer[:width]) >= (inner[:x] + inner[:width]) &&
        (outer[:y] + outer[:height]) >= (inner[:y] + inner[:height])
      end

      # =================================================================
      # Gap Creation
      # =================================================================

      def create_gap(x, y, width, height)
        {
          x: x.round(2),
          y: y.round(2),
          width: width.round(2),
          height: height.round(2),
          area: (width * height).round(2)
        }
      end

      # =================================================================
      # Board Fitting
      # =================================================================

      def find_gap_for_board(board_2d, rotation = 0, sheet = nil)
        target_sheet = sheet || @sheet
        return nil unless target_sheet && board_2d

        # Get board dimensions with rotation
        if rotation == 90 || rotation == 270
          needed_width = board_2d.height + (2 * @min_spacing)
          needed_height = board_2d.width + (2 * @min_spacing)
        else
          needed_width = board_2d.width + (2 * @min_spacing)
          needed_height = board_2d.height + (2 * @min_spacing)
        end

        # Find gaps
        gaps = find_gaps(target_sheet)

        # Find first gap that fits
        gaps.find do |gap|
          gap[:width] >= needed_width && gap[:height] >= needed_height
        end
      end

      def find_best_gap(board_2d, try_rotations: true, sheet: nil)
        target_sheet = sheet || @sheet
        return nil unless target_sheet && board_2d

        best_gap = nil
        best_rotation = 0
        best_fit_score = Float::INFINITY

        # Try different rotations
        rotations = try_rotations ? [0, 90, 180, 270] : [0]

        rotations.each do |rotation|
          gap = find_gap_for_board(board_2d, rotation, target_sheet)
          next unless gap

          # Calculate fit score (lower is better)
          # Prefer gaps that are close to board size (minimize wasted space)
          if rotation == 90 || rotation == 270
            wasted_area = gap[:area] - (board_2d.height * board_2d.width)
          else
            wasted_area = gap[:area] - (board_2d.width * board_2d.height)
          end

          if wasted_area < best_fit_score
            best_gap = gap
            best_rotation = rotation
            best_fit_score = wasted_area
          end
        end

        return nil unless best_gap

        {
          gap: best_gap,
          rotation: best_rotation,
          wasted_area: best_fit_score
        }
      end

      # =================================================================
      # Validation
      # =================================================================

      def gap_is_valid?(gap, sheet)
        return false unless gap
        return false unless sheet

        # Check minimum size
        return false if gap[:width] < @min_gap_size
        return false if gap[:height] < @min_gap_size

        # Check within sheet bounds
        return false if gap[:x] < 0 || gap[:y] < 0
        return false if (gap[:x] + gap[:width]) > sheet.width
        return false if (gap[:y] + gap[:height]) > sheet.height

        # Check no boards intersect this gap
        sheet.boards_2d.each do |board|
          next unless board.positioned?

          pos = board.nesting_position
          if rect_intersects_rect?(gap[:x], gap[:y], gap[:width], gap[:height],
                                   pos[:x], pos[:y], board.width, board.height)
            return false
          end
        end

        true
      end

      # =================================================================
      # Display & Debug
      # =================================================================

      def print_gaps(gaps = nil)
        target_gaps = gaps || find_gaps

        puts "=" * 50
        puts "GAP CALCULATOR - Gaps Found: #{target_gaps.count}"
        puts "=" * 50
        puts ""

        if target_gaps.empty?
          puts "No gaps found"
        else
          target_gaps.each_with_index do |gap, i|
            puts "Gap #{i + 1}:"
            puts "  Position: (#{gap[:x].round(0)}, #{gap[:y].round(0)})"
            puts "  Size: #{gap[:width].round(0)} × #{gap[:height].round(0)} mm"
            puts "  Area: #{gap[:area].round(0)} mm²"
            puts ""
          end
        end

        puts "Settings:"
        puts "  Min gap size: #{@min_gap_size} mm"
        puts "  Min spacing: #{@min_spacing} mm"
        puts "=" * 50
      end

      def visualize_gaps(sheet, gaps = nil)
        target_gaps = gaps || find_gaps(sheet)

        puts "\nSheet Visualization:"
        puts "┌#{'─' * (sheet.width / 50).to_i}┐"

        # Simple ASCII visualization
        puts "│ Sheet: #{sheet.width.round(0)} × #{sheet.height.round(0)} mm"
        puts "│ Boards: #{sheet.board_count}"
        puts "│ Gaps: #{target_gaps.count}"
        puts "│"

        target_gaps.first(5).each_with_index do |gap, i|
          puts "│ Gap #{i + 1}: #{gap[:width].round(0)}×#{gap[:height].round(0)} at (#{gap[:x].round(0)},#{gap[:y].round(0)})"
        end

        puts "└#{'─' * (sheet.width / 50).to_i}┘"
      end

      # =================================================================
      # Class Methods
      # =================================================================

      class << self
        def find_gaps(sheet, options = {})
          calculator = new(sheet)
          calculator.min_gap_size = options[:min_gap_size] if options[:min_gap_size]
          calculator.min_spacing = options[:min_spacing] if options[:min_spacing]
          calculator.allow_rotation = options[:allow_rotation] if options.key?(:allow_rotation)
          calculator.find_gaps
        end

        def find_gap_for_board(sheet, board_2d, rotation = 0, options = {})
          calculator = new(sheet)
          calculator.min_gap_size = options[:min_gap_size] if options[:min_gap_size]
          calculator.min_spacing = options[:min_spacing] if options[:min_spacing]
          calculator.find_gap_for_board(board_2d, rotation)
        end

        def find_best_gap(sheet, board_2d, options = {})
          calculator = new(sheet)
          calculator.min_gap_size = options[:min_gap_size] if options[:min_gap_size]
          calculator.min_spacing = options[:min_spacing] if options[:min_spacing]
          try_rotations = options.fetch(:try_rotations, true)
          calculator.find_best_gap(board_2d, try_rotations: try_rotations)
        end
      end

    end

  end
end
