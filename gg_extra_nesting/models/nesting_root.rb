# frozen_string_literal: true

module GG_Cabinet
  module ExtraNesting

    # NestingRoot model - represents the root nesting container
    # Phase 4 implementation
    class NestingRoot < PersistentEntity
      attr_reader :sheets

      def initialize(sketchup_group = nil)
        super(sketchup_group)
        @sheets = []
      end

      # Find nesting root in model
      def self.find_in_model(model)
        root_group = model.entities.find do |e|
          e.is_a?(Sketchup::Group) &&
          e.get_attribute('ABF', 'is-nesting-root')
        end

        return nil unless root_group

        new(root_group)
      end
    end

  end
end
