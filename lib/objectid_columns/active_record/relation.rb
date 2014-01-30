require 'objectid_columns'

module ObjectidColumns
  module ActiveRecord
    module Relation
      def where(*args)
        ocs = oid_columns rescue [ ]

        return super(*args) unless ocs.length > 0

        if args.length == 1 && args[0].kind_of?(Hash)
          query = { }
          args[0].each do |key, value|
            if ocs.include?(key.to_sym)
              if (! value)
                query[key] = nil
              elsif value.respond_to?(:to_bson_id)
                type = columns_hash[key.to_s].type
                value = value.to_bson_id
                value = case type
                when :string then value.to_s
                when :binary then value.to_binary
                else raise "Unknown type #{type.inspect}"
                end
                query[key] = value
              else
                raise ArgumentError, "You're trying to constrain on ObjectID column #{key.inspect}, but you passed #{value.inspect}, and we don't know how to convert that to an ObjectID value."
              end
            else
              query[key] = value
            end
          end

          super(query)
        else
          super(*args)
        end
      end
    end
  end
end
