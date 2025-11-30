# frozen_string_literal: true

# ===============================================================
# GG_Cabinet Extra Nesting Plugin - Main Entry Point
# ===============================================================

require 'sketchup.rb'
require 'extensions.rb'

module GG_Cabinet
  module ExtraNesting

    # Version and mode configuration
    VERSION = '0.1.0-dev'
    DEV_MODE = true

    # Development settings
    DEV_SETTINGS = {
      use_playground: true,
      playground_offset_x: 20000.mm,
      clone_n1_root: true,
      debug_logging: true
    }

    # Paths
    PLUGIN_ROOT = File.dirname(__FILE__)

    # Load core components
    def self.load_components
      require File.join(PLUGIN_ROOT, 'models', 'persistent_entity')
      require File.join(PLUGIN_ROOT, 'models', 'board')
      require File.join(PLUGIN_ROOT, 'models', 'face')
      require File.join(PLUGIN_ROOT, 'models', 'two_d_group')
      require File.join(PLUGIN_ROOT, 'models', 'sheet')
      require File.join(PLUGIN_ROOT, 'models', 'nesting_root')
      require File.join(PLUGIN_ROOT, 'models', 'label')
      require File.join(PLUGIN_ROOT, 'models', 'edge_banding')
      require File.join(PLUGIN_ROOT, 'models', 'intersection')

      require File.join(PLUGIN_ROOT, 'services', 'playground_creator')
      require File.join(PLUGIN_ROOT, 'services', 'board_scanner')
      require File.join(PLUGIN_ROOT, 'services', 'board_validator')
      require File.join(PLUGIN_ROOT, 'services', 'settings_manager')
      require File.join(PLUGIN_ROOT, 'services', 'edge_banding_drawer')
      require File.join(PLUGIN_ROOT, 'services', 'two_d_projector')
      require File.join(PLUGIN_ROOT, 'services', 'gap_calculator')
      require File.join(PLUGIN_ROOT, 'services', 'nesting_engine')
      require File.join(PLUGIN_ROOT, 'services', 'geometry_flattener')
      require File.join(PLUGIN_ROOT, 'services', 'text_drawer')

      require File.join(PLUGIN_ROOT, 'tools', 'label_tool')
      require File.join(PLUGIN_ROOT, 'tools', 'nesting_tool')

      require File.join(PLUGIN_ROOT, 'helpers', 'geometry_helpers')

      require File.join(PLUGIN_ROOT, 'database')
      require File.join(PLUGIN_ROOT, 'dev_tools') if DEV_MODE
      require File.join(PLUGIN_ROOT, 'test_runner') if DEV_MODE
    end

    # Initialize plugin
    def self.initialize_plugin
      puts "=" * 60
      puts "GG_Cabinet Extra Nesting v#{VERSION}"
      puts "Development Mode: #{DEV_MODE}"
      puts "=" * 60

      load_components
      setup_menu

      puts "✓ Extra Nesting Plugin initialized successfully"
    end

    # Setup menu
    def self.setup_menu
      menu = UI.menu('Plugins')
      submenu = menu.add_submenu('GG Extra Nesting')

      if DEV_MODE
        submenu.add_item('🎮 Dev: Create Playground') {
          DevTools.create_or_reset_playground
        }
        submenu.add_item('🎮 Dev: Focus N1') {
          DevTools.focus_n1
        }
        submenu.add_item('🎮 Dev: Focus N2') {
          DevTools.focus_n2
        }
        submenu.add_separator
        
        # Service test buttons
        test_submenu = submenu.add_submenu('🧪 Run Service Tests')
        
        # Add button for each service test
        TestRunner::SERVICE_TESTS.each do |test_file_name, _test_methods|
          friendly_name = TestRunner.test_friendly_name(test_file_name)
          test_submenu.add_item("Test: #{friendly_name}") {
            TestRunner.run_service_test(test_file_name)
          }
        end
        
        test_submenu.add_separator
        test_submenu.add_item('▶️ Run All Service Tests') {
          TestRunner.run_all_service_tests
        }
        test_submenu.add_item('▶️ Run Full Test Suite') {
          TestRunner.run_full_test_suite
        }
        
        # Phase test buttons
        phase_submenu = submenu.add_submenu('📋 Run Phase Tests')
        
        # Add button for each phase test
        TestRunner::PHASE_TESTS.each do |phase_test_name, display_name|
          phase_submenu.add_item(display_name) {
            TestRunner.run_phase_test(phase_test_name)
          }
        end
        
        phase_submenu.add_separator
        phase_submenu.add_item('▶️ Run All Phase Tests') {
          TestRunner.run_all_phase_tests
        }
        
        submenu.add_separator
      end

      submenu.add_separator
      
      submenu.add_item('Flatten Selected to Plane') {
        result = GeometryFlattener.flatten_selected
        if result[:success]
          UI.messagebox(result[:message], MB_OK)
        else
          UI.messagebox(result[:message], MB_OK)
        end
      }

      submenu.add_item('Label Extra Boards') {
        LabelTool.label_selected_boards
      }

      submenu.add_item('Nest Extra Boards') {
        NestingTool.nest_selected_boards
      }
    end

  end
end

# Auto-initialize
GG_Cabinet::ExtraNesting.initialize_plugin
