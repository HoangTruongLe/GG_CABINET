# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # GeometryFlattener - Service for flattening 3D geometry to XY plane (Z=0)
    # Removes vertices where Z > 0, effectively flattening geometry to XY plane
    class GeometryFlattener

      class << self

        # Flatten selected groups/components to XY plane
        # @return [Hash] Result hash with :success, :message, :entities_count
        def flatten_selected
          model = Sketchup.active_model
          selection = model.selection

          return {
            success: false,
            message: "No entities selected. Please select groups or components to flatten.",
            entities_count: 0
          } if selection.empty?

          model.start_operation('Flatten Geometry', true)

          begin
            processed = []

            selection.each do |entity|
              begin
                next unless entity.valid?

                # Step 1: Check if Group or ComponentInstance
                unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
                  puts "Warning: Skipping #{entity.class} - only Groups and Components can be flattened"
                  next
                end

                # Step 2: Make ComponentInstance unique if shared
                entity = make_unique(entity) if entity.is_a?(Sketchup::ComponentInstance)

                # Step 3: Remove vertices where Z > 0
                vertices_removed = remove_vertices_above_z0(entity)
                
                if vertices_removed > 0
                  processed << entity
                  puts "Removed #{vertices_removed} vertices above Z=0 from #{entity.class}"
                end

              rescue => e
                puts "Warning: Could not flatten #{entity.class}: #{e.message}"
              end
            end

            model.commit_operation

            {
              success: processed.length > 0,
              message: processed.length > 0 ?
                "Successfully flattened #{processed.length} entity(ies) to XY plane." :
                "No entities could be flattened.",
              entities_count: processed.length
            }
          rescue => e
            model.abort_operation
            {
              success: false,
              message: "Error: #{e.message}",
              entities_count: 0
            }
          end
        end

        def flatten_group(group)
          return unless group && group.is_a?(Sketchup::Group) && group.valid?
          remove_vertices_above_z0(group)
          group
        end

        private

        # Make ComponentInstance unique if shared
        # @param entity [Sketchup::ComponentInstance] Component to check
        # @return [Sketchup::ComponentInstance] Unique component
        def make_unique(entity)
          return entity unless entity.is_a?(Sketchup::ComponentInstance)
          return entity if entity.definition.instances.length <= 1

          model = Sketchup.active_model
          parent = entity.parent
          return entity unless parent && parent.respond_to?(:entities)

          # Create unique copy
          new_def = model.definitions.add("#{entity.definition.name}_unique_#{Time.now.to_i}")
          new_def.entities.add_entities(entity.definition.entities.to_a, true)

          new_instance = parent.entities.add_instance(new_def, entity.transformation)
          entity.erase!

          new_instance
        end

        # Remove vertices where Z > 0 by deleting their connected edges
        # @param entity [Sketchup::Group, Sketchup::ComponentInstance] Entity to flatten
        # @return [Integer] Number of vertices removed
        def remove_vertices_above_z0(entity)
          # Get entities collection
          entities_collection = entity.is_a?(Sketchup::Group) ?
            entity.entities : entity.definition.entities

          # Find all vertices in entities that respond to :vertices
          vertices_to_check = entities_collection.find_all { |e| e.respond_to?(:vertices) }
            .flat_map(&:vertices)
            .uniq

          # Select vertices where Z > 0.0001
          high_vertices_to_delete = vertices_to_check.select { |v| v.position.z > 0.0001 }
          count = high_vertices_to_delete.length

          # Delete edges connected to high vertices
          high_vertices_to_delete.each do |v|
            v.edges.each do |edge|
              edge.erase! unless edge.deleted?
            end
          end
          count
        end

      end

    end

  end
end
