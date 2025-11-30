# frozen_string_literal: true

# ===============================================================
# Tests for GeometryFlattener Service
# ===============================================================

require_relative '../test_helper'

module GG_Cabinet
  module ExtraNesting
    module TestHelper

      def self.test_geometry_flattener(results)
        puts "\nTesting GeometryFlattener..."

        model = nil
        begin
          model = Sketchup.active_model
          model.start_operation('Test GeometryFlattener', true)

          # Test 1: Flatten selected group with geometry above Z=0
          test_flatten_group_with_high_geometry(model, results)

          # Test 2: Flatten selected component
          test_flatten_component(model, results)

          # Test 3: Flatten selected - empty selection
          test_flatten_selected_empty(model, results)

          # Test 4: Flatten selected - skips non-group/component
          test_flatten_selected_skips_invalid(model, results)

          # Test 5: Flatten nested groups
          test_flatten_nested_groups(model, results)

          model.commit_operation
          results.record_pass("GeometryFlattener all tests")

        rescue => e
          model.abort_operation if model && model.active_operation
          results.record_fail("GeometryFlattener all tests", e.message)
          puts "  Error: #{e.message}"
          puts "  Backtrace: #{e.backtrace.first(5).join("\n  ")}"
        end
      end

      private

      def self.test_flatten_group_with_high_geometry(model, results)
        begin
          entities = model.active_entities
          test_group = entities.add_group
          test_entities = test_group.entities

          # Create geometry above Z=0
          # Face at Z=10
          face_points = [
            Geom::Point3d.new(0, 0, 10),
            Geom::Point3d.new(100, 0, 10),
            Geom::Point3d.new(100, 100, 10),
            Geom::Point3d.new(0, 100, 10)
          ]
          face = test_entities.add_face(face_points)

          # Edge at Z=5
          edge = test_entities.add_line(
            Geom::Point3d.new(0, 0, 5),
            Geom::Point3d.new(50, 0, 5)
          )

          # Geometry at Z=0 (should remain)
          face_at_z0 = test_entities.add_face([
            Geom::Point3d.new(0, 0, 0),
            Geom::Point3d.new(50, 0, 0),
            Geom::Point3d.new(50, 50, 0),
            Geom::Point3d.new(0, 50, 0)
          ])

          # Count vertices above Z=0 before flattening
          vertices_before = test_entities.find_all { |e| e.respond_to?(:vertices) }
            .flat_map(&:vertices)
            .uniq
          high_vertices_before = vertices_before.count { |v| v.position.z > 0.0001 }
          
          assert_true(high_vertices_before > 0, "Should have vertices above Z=0")

          # Select and flatten
          model.selection.clear
          model.selection.add(test_group)
          result = GeometryFlattener.flatten_selected

          assert_true(result[:success], "Should successfully flatten group")
          assert_equal(1, result[:entities_count], "Should process 1 entity")

          # Verify geometry above Z=0 is removed
          vertices_after = test_entities.find_all { |e| e.respond_to?(:vertices) }
            .flat_map(&:vertices)
            .uniq
          high_vertices_after = vertices_after.count { |v| v.position.z > 0.0001 }

          assert_equal(0, high_vertices_after, "Should have no vertices above Z=0 after flattening")

          results.record_pass("Flatten group with geometry above Z=0")
        rescue => e
          results.record_fail("Flatten group with geometry above Z=0", e.message)
        end
      end

      def self.test_flatten_component(model, results)
        begin
          entities = model.active_entities

          # Create a component definition
          comp_def = model.definitions.add("TestComponent")
          comp_entities = comp_def.entities

          # Add geometry above Z=0
          comp_entities.add_face([
            Geom::Point3d.new(0, 0, 15),
            Geom::Point3d.new(100, 0, 15),
            Geom::Point3d.new(100, 100, 15),
            Geom::Point3d.new(0, 100, 15)
          ])

          # Add instance
          comp_instance = entities.add_instance(comp_def, Geom::Transformation.new)

          # Count high vertices before
          vertices_before = comp_entities.find_all { |e| e.respond_to?(:vertices) }
            .flat_map(&:vertices)
            .uniq
          high_vertices_before = vertices_before.count { |v| v.position.z > 0.0001 }

          # Select and flatten
          model.selection.clear
          model.selection.add(comp_instance)
          result = GeometryFlattener.flatten_selected

          assert_true(result[:success], "Should successfully flatten component")
          assert_equal(1, result[:entities_count], "Should process 1 entity")

          # Verify geometry above Z=0 is removed
          vertices_after = comp_def.entities.find_all { |e| e.respond_to?(:vertices) }
            .flat_map(&:vertices)
            .uniq
          high_vertices_after = vertices_after.count { |v| v.position.z > 0.0001 }

          assert_equal(0, high_vertices_after, "Should have no vertices above Z=0 after flattening")

          results.record_pass("Flatten component")
        rescue => e
          results.record_fail("Flatten component", e.message)
        end
      end

      def self.test_flatten_selected_empty(model, results)
        begin
          # Clear selection
          model.selection.clear

          # Try to flatten with empty selection
          result = GeometryFlattener.flatten_selected

          assert_false(result[:success], "Should fail with empty selection")
          assert_equal(0, result[:entities_count], "Should process 0 entities")
          assert_true(result[:message].include?("No entities selected"), "Should indicate no selection")

          results.record_pass("Flatten selected (empty selection)")
        rescue => e
          results.record_fail("Flatten selected (empty selection)", e.message)
        end
      end

      def self.test_flatten_selected_skips_invalid(model, results)
        begin
          entities = model.active_entities

          # Create a face directly (not in a group)
          face = entities.add_face([
            Geom::Point3d.new(0, 0, 10),
            Geom::Point3d.new(100, 0, 10),
            Geom::Point3d.new(100, 100, 10),
            Geom::Point3d.new(0, 100, 10)
          ])

          # Create a valid group
          group = entities.add_group
          group.entities.add_face([
            Geom::Point3d.new(0, 0, 5),
            Geom::Point3d.new(50, 0, 5),
            Geom::Point3d.new(50, 50, 5),
            Geom::Point3d.new(0, 50, 5)
          ])

          # Select both (face should be skipped)
          model.selection.clear
          model.selection.add(face)
          model.selection.add(group)

          result = GeometryFlattener.flatten_selected

          # Should succeed but only process the group
          assert_true(result[:success], "Should succeed")
          assert_equal(1, result[:entities_count], "Should process only the group, skip the face")

          results.record_pass("Flatten selected skips invalid entities")
        rescue => e
          results.record_fail("Flatten selected skips invalid entities", e.message)
        end
      end

      def self.test_flatten_nested_groups(model, results)
        begin
          entities = model.active_entities
          outer_group = entities.add_group

          # Create nested groups with geometry at Z=20
          middle_group = outer_group.entities.add_group
          inner_group = middle_group.entities.add_group

          inner_group.entities.add_face([
            Geom::Point3d.new(0, 0, 20),
            Geom::Point3d.new(30, 0, 20),
            Geom::Point3d.new(30, 30, 20),
            Geom::Point3d.new(0, 30, 20)
          ])

          # Count high vertices before
          all_entities = [outer_group, middle_group, inner_group]
          vertices_before = all_entities.flat_map do |g|
            g.entities.find_all { |e| e.respond_to?(:vertices) }
              .flat_map(&:vertices)
          end.uniq
          high_vertices_before = vertices_before.count { |v| v.position.z > 0.0001 }

          assert_true(high_vertices_before > 0, "Should have vertices above Z=0")

          # Select and flatten
          model.selection.clear
          model.selection.add(outer_group)
          result = GeometryFlattener.flatten_selected

          assert_true(result[:success], "Should successfully flatten nested groups")

          # Verify geometry above Z=0 is removed
          vertices_after = all_entities.flat_map do |g|
            g.entities.find_all { |e| e.respond_to?(:vertices) }
              .flat_map(&:vertices)
          end.uniq
          high_vertices_after = vertices_after.count { |v| v.position.z > 0.0001 }

          assert_equal(0, high_vertices_after, "Should have no vertices above Z=0 after flattening")

          results.record_pass("Flatten nested groups")
        rescue => e
          results.record_fail("Flatten nested groups", e.message)
        end
      end

    end
  end
end
