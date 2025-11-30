# frozen_string_literal: true

# ===============================================================
# Tests for Board Model
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_board_model(results)
        puts "\nTesting Board Model..."

        begin
          model = Sketchup.active_model

          # Create test board
          board_group = create_test_board(600, 400, 18)
          board = Board.new(board_group)

          # Test basic properties
          assert_not_nil(board.front_face, "Front face should be detected")
          assert_not_nil(board.back_face, "Back face should be detected")
          assert_equal(18.0, board.thickness, "Thickness should be 18mm")

          # Test dimensions
          assert(board.width > 0, "Width should be positive")
          assert(board.height > 0, "Height should be positive")

          # Test validation
          assert_true(board.valid?, "Board should be valid")
          assert_equal(0, board.validation_errors.count, "Should have no validation errors")

          # Test classification
          assert_not_nil(board.classification_key, "Classification key should exist")

          board_group.erase!
          results.record_pass("Board model basic functionality")

        rescue => e
          results.record_fail("Board model basic functionality", e.message)
        end
      end

    end
  end
end
