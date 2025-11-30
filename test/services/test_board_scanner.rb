# frozen_string_literal: true

# ===============================================================
# Tests for BoardScanner Service
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_board_scanner(results)
        puts "\nTesting BoardScanner..."

        begin
          model = Sketchup.active_model

          # Create test boards
          board1 = create_test_board(600, 400, 18)
          board1.set_attribute('ABF', 'is-board', true)

          board2 = create_test_board(500, 300, 18)
          board2.set_attribute('ABF', 'is-board', true)

          scanner = BoardScanner.new

          # Scan all boards
          boards = scanner.scan_all_boards
          assert(boards.count >= 2, "Should find at least 2 boards")

          # Test board properties
          boards.each do |board|
            assert(board.is_a?(Board), "Should return Board objects")
          end

          board1.erase!
          board2.erase!
          results.record_pass("BoardScanner basic functionality")

        rescue => e
          results.record_fail("BoardScanner basic functionality", e.message)
        end
      end

      def self.test_board_scanner_filtering(results)
        puts "\nTesting BoardScanner Filtering..."

        begin
          model = Sketchup.active_model

          scanner = BoardScanner.new

          # Test different filter methods
          all_boards = scanner.scan_all_boards
          labeled_boards = scanner.scan_labeled_boards
          unlabeled_boards = scanner.scan_unlabeled_boards
          extra_boards = scanner.scan_extra_boards

          assert(all_boards.is_a?(Array), "scan_all_boards should return array")
          assert(labeled_boards.is_a?(Array), "scan_labeled_boards should return array")
          assert(unlabeled_boards.is_a?(Array), "scan_unlabeled_boards should return array")
          assert(extra_boards.is_a?(Array), "scan_extra_boards should return array")

          results.record_pass("BoardScanner filtering methods")

        rescue => e
          results.record_fail("BoardScanner filtering methods", e.message)
        end
      end

    end
  end
end
