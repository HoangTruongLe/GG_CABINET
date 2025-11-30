# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # Service for scanning and finding boards in model
    # Phase 2: Complete implementation
    class BoardScanner
      attr_reader :model, :scan_results

      def initialize(model = nil)
        @model = model || Sketchup.active_model
        @scan_results = {}
      end

      # =================================================================
      # Main Scanning Methods
      # =================================================================

      # Scan entire model for all boards
      def scan_all_boards
        groups = collect_all_groups(@model.entities)

        boards = groups.select { |g| looks_like_board?(g) }
                       .map { |g| create_board_safe(g) }
                       .compact

        @scan_results = {
          total_groups: groups.count,
          board_candidates: boards.count,
          boards: boards,
          scanned_at: Time.now
        }

        boards
      end

      # Scan for boards in specific container (e.g., N2 playground)
      def scan_container(container)
        return [] unless container.is_a?(Sketchup::Group) || container.is_a?(Sketchup::ComponentInstance)

        groups = collect_all_groups(container.entities)

        boards = groups.select { |g| looks_like_board?(g) }
                       .map { |g| create_board_safe(g) }
                       .compact

        boards
      end

      # Scan N2 playground specifically
      def scan_playground
        n2 = PlaygroundCreator.find_n2_playground(@model)
        return [] unless n2

        scan_container(n2)
      end

      # Scan for unlabeled boards (boards without labels)
      def scan_unlabeled_boards(container = nil)
        container ||= @model.entities
        groups = collect_all_groups(container)

        unlabeled = groups.select do |g|
          looks_like_board?(g) && !has_label?(g)
        end

        unlabeled.map { |g| create_board_safe(g) }.compact
      end

      # Scan for extra boards (boards marked as extra)
      def scan_extra_boards(container = nil)
        container ||= @model.entities
        groups = collect_all_groups(container)

        extra = groups.select do |g|
          g.get_attribute('ABF', 'is-board') == true &&
          g.get_attribute('ABF', 'is-extra-board') == true
        end

        extra.map { |g| create_board_safe(g) }.compact
      end

      # Scan for boards with labels (already processed boards)
      def scan_labeled_boards(container = nil)
        container ||= @model.entities
        groups = collect_all_groups(container)

        labeled = groups.select do |g|
          looks_like_board?(g) && has_label?(g)
        end

        labeled.map { |g| create_board_safe(g) }.compact
      end

      # =================================================================
      # Classification & Grouping
      # =================================================================

      # Scan and group boards by classification (material + thickness)
      def scan_and_classify(container = nil)
        boards = container ? scan_container(container) : scan_all_boards

        classified = {}

        boards.each do |board|
          key = board.classification_key
          classified[key] ||= []
          classified[key] << board
        end

        classified
      end

      # Get statistics about boards in model
      def scan_statistics(container = nil)
        boards = container ? scan_container(container) : scan_all_boards

        {
          total_boards: boards.count,
          valid_boards: boards.count { |b| b.valid? },
          invalid_boards: boards.count { |b| !b.valid? },
          labeled_boards: boards.count { |b| b.label },
          unlabeled_boards: boards.count { |b| !b.label },
          extra_boards: boards.count { |b| b.entity.get_attribute('ABF', 'is-extra-board') },
          with_intersections: boards.count { |b| b.has_intersections? },
          classifications: scan_and_classify(container).keys.sort,
          classification_count: scan_and_classify(container).count
        }
      end

      # =================================================================
      # Filtering
      # =================================================================

      # Filter boards by material
      def filter_by_material(boards, material_name)
        boards.select { |b| b.material_name == material_name }
      end

      # Filter boards by thickness
      def filter_by_thickness(boards, thickness_mm)
        boards.select { |b| (b.thickness - thickness_mm).abs < 0.1 }
      end

      # Filter boards by classification key
      def filter_by_classification(boards, classification_key)
        boards.select { |b| b.classification_key == classification_key }
      end

      # Filter valid boards only
      def filter_valid_boards(boards)
        boards.select(&:valid?)
      end

      # Filter invalid boards only
      def filter_invalid_boards(boards)
        boards.reject(&:valid?)
      end

      # =================================================================
      # Helper Methods
      # =================================================================

      private

      # Recursively collect all groups from entities
      def collect_all_groups(entities, groups = [])
        entities.each do |entity|
          if entity.is_a?(Sketchup::Group)
            groups << entity
            # Recursively scan inside groups
            collect_all_groups(entity.entities, groups)
          elsif entity.is_a?(Sketchup::ComponentInstance)
            # Also scan component instances
            collect_all_groups(entity.definition.entities, groups)
          end
        end

        groups
      end

      # Check if a group looks like a board
      def looks_like_board?(group)
        return false unless group.is_a?(Sketchup::Group)
        return false unless group.valid?

        # Must have faces
        faces = group.entities.grep(Sketchup::Face)
        return false if faces.empty?

        # Must have reasonable bounds
        bounds = group.bounds
        return false if bounds.width < 1.mm || bounds.height < 1.mm || bounds.depth < 1.mm

        # Reasonable size (not too small, not too large)
        dimensions = [bounds.width, bounds.height, bounds.depth].map { |d| d / 1.mm }
        min_dim = dimensions.min
        max_dim = dimensions.max

        # Min dimension should be thickness (1mm - 50mm)
        return false if min_dim < 1 || min_dim > 50

        # Max dimension should be reasonable for a board (50mm - 5000mm)
        return false if max_dim < 50 || max_dim > 5000

        true
      end

      # Check if group has a label
      def has_label?(group)
        return false unless group.is_a?(Sketchup::Group)

        group.entities.any? do |ent|
          ent.is_a?(Sketchup::Group) &&
          ent.get_attribute('ABF', 'is-label') == true
        end
      end

      # Safely create a Board object
      def create_board_safe(group)
        Board.new(group)
      rescue StandardError => e
        puts "Warning: Failed to create Board from group #{group.entityID}: #{e.message}"
        nil
      end

      public

      # =================================================================
      # Development & Debugging
      # =================================================================

      # Print scan results summary
      def print_scan_summary(container = nil)
        stats = scan_statistics(container)

        puts "=" * 70
        puts "BOARD SCANNER - SUMMARY"
        puts "=" * 70
        puts ""
        puts "Total Boards: #{stats[:total_boards]}"
        puts "  Valid: #{stats[:valid_boards]}"
        puts "  Invalid: #{stats[:invalid_boards]}"
        puts ""
        puts "Labels:"
        puts "  Labeled: #{stats[:labeled_boards]}"
        puts "  Unlabeled: #{stats[:unlabeled_boards]}"
        puts "  Extra boards: #{stats[:extra_boards]}"
        puts ""
        puts "Features:"
        puts "  With intersections: #{stats[:with_intersections]}"
        puts ""
        puts "Classifications:"
        puts "  Total: #{stats[:classification_count]}"
        stats[:classifications].each do |key|
          count = scan_and_classify(container)[key].count
          puts "    - #{key}: #{count} boards"
        end
        puts "=" * 70
      end

      # Highlight all boards in model
      def highlight_all_boards(container = nil)
        boards = container ? scan_container(container) : scan_all_boards

        @model.selection.clear
        boards.each do |board|
          @model.selection.add(board.entity)
        end

        puts "Highlighted #{boards.count} boards"
      end

      # =================================================================
      # Class Methods (convenience)
      # =================================================================

      class << self
        # Quick scan of entire model
        def scan_model(model = nil)
          scanner = new(model)
          scanner.scan_all_boards
        end

        # Quick scan of playground
        def scan_playground(model = nil)
          scanner = new(model)
          scanner.scan_playground
        end

        # Quick scan of extra boards
        def scan_extra_boards(model = nil)
          scanner = new(model)
          scanner.scan_extra_boards
        end

        # Quick statistics
        def statistics(model = nil)
          scanner = new(model)
          scanner.scan_statistics
        end

        # Quick print summary
        def print_summary(model = nil)
          scanner = new(model)
          scanner.print_scan_summary
        end
      end
    end

  end
end
