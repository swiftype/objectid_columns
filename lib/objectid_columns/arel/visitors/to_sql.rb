require 'active_support'

module ObjectidColumns
  module Arel
    module Visitors
      # This module gets mixed into Arel::Visitors::ToSql, which is the class that the Arel gem (which is really the
      # backbone of ActiveRecord's query language) uses to generate SQL. This teaches Arel what to do when it bumps
      # into an object of a BSON ID class -- _i.e._, how to convert it to a SQL literal.
      #
      # How this works depends on which version of ActiveRecord -- and therefore AREL -- you're using:
      #
      # * In Arel 4.x, the #visit... methods get called with two arguments. The first is the actual BSON ID that needs
      #   to be converted; the second provides context. From the second parameter, we can get the table name and
      #   column name. We use this to get a hold of the ObjectidColumnsManager via its class method .for_table, and,
      #   from there, a converted, valid value for the column in question (whether hex or binary).
      # * In Arel 3.x, unfortunately, we do not get passed any context information at all; we just get a BSON ID, and
      #   are told "here, convert that to a SQL representation". The problem is that we don't know whether to convert
      #   this to a string (hex) representation, or a pure-binary representation. So, instead, we do a gross hack:
      #   when we retrieve an object-id value out of the database, we tag it with a "preferred" representation (which
      #   is whatever its column is); then, when we need to convert such a value, we just use this preferred
      #   representation. This isn't perfect, but nicely solves the by-far-most-common case of this, which is where
      #   we're just calling #save or #save! on an ActiveRecord model that has an object-ID column as its primary key.
      #
      module ToSql
        extend ActiveSupport::Concern

        require 'arel'
        if ::Arel::VERSION =~ /^[23]\./
          def visit_Arel_Attributes_Attribute_with_objectid_columns(o, *args)
            out = visit_Arel_Attributes_Attribute_without_objectid_columns(o, *args)
            self.last_relation = o.relation
            out
          end

          included do
            alias_method_chain :visit_Arel_Attributes_Attribute, :objectid_columns


            alias :visit_Arel_Attributes_Integer :visit_Arel_Attributes_Attribute_with_objectid_columns
            alias :visit_Arel_Attributes_Float :visit_Arel_Attributes_Attribute_with_objectid_columns
            alias :visit_Arel_Attributes_Decimal :visit_Arel_Attributes_Attribute_with_objectid_columns
            alias :visit_Arel_Attributes_String :visit_Arel_Attributes_Attribute_with_objectid_columns
            alias :visit_Arel_Attributes_Time :visit_Arel_Attributes_Attribute_with_objectid_columns
            alias :visit_Arel_Attributes_Boolean :visit_Arel_Attributes_Attribute_with_objectid_columns

            attr_accessor :last_relation
          end
        end

        def visit_BSON_ObjectId(o, a = nil)
          column = if a then column_for(a) else last_column end
          relation = if a then a.relation else last_relation end

          raise "no column?!?" unless column
          raise "no relation?!?" unless relation

          quote(bson_objectid_value_from_parameter(o, column, relation), column)

#           $stderr.puts "last_column: #{last_column.inspect}"
#           $stderr.puts "last_relation: #{last_relation.inspect}"

#           value = if a # i.e., ActiveRecord 4.x
#             bson_objectid_value_from_parameter(o, a)
#           elsif o.objectid_preferred_conversion == :binary
#             o.to_binary
#           elsif o.objectid_preferred_conversion == :string
#             o.to_s
#           else
#             raise %{ObjectidColumns: You seem to be using an ObjectId value in a context where we can't
# tell whether to convert it to a binary or string representation. This can arise in certain
# scenarios, particularly with ActiveRecord/Arel 3.x (as opposed to 4.x).

# The solution is to convert this value manually (call #to_binary or #to_s on it,
# for pure-binary or hex representation, respectively) before using it.

# If you really want to dig in deeper and potentially offer a fix for this issue,
# see objectid_columns/lib/objectid_columns/arel/visitors/to_sql.}
#           end

#           quote(value, column)
        end

        alias_method :visit_Moped_BSON_ObjectId, :visit_BSON_ObjectId

        private
        def bson_objectid_value_from_parameter(o, column, relation)
          column_name = column.name

          manager = ObjectidColumns::ObjectidColumnsManager.for_table(relation.name)
          unless manager
            raise %{ObjectidColumns: You're trying to evaluate a SQL statement (in Arel, probably via ActiveRecord)
that contains a BSON ObjectId value -- you're trying to use the value '#{o}'
(of class #{o.class.name}) with column #{column_name.inspect} of table
#{relation.name.inspect}. However, we can't find any record of any ObjectId
columns being declared for that table anywhere.

As a result, we don't know whether this column should be treated as a binary or
a hexadecimal ObjectId, and hence don't know how to transform this value properly.}
          end

          unless manager.is_objectid_column?(column_name)
            raise %{ObjectidColumns: You're trying to evaluate a SQL statement (in Arel, probably via ActiveRecord)
that contains a BSON ObjectId value -- you're trying to use the value '#{o}'
(of class #{o.class.name}) with column #{column_name.inspect} of table
#{relation.name.inspect}.

While we can find a record of some ObjectId columns being declared for
that table, they don't appear to include #{column_name.inspect}. As such,
we don't knwo whether this column should be treated as a binary or a hexadecimal
ObjectId, and hence don't know how to transform this value properly.}
          end

          manager.to_valid_value_for_column(column_name, o)
        end
      end
    end
  end
end
