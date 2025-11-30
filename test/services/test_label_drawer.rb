# frozen_string_literal: true

# ===============================================================
# Tests for LabelDrawer Service
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_label_drawer(results)
        puts "\nTesting LabelDrawer..."

        begin
          model = Sketchup.active_model

          # Create test board
          board_group = create_test_board(600, 400, 18)
          board = Board.new(board_group)

          # Draw label
          label = LabelDrawer.draw_label(board, 1, 0)

          assert_not_nil(label, "Label should be created")
          assert_equal(true, label.get_attribute('ABF', 'is-label'))
          assert_equal(1, label.get_attribute('ABF', 'label-index'))

          # Test has_label
          assert_true(LabelDrawer.has_label?(board), "Board should have label")

          board_group.erase!
          results.record_pass("LabelDrawer basic functionality")

        rescue => e
          results.record_fail("LabelDrawer basic functionality", e.message)
        end
      end

    end
  end
end
