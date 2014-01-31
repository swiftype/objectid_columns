require 'objectid_columns'
require 'active_support'
require 'objectid_columns/has_objectid_columns'

module ObjectidColumns
  module ActiveRecord
    module Base
      extend ActiveSupport::Concern

      module ClassMethods
        def has_objectid_columns?
          false
        end

        [ :has_objectid_columns, :has_objectid_column, :has_objectid_primary_key ].each do |method_name|
          define_method(method_name) do |*args|
            include ::ObjectidColumns::HasObjectidColumns
            send(method_name, *args)
          end
        end
      end
    end
  end
end
