# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # Service for validating board geometry
    # Phase 2: Complete implementation
    class BoardValidator
      attr_reader :validation_results

      def initialize
        @validation_results = {}
      end

      # =================================================================
      # Single Board Validation
      # =================================================================

      # Validate single board with detailed results
      def validate_board(board)
        results = {
          board_id: board.entity_id,
          board_name: board.entity.name,
          valid: board.valid?,
          errors: board.validation_errors,
          warnings: [],
          info: {},
          validated_at: Time.now
        }

        # Add warnings for non-critical issues
        results[:warnings] = check_warnings(board)

        # Add info
        results[:info] = {
          material: board.material_name,
          thickness: board.thickness,
          classification: board.classification_key,
          has_label: board.labeled?,
          can_be_labeled: board.can_be_labeled?,
          can_be_nested: board.can_be_nested?,
          has_intersections: board.has_intersections?
        }

        results
      end

      # Check for warnings (non-critical issues)
      def check_warnings(board)
        warnings = []

        # Material can be nil - no warning needed

        # Check thickness snapping
        unless Board::COMMON_THICKNESSES.include?(board.thickness)
          warnings << "Thickness #{board.thickness}mm is not a common thickness"
        end

        # Check for missing label (warning if board is valid but not labeled)
        if board.valid? && !board.labeled?
          warnings << "Valid board but no label found (can be labeled)"
        end

        # Check if board can be nested
        if board.labeled? && !board.valid?
          warnings << "Board has label but is invalid (cannot be nested)"
        end

        # Check label rotation
        if board.label && board.label_rotation == 0
          warnings << "Label rotation is 0° (may need adjustment for nesting)"
        end

        # Check board size
        dims = board.dimensions
        if dims[:length] > 2500 || dims[:width] > 1300
          warnings << "Board dimensions exceed standard sheet size (2440x1220mm)"
        end

        if dims[:length] < 50 || dims[:width] < 50
          warnings << "Board dimensions are very small (< 50mm)"
        end

        warnings
      end

      # =================================================================
      # Batch Validation
      # =================================================================

      # Validate multiple boards
      def validate_boards(boards)
        results = boards.map { |board| validate_board(board) }

        @validation_results = {
          total_boards: boards.count,
          valid_boards: results.count { |r| r[:valid] },
          invalid_boards: results.count { |r| !r[:valid] },
          boards_with_warnings: results.count { |r| r[:warnings].any? },
          boards_with_errors: results.count { |r| r[:errors].any? },
          results: results,
          validated_at: Time.now
        }

        @validation_results
      end

      # Get summary of validation results
      def validation_summary
        return nil unless @validation_results

        {
          total: @validation_results[:total_boards],
          valid: @validation_results[:valid_boards],
          invalid: @validation_results[:invalid_boards],
          pass_rate: (@validation_results[:valid_boards].to_f / @validation_results[:total_boards] * 100).round(1)
        }
      end

      # =================================================================
      # Error Analysis
      # =================================================================

      # Get all error types and their frequency
      def error_frequency
        return {} unless @validation_results

        errors = {}

        @validation_results[:results].each do |result|
          result[:errors].each do |error|
            errors[error] ||= 0
            errors[error] += 1
          end
        end

        errors.sort_by { |_, count| -count }.to_h
      end

      # Get all warning types and their frequency
      def warning_frequency
        return {} unless @validation_results

        warnings = {}

        @validation_results[:results].each do |result|
          result[:warnings].each do |warning|
            warnings[warning] ||= 0
            warnings[warning] += 1
          end
        end

        warnings.sort_by { |_, count| -count }.to_h
      end

      # Get boards with specific error
      def boards_with_error(error_message)
        return [] unless @validation_results

        @validation_results[:results].select do |result|
          result[:errors].include?(error_message)
        end
      end

      # Get boards with specific warning
      def boards_with_warning(warning_message)
        return [] unless @validation_results

        @validation_results[:results].select do |result|
          result[:warnings].include?(warning_message)
        end
      end

      # =================================================================
      # Filtering & Reporting
      # =================================================================

      # Get only valid boards from results
      def valid_boards
        return [] unless @validation_results

        @validation_results[:results].select { |r| r[:valid] }
      end

      # Get only invalid boards from results
      def invalid_boards
        return [] unless @validation_results

        @validation_results[:results].reject { |r| r[:valid] }
      end

      # Get boards with warnings
      def boards_with_warnings
        return [] unless @validation_results

        @validation_results[:results].select { |r| r[:warnings].any? }
      end

      # =================================================================
      # Printing & Display
      # =================================================================

      # Print validation summary
      def print_summary
        return unless @validation_results

        summary = validation_summary

        puts "=" * 70
        puts "BOARD VALIDATION SUMMARY"
        puts "=" * 70
        puts ""
        puts "Total Boards: #{summary[:total]}"
        puts "  Valid: #{summary[:valid]} (#{summary[:pass_rate]}%)"
        puts "  Invalid: #{summary[:invalid]}"
        puts ""
        puts "Boards with Warnings: #{@validation_results[:boards_with_warnings]}"
        puts ""

        if error_frequency.any?
          puts "Error Breakdown:"
          error_frequency.each do |error, count|
            puts "  - #{error}: #{count}"
          end
          puts ""
        end

        if warning_frequency.any?
          puts "Warning Breakdown:"
          warning_frequency.each do |warning, count|
            puts "  - #{warning}: #{count}"
          end
        end

        puts "=" * 70
      end

      # Print detailed report for all boards
      def print_detailed_report
        return unless @validation_results

        puts "=" * 70
        puts "DETAILED BOARD VALIDATION REPORT"
        puts "=" * 70
        puts ""

        @validation_results[:results].each_with_index do |result, index|
          puts "Board #{index + 1}: #{result[:board_name]}"
          puts "  Status: #{result[:valid] ? '✓ VALID' : '✗ INVALID'}"
          puts "  Material: #{result[:info][:material]}"
          puts "  Thickness: #{result[:info][:thickness]} mm"
          puts "  Classification: #{result[:info][:classification]}"

          if result[:errors].any?
            puts "  Errors:"
            result[:errors].each { |err| puts "    - #{err}" }
          end

          if result[:warnings].any?
            puts "  Warnings:"
            result[:warnings].each { |warn| puts "    - #{warn}" }
          end

          puts ""
        end

        puts "=" * 70
      end

      # Print validation report for invalid boards only
      def print_invalid_boards_report
        return unless @validation_results

        invalid = invalid_boards
        return if invalid.empty?

        puts "=" * 70
        puts "INVALID BOARDS REPORT"
        puts "=" * 70
        puts ""
        puts "Found #{invalid.count} invalid boards:"
        puts ""

        invalid.each_with_index do |result, index|
          puts "#{index + 1}. #{result[:board_name]}"
          puts "   ID: #{result[:board_id]}"
          puts "   Errors:"
          result[:errors].each { |err| puts "     - #{err}" }
          puts ""
        end

        puts "=" * 70
      end

      # =================================================================
      # Class Methods (convenience)
      # =================================================================

      class << self
        # Quick validate single board
        def validate(board)
          board.valid?
        end

        # Quick validate with details
        def detailed_validation(board)
          validator = new
          validator.validate_board(board)
        end

        # Validate batch of boards
        def validate_batch(boards)
          validator = new
          validator.validate_boards(boards)
          validator.validation_results
        end

        # Validate and print summary
        def validate_and_print(boards)
          validator = new
          validator.validate_boards(boards)
          validator.print_summary
          validator.validation_results
        end

        # Validate and print detailed report
        def validate_and_report(boards)
          validator = new
          validator.validate_boards(boards)
          validator.print_detailed_report
          validator.validation_results
        end

        # Quick validation summary
        def quick_summary(boards)
          {
            total: boards.count,
            valid: boards.count(&:valid?),
            invalid: boards.count { |b| !b.valid? }
          }
        end
      end
    end

  end
end
