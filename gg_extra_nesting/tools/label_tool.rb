# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # LabelTool - Labels selected boards as extra boards for nesting
    class LabelTool

      class << self

        def label_selected_boards
          model = Sketchup.active_model
          selection = model.selection

          if selection.empty?
            UI.messagebox("Please select at least one board to label")
            return
          end

          # Filter selection to only groups
          board_entities = selection.grep(Sketchup::Group)

          if board_entities.empty?
            UI.messagebox("No groups selected. Please select board groups.")
            return
          end

          puts "\n" + ("=" * 70)
          puts "LABEL TOOL - Labeling Extra Boards"
          puts ("=" * 70)

          labeled_count = 0
          relabeled_count = 0
          skipped_count = 0
          errors = []

          # Find next available index
          next_index = find_next_board_index(model)
          current_index = next_index

          model.start_operation('Label Extra Boards', true)

          begin
            board_entities.each_with_index do |entity, i|
              puts "\nProcessing #{i + 1}/#{board_entities.count}: #{entity.name}"

              # Create Board object to validate
              board = Board.new(entity)

              unless board.valid?
                puts "  ✗ Invalid board:"
                board.validation_errors.each { |err| puts "    - #{err}" }
                errors << "#{entity.name}: #{board.validation_errors.join(', ')}"
                skipped_count += 1
                next
              end

              # Label the board with all required attributes
              label_board(entity, board, current_index)

              # Mark front face
              mark_front_face(board)

              # Draw visual label on front face
              draw_visual_label(board, current_index)

              if was_labeled
                puts "  ↻ Re-labeled (index updated)"
                relabeled_count += 1
              else
                puts "  ✓ Labeled successfully"
                labeled_count += 1
              end

              puts "    Index: #{current_index}"
              puts "    Material: #{board.material_name || 'None'}"
              puts "    Thickness: #{board.thickness} mm"
              puts "    Size: #{board.width.round(0)} × #{board.height.round(0)} mm"
              puts "    Classification: #{board.classification_key}"
              puts "    Front face intersections: #{board.front_intersections.count}"

              current_index += 1
            end

            model.commit_operation

            # Show summary
            puts "\n" + ("-" * 70)
            puts "LABELING SUMMARY"
            puts ("-" * 70)
            puts "  Total selected: #{board_entities.count}"
            puts "  Newly labeled: #{labeled_count}"
            puts "  Re-labeled: #{relabeled_count}"
            puts "  Skipped: #{skipped_count}"
            puts "  Errors: #{errors.count}"
            puts "  Next index: #{current_index}"

            if errors.any?
              puts "\nErrors:"
              errors.each { |err| puts "  - #{err}" }
            end

            # Show user message
            total_labeled = labeled_count + relabeled_count
            if total_labeled > 0
              message = "Successfully labeled #{total_labeled} board(s) as extra boards.\n\n"
              message += "Newly labeled: #{labeled_count}\n"
              message += "Re-labeled: #{relabeled_count}\n"
              message += "Skipped: #{skipped_count}\n"
              message += "Errors: #{errors.count}\n\n"
              message += "Board indices: #{next_index} - #{current_index - 1}"
              UI.messagebox(message)
            elsif errors.any?
              UI.messagebox("No boards were labeled.\n\nErrors:\n#{errors.join("\n")}")
            else
              UI.messagebox("No new boards to label (#{skipped_count} skipped)")
            end

          rescue => e
            model.abort_operation
            puts "\nError: #{e.message}"
            puts e.backtrace.first(5).join("\n")
            UI.messagebox("Error labeling boards: #{e.message}")
          end
        end

        private

        def find_next_board_index(model)
          # Find the highest existing board-index
          max_index = 0

          model.entities.grep(Sketchup::Group).each do |entity|
            index = entity.get_attribute('ABF', 'board-index')
            max_index = index if index && index.to_i > max_index
          end

          max_index + 1
        end

        def label_board(entity, board, index)
          # Set all required ABF attributes
          entity.set_attribute('ABF', 'is-board', true)
          entity.set_attribute('ABF', 'is-extra-board', true)
          entity.set_attribute('ABF', 'board-index', index)
          entity.set_attribute('ABF', 'labeled-at', Time.now.to_s)

          # Material and thickness
          entity.set_attribute('ABF', 'material-name', board.material_name) if board.material_name
          entity.set_attribute('ABF', 'thickness', board.thickness)

          # Classification key
          entity.set_attribute('ABF', 'classification-key', board.classification_key)

          # Edge banding (default: no edge banding)
          # Format: [top, name, thickness, color, bottom]
          # 0 = no edge banding, 1 = has edge banding
          unless entity.get_attribute('ABF', 'edge-band-types')
            entity.set_attribute('ABF', 'edge-band-types', [0, "CHỈ", 1.0, "#b36ea9", 0])
          end

          # Label rotation (default 0, user should set this as needed)
          unless entity.get_attribute('ABF', 'label-rotation')
            entity.set_attribute('ABF', 'label-rotation', 0)
          end
        end

        def mark_front_face(board)
          # Mark the front face entity with is-labeled-face attribute
          return unless board.front_face && board.front_face.entity

          board.front_face.entity.set_attribute('ABF', 'is-labeled-face', true)

          puts "    Front face marked (#{board.front_intersections.count} intersections)"
        end

        def draw_visual_label(board, new_label_index)
          board.remove_label
          board.create_label(new_label_index)
        end

        def unlabel_selected_boards
          model = Sketchup.active_model
          selection = model.selection

          if selection.empty?
            UI.messagebox("Please select at least one labeled board to unlabel")
            return
          end

          board_entities = selection.grep(Sketchup::Group)

          if board_entities.empty?
            UI.messagebox("No groups selected")
            return
          end

          model.start_operation('Unlabel Extra Boards', true)

          unlabeled_count = 0

          begin
            board_entities.each do |entity|
              if entity.get_attribute('ABF', 'is-extra-board') == true
                # Remove extra-board attribute but keep other attributes
                entity.delete_attribute('ABF', 'is-extra-board')
                entity.delete_attribute('ABF', 'labeled-at')

                # Remove visual label
                remove_existing_label(entity)

                # Unmark front face
                entity.entities.grep(Sketchup::Face).each do |face|
                  face.delete_attribute('ABF', 'is-labeled-face')
                end

                unlabeled_count += 1
              end
            end

            model.commit_operation

            UI.messagebox("Unlabeled #{unlabeled_count} board(s)")

          rescue => e
            model.abort_operation
            UI.messagebox("Error unlabeling boards: #{e.message}")
          end
        end

        def count_labeled_boards
          model = Sketchup.active_model
          count = 0

          model.entities.grep(Sketchup::Group).each do |entity|
            count += 1 if entity.get_attribute('ABF', 'is-extra-board') == true
          end

          count
        end

        def reindex_all_labeled_boards
          model = Sketchup.active_model

          # Find all labeled boards
          labeled_boards = model.entities.grep(Sketchup::Group).select do |entity|
            entity.get_attribute('ABF', 'is-extra-board') == true
          end

          return if labeled_boards.empty?

          model.start_operation('Reindex Labeled Boards', true)

          begin
            labeled_boards.each_with_index do |entity, index|
              new_index = index + 1
              old_index = entity.get_attribute('ABF', 'board-index')

              entity.set_attribute('ABF', 'board-index', new_index)

              # Update visual label
              board = Board.new(entity)
              remove_existing_label(entity)
              draw_visual_label(board, new_index)

              puts "Reindexed: #{entity.name} (#{old_index} → #{new_index})"
            end

            model.commit_operation

            UI.messagebox("Reindexed #{labeled_boards.count} labeled board(s)")

          rescue => e
            model.abort_operation
            UI.messagebox("Error reindexing boards: #{e.message}")
          end
        end

      end

    end

  end
end
