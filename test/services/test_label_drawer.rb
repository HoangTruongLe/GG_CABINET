# frozen_string_literal: true

# ===============================================================
# Tests for Label Drawing via TextDrawer Service
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_label_drawer(results)
        puts "\nTesting Label Drawing (TextDrawer)..."

        begin
          model = Sketchup.active_model

          # Create test board
          board_group = create_test_board(600, 400, 18)
          board = Board.new(board_group)

          # Test label is created automatically via Board
          test_automatic_label_creation(results, board)

          # Test text drawing components
          test_text_drawing(results, board)

          # Test label components
          test_label_components(results, board)

          # Test label visibility
          test_label_visibility(results, board)

          board_group.erase!
          results.record_pass("Label drawing comprehensive tests")

        rescue => e
          results.record_fail("Label drawing comprehensive tests", e.message)
        end
      end

      def self.test_automatic_label_creation(results, board)
        puts "  Testing automatic label creation..."

        # Create label via Label model
        label = Label.new(board, 1)

        # Label should exist
        assert_not_nil(label, "Label should be created")
        assert_true(label.valid?, "Label should be valid")

        # Label entity should have correct attributes
        entity = label.entity
        assert_equal(true, entity.get_attribute('ABF', 'is-label'), "is-label should be true")
        assert_equal(1, entity.get_attribute('ABF', 'label-index'), "label-index should be 1")

        results.record_pass("Automatic label creation")
      end

      def self.test_text_drawing(results, board)
        puts "  Testing text drawing..."

        # Create a test group for text
        test_group = board.entity.entities.add_group
        test_group.name = "TextTest"

        # Test drawing index number
        index_text = TextDrawer.draw_text(test_group.entities, "7", 6.0, false)
        assert_not_nil(index_text, "Index text should be created")
        assert_true(index_text.valid?, "Index text should be valid")

        # Test drawing separator
        separator_text = TextDrawer.draw_text(test_group.entities, "-", 5.0, false)
        assert_not_nil(separator_text, "Separator text should be created")
        assert_true(separator_text.valid?, "Separator text should be valid")

        # Test drawing instance name
        name_text = TextDrawer.draw_text(test_group.entities, "Board_Name", 5.0, false)
        assert_not_nil(name_text, "Instance name text should be created")
        assert_true(name_text.valid?, "Instance name text should be valid")

        # Test empty text handling
        empty_text = TextDrawer.draw_text(test_group.entities, "", 5.0, false)
        assert_not_nil(empty_text, "Empty text should create empty group")
        assert_equal("EmptyTextGroup", empty_text.name, "Empty text should be named EmptyTextGroup")

        # Clean up
        test_group.erase!

        results.record_pass("Text drawing")
      end

      def self.test_label_components(results, board)
        puts "  Testing label components..."

        label = board.label
        return unless label

        entity = label.entity

        # Label should contain child groups (text components)
        text_groups = entity.entities.grep(Sketchup::Group)
        assert_true(text_groups.length >= 2, "Label should contain at least 2 text groups (index + name)")

        # Label should contain edges (arrow)
        edges = entity.entities.grep(Sketchup::Edge)
        assert_true(edges.length >= 3, "Label should contain at least 3 edges (arrow: line + 2 head lines)")

        # Test arrow components
        # Arrow should have a horizontal main line and two angled head lines
        horizontal_edges = edges.select { |e| (e.line[1].y.abs < 0.01) }
        angled_edges = edges.select { |e| (e.line[1].y.abs > 0.01) }

        # We expect at least 1 horizontal edge (main arrow line)
        # and at least 2 angled edges (arrow head)
        assert_true(horizontal_edges.length >= 1, "Should have at least 1 horizontal edge (arrow line)")
        assert_true(angled_edges.length >= 2, "Should have at least 2 angled edges (arrow head)")

        results.record_pass("Label components")
      end

      def self.test_label_visibility(results, board)
        puts "  Testing label visibility..."

        label = board.label
        return unless label

        # Label should have bounds
        bounds = label.bounds
        assert_not_nil(bounds, "Label should have bounds")

        # Bounds should have non-zero volume
        width = bounds.width
        height = bounds.height
        depth = bounds.depth

        assert_true(width > 0 || height > 0 || depth > 0, "Label bounds should have non-zero dimensions")

        # Label should be positioned on the front face
        face = board.front_face
        return unless face

        label_center = label.center
        face_center = face.center

        # Centers should be relatively close
        distance = label_center.distance(face_center)
        assert_true(distance < 100.0, "Label center should be close to face center (within 100mm)")

        # Label should be visible (not hidden)
        assert_false(label.entity.hidden?, "Label should be visible")

        results.record_pass("Label visibility")
      end

      # Helper assertion methods
      def self.assert_not_nil(value, message = "Value should not be nil")
        raise message if value.nil?
      end

      def self.assert_true(condition, message = "Condition should be true")
        raise message unless condition
      end

      def self.assert_false(condition, message = "Condition should be false")
        raise message if condition
      end

      def self.assert_equal(expected, actual, message = nil)
        message ||= "Expected #{expected}, got #{actual}"
        raise message unless expected == actual
      end

    end
  end
end
