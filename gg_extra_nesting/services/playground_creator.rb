# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # Service for creating and managing N2 Playground
    # N2 is a copy of N1 nesting root offset 20000mm to the right
    # Used for safe development without corrupting N1 data
    class PlaygroundCreator

      PLAYGROUND_OFFSET_X = 20000.mm
      PLAYGROUND_NAME = "__N2_Playground_ExtraNesting"

      # Create or find existing playground
      def self.create_or_find_playground(model)
        # Find N1 nesting root
        n1_root = find_n1_nesting_root(model)

        unless n1_root
          UI.messagebox("N1 Nesting Root not found!\n\nPlease ensure you have a nesting root with attribute:\nABF > 'is-nesting-root' = true")
          return nil
        end

        # Check if N2 playground already exists
        n2_root = find_n2_playground(model)

        if n2_root
          puts "✓ N2 Playground found (reusing existing)"
          return n2_root
        end

        # Clone N1 root to create N2 playground
        puts "Creating N2 Playground (offset: #{PLAYGROUND_OFFSET_X / 1.mm}mm)..."
        n2_root = clone_n1_to_playground(n1_root, model)

        puts "✓ N2 Playground created successfully"
        n2_root
      end

      # Find N1 nesting root (original)
      def self.find_n1_nesting_root(model)
        model.entities.find do |e|
          e.is_a?(Sketchup::Group) &&
          e.get_attribute('ABF', 'is-nesting-root') &&
          !e.get_attribute('ABF', 'is-playground')
        end
      end

      # Find N2 playground (development copy)
      def self.find_n2_playground(model)
        model.entities.find do |e|
          e.is_a?(Sketchup::Group) &&
          e.get_attribute('ABF', 'is-nesting-root') &&
          e.get_attribute('ABF', 'is-playground')
        end
      end

      # Clone N1 root to create N2 playground
      def self.clone_n1_to_playground(n1_root, model)
        model.start_operation('Create N2 Playground', true)

        begin
          # Make a copy of N1 root
          n2_root = model.entities.add_instance(
            n1_root.definition,
            n1_root.transformation
          )

          # Make it unique (so edits don't affect N1)
          n2_root.make_unique

          # Mark as playground
          n2_root.set_attribute('ABF', 'is-playground', true)
          n2_root.set_attribute('ABF', 'playground-source', n1_root.entityID)
          n2_root.set_attribute('ABF', 'created-at', Time.now.to_s)
          n2_root.name = PLAYGROUND_NAME

          # Offset 20000mm to the right
          offset = Geom::Transformation.translation([PLAYGROUND_OFFSET_X, 0, 0])
          n2_root.transform!(offset)

          model.commit_operation

          puts "  ↳ Source N1: #{n1_root.name} (ID: #{n1_root.entityID})"
          puts "  ↳ Created N2: #{n2_root.name} (ID: #{n2_root.entityID})"
          puts "  ↳ Offset: +#{PLAYGROUND_OFFSET_X / 1.mm}mm on X-axis"

          n2_root
        rescue => e
          model.abort_operation
          puts "✗ Error creating playground: #{e.message}"
          puts e.backtrace.join("\n")
          nil
        end
      end

      # Delete playground
      def self.delete_playground(model)
        n2_root = find_n2_playground(model)

        unless n2_root
          puts "No playground found to delete"
          return false
        end

        model.start_operation('Delete N2 Playground', true)
        n2_root.erase!
        model.commit_operation

        puts "✓ N2 Playground deleted"
        true
      end

      # Reset playground (delete and recreate)
      def self.reset_playground(model)
        delete_playground(model)
        create_or_find_playground(model)
      end

      # Get playground info
      def self.playground_info(model)
        n1 = find_n1_nesting_root(model)
        n2 = find_n2_playground(model)

        {
          has_n1: !n1.nil?,
          has_n2: !n2.nil?,
          n1_id: n1&.entityID,
          n2_id: n2&.entityID,
          n1_name: n1&.name,
          n2_name: n2&.name,
          n1_bounds: n1&.bounds,
          n2_bounds: n2&.bounds
        }
      end

    end

  end
end
