# frozen_string_literal: true

# ===============================================================
# Tests for Label Model
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_label_model(results)
        puts "\nTesting Label Model..."

        begin
          model = Sketchup.active_model

          # Create test board
          board_group = create_test_board(600, 400, 18)
          board = Board.new(board_group)

          # Test label detection
          assert_not_nil(board.labeled?, "labeled? should return boolean")
          assert_not_nil(board.can_be_labeled?, "can_be_labeled? should return boolean")

          # Test label rotation
          if board.labeled? && board.label
            assert_not_nil(board.label.rotation, "Label should have rotation")
          end

          board_group.erase!
          results.record_pass("Label model basic functionality")

        rescue => e
          results.record_fail("Label model basic functionality", e.message)
        end
      end

    end
  end
end
