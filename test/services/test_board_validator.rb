# frozen_string_literal: true

# ===============================================================
# Tests for BoardValidator Service
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_board_validator(results)
        puts "\nTesting BoardValidator..."

        begin
          model = Sketchup.active_model

          # Create test board
          board_group = create_test_board(600, 400, 18)
          board = Board.new(board_group)

          validator = BoardValidator.new

          # Validate board
          result = validator.validate_board(board)

          assert_not_nil(result, "Validation result should not be nil")
          assert(result.has_key?(:valid), "Result should have :valid key")
          assert(result.has_key?(:errors), "Result should have :errors key")
          assert(result.has_key?(:warnings), "Result should have :warnings key")

          board_group.erase!
          results.record_pass("BoardValidator basic functionality")

        rescue => e
          results.record_fail("BoardValidator basic functionality", e.message)
        end
      end

      def self.test_board_validator_batch(results)
        puts "\nTesting BoardValidator Batch Validation..."

        begin
          model = Sketchup.active_model

          validator = BoardValidator.new

          # Create multiple test boards
          board1 = create_test_board(600, 400, 18)
          board2 = create_test_board(500, 300, 18)

          boards = [Board.new(board1), Board.new(board2)]

          # Batch validate
          results_batch = validator.validate_batch(boards)

          assert_not_nil(results_batch, "Batch validation result should not be nil")
          assert(results_batch.has_key?(:total), "Result should have :total key")
          assert(results_batch.has_key?(:valid_count), "Result should have :valid_count key")
          assert(results_batch.has_key?(:invalid_count), "Result should have :invalid_count key")

          board1.erase!
          board2.erase!
          results.record_pass("BoardValidator batch validation")

        rescue => e
          results.record_fail("BoardValidator batch validation", e.message)
        end
      end

    end
  end
end
