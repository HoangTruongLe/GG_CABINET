# frozen_string_literal: true

require 'singleton'
require 'json'

module GG_Cabinet
  module ExtraNesting

    # Simple in-memory database with JSON export/import
    # Singleton pattern - one instance per session
    class Database
      include Singleton

      def initialize
        @store = {}
      end

      # Save record
      def save(table, id, data)
        @store[table] ||= {}
        @store[table][id] = data
      end

      # Find by ID
      def find(table, id)
        @store.dig(table, id)
      end

      # Find by conditions
      def find_by(table, conditions)
        return [] unless @store[table]

        @store[table].values.select do |record|
          conditions.all? { |k, v| record[k] == v }
        end
      end

      # Get all records from table
      def where(table, conditions = nil)
        return [] unless @store[table]

        if conditions.nil?
          @store[table].values
        else
          @store[table].values.select do |record|
            conditions.all? { |k, v| record[k] == v }
          end
        end
      end

      # Delete record
      def delete(table, id)
        return unless @store[table]
        @store[table].delete(id)
      end

      # Clear table
      def clear_table(table)
        @store[table] = {}
      end

      # Clear all
      def clear_all
        @store = {}
      end

      # Export to JSON
      def export_to_json
        JSON.pretty_generate(@store)
      end

      # Import from JSON
      def import_from_json(json_string)
        @store = JSON.parse(json_string)
      end

      # Save to file
      def save_to_file(file_path)
        File.write(file_path, export_to_json)
      end

      # Load from file
      def load_from_file(file_path)
        return unless File.exist?(file_path)
        import_from_json(File.read(file_path))
      end

      # Statistics
      def stats
        {
          tables: @store.keys,
          total_records: @store.values.sum { |table| table.size }
        }
      end
    end

  end
end
