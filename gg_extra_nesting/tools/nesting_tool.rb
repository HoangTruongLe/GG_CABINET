# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # NestingTool - Nests selected labeled boards into cloned nesting root
    class NestingTool

      class << self

        def nest_selected_boards
          model = Sketchup.active_model
          selection = model.selection

          if selection.empty?
            UI.messagebox("Please select at least one labeled board to nest")
            return
          end

          puts "\n" + ("=" * 70)
          puts "NESTING TOOL - Nesting Extra Boards"
          puts ("=" * 70)

          # Step 1: Filter selection to labeled boards
          labeled_boards = find_labeled_boards_in_selection(selection)

          if labeled_boards.empty?
            UI.messagebox("No labeled boards found in selection.\n\nPlease:\n1. Select boards\n2. Click 'Label Extra Boards' first\n3. Then click 'Nest Extra Boards'")
            return
          end

          puts "\nFound #{labeled_boards.count} labeled board(s) in selection"

          # Step 2: Create new nesting root for extra boards
          nesting_root = create_extra_nesting_root(model)

          unless nesting_root
            UI.messagebox("Error: Could not create nesting root for extra boards.")
            return
          end

          puts "Created new nesting root: #{nesting_root.entity.name}"

          # Step 3: Create Board objects
          boards = labeled_boards.map { |entity| Board.new(entity) }
          valid_boards = boards.select(&:valid?)

          puts "\nValid boards: #{valid_boards.count}/#{boards.count}"

          if valid_boards.empty?
            UI.messagebox("No valid boards to nest")
            return
          end

          # Step 4: Project boards to 2D
          puts "\nProjecting boards to 2D..."
          projector = TwoDProjector.new
          boards_2d = []

          valid_boards.each_with_index do |board, i|
            puts "  Projecting #{i + 1}/#{valid_boards.count}: #{board.entity.name}"

            begin
              # Create temporary container for projection
              temp_container = model.entities.add_group
              temp_container.name = "Temp_2D_Container"

              two_d_group = projector.project_board(board, temp_container)

              if two_d_group && two_d_group.valid?
                # Set material and thickness for matching
                two_d_group.instance_variable_set(:@material_name, board.material_name)
                two_d_group.instance_variable_set(:@thickness, board.thickness)

                # Add accessors if needed
                class << two_d_group
                  attr_accessor :material_name, :thickness unless method_defined?(:material_name)
                end

                two_d_group.material_name = board.material_name
                two_d_group.thickness = board.thickness

                boards_2d << two_d_group
                puts "    ✓ Projected: #{two_d_group.width.round(0)} × #{two_d_group.height.round(0)} mm"
              else
                puts "    ✗ Failed to project"
              end

            rescue => e
              puts "    ✗ Error: #{e.message}"
            end
          end

          if boards_2d.empty?
            UI.messagebox("No boards could be projected to 2D")
            return
          end

          puts "\nSuccessfully projected #{boards_2d.count} board(s) to 2D"

          # Step 5: Create nesting engine
          puts "\nInitializing nesting engine..."
          engine = NestingEngine.new(nesting_root)
          engine.allow_rotation = true
          engine.create_new_sheets = true
          engine.prefer_existing_sheets = true
          engine.min_spacing = 5.0

          # Step 6: Nest boards with progress
          puts "\nNesting boards..."

          model.start_operation('Nest Extra Boards', true)

          begin
            results = engine.nest_boards(boards_2d) do |current, total, board|
              puts "  Nesting #{current}/#{total}: #{board.width.round(0)} × #{board.height.round(0)} mm"
            end

            model.commit_operation

            # Step 7: Show results
            successful = results.count { |r| r[:success] }
            failed = results.count { |r| !r[:success] }

            puts "\n" + ("-" * 70)
            puts "NESTING RESULTS"
            puts ("-" * 70)
            puts "  Total boards: #{results.count}"
            puts "  Successfully nested: #{successful}"
            puts "  Failed: #{failed}"
            puts "  New sheets created: #{engine.new_sheets_created}"
            puts "  Average utilization: #{engine.average_utilization}%"

            # Show detailed results
            engine.print_placement_results

            # Validation
            validation_errors = engine.validate_nesting
            if validation_errors.any?
              puts "\n⚠ Validation Warnings:"
              validation_errors.each { |err| puts "  - #{err}" }
            else
              puts "\n✓ Nesting is valid (no overlaps)"
            end

            # User message
            message = "Nesting Complete!\n\n"
            message += "Successfully nested: #{successful}/#{results.count} boards\n"
            message += "New sheets created: #{engine.new_sheets_created}\n"
            message += "Average utilization: #{engine.average_utilization}%\n\n"

            if failed > 0
              message += "Failed to nest #{failed} board(s)"
            end

            if validation_errors.any?
              message += "\n\nWarnings: #{validation_errors.count}"
            end

            UI.messagebox(message)

            # Focus on nesting root
            model.active_view.zoom(nesting_root.entity)

          rescue => e
            model.abort_operation
            puts "\nError during nesting: #{e.message}"
            puts e.backtrace.first(10).join("\n")
            UI.messagebox("Error during nesting: #{e.message}")
          end
        end

        private

        def find_labeled_boards_in_selection(selection)
          boards = []

          selection.grep(Sketchup::Group).each do |entity|
            if entity.get_attribute('ABF', 'is-extra-board') == true
              boards << entity
            end
          end

          boards
        end

        def create_extra_nesting_root(model)
          # Create a new empty nesting root for extra boards
          begin
            # Create new group
            root_group = model.entities.add_group
            root_group.name = "ExtraNesting_#{Time.now.strftime('%Y%m%d_%H%M%S')}"

            # Set attributes
            root_group.set_attribute('ABF', 'is-nesting-root', true)
            root_group.set_attribute('ABF', 'is-extra-nesting', true)
            root_group.set_attribute('ABF', 'created-at', Time.now.to_s)

            # Create NestingRoot wrapper
            nesting_root = NestingRoot.new(root_group)

            puts "Created new nesting root for extra boards"

            nesting_root

          rescue => e
            puts "Error creating nesting root: #{e.message}"
            nil
          end
        end

      end

    end

  end
end
