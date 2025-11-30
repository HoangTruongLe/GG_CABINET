# frozen_string_literal: true

# ===============================================================
# Test Runner - Utility for running tests in dev mode
# ===============================================================

module GG_Cabinet
  module ExtraNesting

    # Test runner for development mode
    class TestRunner

      # Test file mapping: filename => test method names
      SERVICE_TESTS = {
        'test_board_scanner' => ['test_board_scanner', 'test_board_scanner_filtering'],
        'test_board_validator' => ['test_board_validator', 'test_board_validator_batch'],
        'test_edge_banding_drawer' => [
          'test_edge_banding_drawer_geometry',
          'test_edge_banding_drawer_triangle_scaling',
          'test_edge_banding_drawer_triangle_vertices',
          'test_edge_banding_drawer_class_methods'
        ],
        'test_gap_calculator' => ['test_gap_calculator'],
        'test_label_drawer' => ['test_label_drawer'],
        'test_nesting_engine' => ['test_nesting_engine'],
        'test_two_d_projector' => ['test_two_d_projector', 'test_two_d_projector_backface'],
        'test_text_drawer' => ['test_text_drawer'],
        'test_geometry_flattener' => ['test_geometry_flattener']
      }.freeze

      # Get the test directory path
      def self.test_dir
        plugin_root = File.dirname(File.dirname(__FILE__))
        File.join(plugin_root, 'test')
      end

      # Get the test helper path
      def self.test_helper_path
        File.join(test_dir, 'test_helper.rb')
      end

      # Get the full test suite path
      def self.test_suite_path
        File.join(test_dir, 'test_suite.rb')
      end

      # Load test helper (required for all tests)
      def self.load_test_helper
        require test_helper_path
      end

      # Run a single service test file
      # @param test_file_name [String] Name of the test file without .rb extension (e.g., 'test_board_scanner')
      def self.run_service_test(test_file_name)
        unless DEV_MODE
          UI.messagebox("Test runner is only available in dev mode.")
          return
        end

        # Load test helper first
        load_test_helper

        # Get test file path
        test_file_path = File.join(test_dir, 'services', "#{test_file_name}.rb")

        unless File.exist?(test_file_path)
          UI.messagebox("Test file not found: #{test_file_path}")
          return
        end

        # Get test method names for this file
        test_methods = SERVICE_TESTS[test_file_name] || []
        
        if test_methods.empty?
          UI.messagebox("No test methods found for: #{test_file_name}")
          return
        end

        puts "\n" + ("=" * 70)
        puts "Running Service Test: #{test_file_name}"
        puts ("=" * 70)

        begin
          # Load the test file
          load test_file_path

          # Create results object
          results = GG_Cabinet::ExtraNesting::TestHelper::TestResults.new

          # Run each test method
          test_methods.each do |method_name|
            test_helper = GG_Cabinet::ExtraNesting::TestHelper
            if test_helper.respond_to?(method_name)
              test_helper.send(method_name, results)
            else
              puts "Warning: Test method #{method_name} not found in TestHelper"
            end
          end

          # Print summary
          results.print_summary

          # Show result dialog
          message = "Test: #{test_file_name}\n\n"
          message += "Total tests: #{results.tests_run}\n"
          message += "Passed: #{results.tests_passed}\n"
          message += "Failed: #{results.tests_failed}"

          if results.tests_failed > 0
            message += "\n\nCheck Ruby Console for details."
            UI.messagebox(message, MB_OK)
          else
            UI.messagebox(message)
          end

          results

        rescue => e
          error_message = "Error running test #{test_file_name}:\n#{e.message}"
          puts error_message
          puts e.backtrace.join("\n")
          UI.messagebox(error_message, MB_OK)
          nil
        end
      end

      # Run all service tests
      def self.run_all_service_tests
        unless DEV_MODE
          UI.messagebox("Test runner is only available in dev mode.")
          return
        end

        puts "\n" + ("=" * 70)
        puts "Running ALL Service Tests"
        puts ("=" * 70)

        begin
          # Load test helper
          load_test_helper

          # Create combined results
          all_results = GG_Cabinet::ExtraNesting::TestHelper::TestResults.new
          test_helper = GG_Cabinet::ExtraNesting::TestHelper

          # Run each service test
          SERVICE_TESTS.each do |test_file_name, test_methods|
            test_file_path = File.join(test_dir, 'services', "#{test_file_name}.rb")

            next unless File.exist?(test_file_path)

            puts "\n" + ("-" * 70)
            puts "Loading: #{test_file_name}"
            puts ("-" * 70)

            begin
              # Load test file
              load test_file_path

              # Run each test method
              test_methods.each do |method_name|
                if test_helper.respond_to?(method_name)
                  test_helper.send(method_name, all_results)
                end
              end
            rescue => e
              error_msg = "Error in #{test_file_name}: #{e.message}"
              puts error_msg
              all_results.record_fail(test_file_name, error_msg)
            end
          end

          # Print summary
          puts "\n" + ("=" * 70)
          puts "ALL SERVICE TESTS SUMMARY"
          puts ("=" * 70)
          all_results.print_summary

          # Show result dialog
          message = "All Service Tests Complete\n\n"
          message += "Total tests: #{all_results.tests_run}\n"
          message += "Passed: #{all_results.tests_passed}\n"
          message += "Failed: #{all_results.tests_failed}"

          if all_results.tests_failed > 0
            message += "\n\nCheck Ruby Console for details."
            UI.messagebox(message, MB_OK)
          else
            UI.messagebox(message)
          end

          all_results

        rescue => e
          error_message = "Error running all tests:\n#{e.message}"
          puts error_message
          puts e.backtrace.join("\n")
          UI.messagebox(error_message, MB_OK)
          nil
        end
      end

      # Run full test suite (all tests including models and integration)
      def self.run_full_test_suite
        unless DEV_MODE
          UI.messagebox("Test runner is only available in dev mode.")
          return
        end

        puts "\n" + ("=" * 70)
        puts "Running FULL Test Suite (All Tests)"
        puts ("=" * 70)

        begin
          # Load and run the full test suite
          load test_suite_path

          # The test_suite.rb auto-runs when loaded, but we can also explicitly call it
          # Check for the TestSuite in the correct namespace
          if defined?(GG_Cabinet::ExtraNesting::TestSuite) && 
             GG_Cabinet::ExtraNesting::TestSuite.respond_to?(:run_all_tests)
            results = GG_Cabinet::ExtraNesting::TestSuite.run_all_tests
          elsif defined?(TestSuite) && TestSuite.respond_to?(:run_all_tests)
            results = TestSuite.run_all_tests
          else
            # The test_suite.rb auto-runs when loaded, so results should already be available
            # Just return a message
            UI.messagebox("Full test suite loaded and executed. Check Ruby Console for results.")
            return nil
          end

          results

        rescue => e
          error_message = "Error running full test suite:\n#{e.message}"
          puts error_message
          puts e.backtrace.join("\n")
          UI.messagebox(error_message, MB_OK)
          nil
        end
      end

      # Get friendly name for test file
      def self.test_friendly_name(test_file_name)
        # Convert 'test_board_scanner' to 'Board Scanner'
        test_file_name
          .sub(/^test_/, '')
          .split('_')
          .map(&:capitalize)
          .join(' ')
      end

      # Phase test file mapping: filename => display name
      PHASE_TESTS = {
        'test_phase1' => 'Phase 1: N2 Playground Foundation',
        'test_phase2' => 'Phase 2: Board Detection & Classification',
        'test_phase3' => 'Phase 3: 2D Projection',
        'test_phase4' => 'Phase 4: Nesting Engine'
      }.freeze

      # Get the phase test directory path
      def self.phase_test_dir
        File.join(test_dir, 'phase')
      end

      # Run a phase test script (standalone script)
      # @param phase_test_name [String] Name of the phase test file without .rb extension (e.g., 'test_phase1')
      def self.run_phase_test(phase_test_name)
        unless DEV_MODE
          UI.messagebox("Phase test runner is only available in dev mode.")
          return
        end

        # Get test file path
        phase_test_path = File.join(phase_test_dir, "#{phase_test_name}.rb")

        unless File.exist?(phase_test_path)
          UI.messagebox("Phase test file not found: #{phase_test_path}")
          return
        end

        display_name = PHASE_TESTS[phase_test_name] || phase_test_name

        puts "\n" + ("=" * 70)
        puts "Running Phase Test: #{display_name}"
        puts ("=" * 70)

        begin
          # Phase tests are standalone scripts that run when loaded
          # They print their own output to the console
          load phase_test_path

          UI.messagebox(
            "Phase test completed: #{display_name}\n\nCheck Ruby Console for detailed results.",
            MB_OK
          )

          true

        rescue => e
          error_message = "Error running phase test #{phase_test_name}:\n#{e.message}"
          puts error_message
          puts e.backtrace.join("\n")
          UI.messagebox(error_message, MB_OK)
          false
        end
      end

      # Run all phase tests
      def self.run_all_phase_tests
        unless DEV_MODE
          UI.messagebox("Phase test runner is only available in dev mode.")
          return
        end

        puts "\n" + ("=" * 70)
        puts "Running ALL Phase Tests"
        puts ("=" * 70)

        results = {
          passed: 0,
          failed: 0,
          total: PHASE_TESTS.length
        }

        PHASE_TESTS.each do |phase_test_name, display_name|
          puts "\n" + ("-" * 70)
          puts "Running: #{display_name}"
          puts ("-" * 70)

          if run_phase_test(phase_test_name)
            results[:passed] += 1
          else
            results[:failed] += 1
          end
        end

        # Show summary
        message = "All Phase Tests Complete\n\n"
        message += "Total: #{results[:total]}\n"
        message += "Passed: #{results[:passed]}\n"
        message += "Failed: #{results[:failed]}"
        message += "\n\nCheck Ruby Console for detailed results."

        UI.messagebox(message, MB_OK)

        results
      end

    end

  end
end

