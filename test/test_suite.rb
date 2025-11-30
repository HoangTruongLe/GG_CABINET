# frozen_string_literal: true

# ===============================================================
# GG_Cabinet Extra Nesting - Main Test Suite Runner
# ===============================================================
#
# Comprehensive tests for all models and services
#
# Load this file in SketchUp Ruby Console:
# load 'c:/Users/KB5007253/Desktop/tools/GG_ExtraNesting/test/test_suite.rb'
#
# ===============================================================

require_relative 'test_helper'

# Load all model tests
require_relative 'models/test_persistent_entity'
require_relative 'models/test_board'
require_relative 'models/test_face'
require_relative 'models/test_intersection'
require_relative 'models/test_two_d_group'
require_relative 'models/test_sheet'
require_relative 'models/test_edge_banding'
require_relative 'models/test_label'
require_relative 'models/test_nesting_root'

# Load all service tests
require_relative 'services/test_board_scanner'
require_relative 'services/test_two_d_projector'
require_relative 'services/test_gap_calculator'
require_relative 'services/test_nesting_engine'
require_relative 'services/test_label_drawer'
require_relative 'services/test_edge_banding_drawer'
require_relative 'services/test_board_validator'
require_relative 'services/test_text_drawer'
require_relative 'services/test_geometry_flattener'

# Load integration tests
require_relative 'integration/test_labeling_workflow'

module GG_Cabinet
  module ExtraNesting
    module TestSuite

      # ================================================================
      # Main Test Runner
      # ================================================================

      def self.run_all_tests
        puts "\n" + ("=" * 70)
        puts "GG_CABINET EXTRA NESTING - AUTOMATED TEST SUITE"
        puts ("=" * 70)
        puts "Starting tests at #{Time.now}"
        puts ("=" * 70)

        results = TestHelper::TestResults.new

        # Model tests
        puts "\n" + ("-" * 70)
        puts "MODEL TESTS"
        puts ("-" * 70)
        TestHelper.test_persistent_entity(results)
        TestHelper.test_board_model(results)
        TestHelper.test_face_model(results)
        TestHelper.test_intersection_model(results)
        TestHelper.test_intersection_detection(results)
        TestHelper.test_board_intersection_layer(results)
        TestHelper.test_mark_square_detection(results)
        TestHelper.test_two_d_group_model(results)
        TestHelper.test_sheet_model(results)
        TestHelper.test_edge_banding_parse_array(results)
        TestHelper.test_edge_banding_model(results)
        TestHelper.test_edge_banding_edge_cases(results)
        TestHelper.test_edge_banding_multiple(results)
        TestHelper.test_edge_banding_from_board(results)
        TestHelper.test_edge_banding_serialization(results)
        TestHelper.test_label_model(results)
        TestHelper.test_nesting_root_model(results)

        # Service tests
        puts "\n" + ("-" * 70)
        puts "SERVICE TESTS"
        puts ("-" * 70)
        TestHelper.test_board_scanner(results)
        TestHelper.test_board_scanner_filtering(results)
        TestHelper.test_two_d_projector(results)
        TestHelper.test_two_d_projector_backface(results)
        TestHelper.test_gap_calculator(results)
        TestHelper.test_nesting_engine(results)
        TestHelper.test_label_drawer(results)
        TestHelper.test_edge_banding_drawer_geometry(results)
        TestHelper.test_edge_banding_drawer_triangle_scaling(results)
        TestHelper.test_edge_banding_drawer_triangle_vertices(results)
        TestHelper.test_edge_banding_drawer_class_methods(results)
        TestHelper.test_board_validator(results)
        TestHelper.test_board_validator_batch(results)
        TestHelper.test_text_drawer(results)
        TestHelper.test_geometry_flattener(results)

        # Integration tests
        puts "\n" + ("-" * 70)
        puts "INTEGRATION TESTS"
        puts ("-" * 70)
        TestHelper.test_labeling_workflow(results)
        TestHelper.test_front_face_detection(results)

        # Print summary
        results.print_summary

        # Return results
        results
      end

    end
  end
end

# Auto-run tests
puts "\n\nRunning automated test suite..."
results = GG_Cabinet::ExtraNesting::TestSuite.run_all_tests

# Return results for inspection
results
