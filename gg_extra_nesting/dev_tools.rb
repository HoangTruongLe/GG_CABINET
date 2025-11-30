# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # Development tools for N2 Playground workflow
    # Only loaded when DEV_MODE = true
    module DevTools

      # Create or reset playground
      def self.create_or_reset_playground
        model = Sketchup.active_model

        info = PlaygroundCreator.playground_info(model)

        if info[:has_n2]
          result = UI.messagebox(
            "N2 Playground already exists.\n\nDo you want to reset it?\n(This will delete and recreate from N1)",
            MB_YESNO
          )

          if result == IDYES
            PlaygroundCreator.reset_playground(model)
            UI.messagebox("N2 Playground reset successfully!")
          end
        else
          n2 = PlaygroundCreator.create_or_find_playground(model)
          if n2
            UI.messagebox("N2 Playground created successfully!\n\nOffset: +20000mm on X-axis")
            focus_n2
          end
        end
      end

      # Focus camera on N1 root
      def self.focus_n1
        model = Sketchup.active_model
        n1 = PlaygroundCreator.find_n1_nesting_root(model)

        unless n1
          UI.messagebox("N1 Nesting Root not found!")
          return
        end

        view = model.active_view
        view.zoom(n1)

        puts "✓ Camera focused on N1 (Original Nesting Root)"
      end

      # Focus camera on N2 playground
      def self.focus_n2
        model = Sketchup.active_model
        n2 = PlaygroundCreator.find_n2_playground(model)

        unless n2
          UI.messagebox("N2 Playground not found!\n\nCreate it first using 'Create Playground'")
          return
        end

        view = model.active_view
        view.zoom(n2)

        puts "✓ Camera focused on N2 (Playground)"
      end

      # Compare N1 vs N2
      def self.compare_roots
        model = Sketchup.active_model
        info = PlaygroundCreator.playground_info(model)

        message = "=== N1 vs N2 Comparison ===\n\n"

        if info[:has_n1]
          message += "N1 (Original):\n"
          message += "  Name: #{info[:n1_name]}\n"
          message += "  ID: #{info[:n1_id]}\n"
          message += "  Bounds: #{format_bounds(info[:n1_bounds])}\n\n"
        else
          message += "N1: NOT FOUND\n\n"
        end

        if info[:has_n2]
          message += "N2 (Playground):\n"
          message += "  Name: #{info[:n2_name]}\n"
          message += "  ID: #{info[:n2_id]}\n"
          message += "  Bounds: #{format_bounds(info[:n2_bounds])}\n"
        else
          message += "N2: NOT FOUND\n"
        end

        puts message
        UI.messagebox(message)
      end

      # Print board info (debug helper)
      def self.print_board_info(board)
        return unless board

        puts "=" * 50
        puts "Board Debug Info"
        puts "=" * 50

        if board.is_a?(Sketchup::Group)
          puts "Entity ID: #{board.entityID}"
          puts "Name: #{board.name}"
          puts "Bounds: #{format_bounds(board.bounds)}"

          dict = board.attribute_dictionary('ABF')
          if dict
            puts "\nAttributes:"
            dict.each { |k, v| puts "  #{k}: #{v}" }
          else
            puts "\nNo ABF attributes"
          end
        elsif board.respond_to?(:to_hash)
          puts board.to_hash.inspect
        else
          puts "Unknown board type: #{board.class}"
        end

        puts "=" * 50
      end

      # Highlight gaps in sheet (visual helper)
      def self.highlight_gaps(sheet)
        puts "Gap highlighting - Coming in Phase 4"
      end

      # Print database stats
      def self.print_db_stats
        stats = Database.instance.stats
        puts "=" * 50
        puts "Database Statistics"
        puts "=" * 50
        puts "Tables: #{stats[:tables].join(', ')}"
        puts "Total Records: #{stats[:total_records]}"
        puts "=" * 50
      end

      # Clear database
      def self.clear_database
        result = UI.messagebox(
          "Clear all database records?",
          MB_YESNO
        )

        if result == IDYES
          Database.instance.clear_all
          puts "✓ Database cleared"
        end
      end

      private

      # Format bounds for display
      def self.format_bounds(bounds)
        return "nil" unless bounds

        w = (bounds.width / 1.mm).round(1)
        h = (bounds.height / 1.mm).round(1)
        d = (bounds.depth / 1.mm).round(1)

        "#{w} × #{h} × #{d} mm"
      end

    end

  end
end
