module ObjectidColumns
  module Arel
    module Visitors
      # This module gets mixed into Arel::Visitors::ToSql, which is the class that the Arel gem (which is really the
      # backbone of ActiveRecord's query language) uses to generate SQL. This teaches Arel what to do when it bumps
      # into an object of a BSON ID class -- _i.e._, how to convert it to a SQL literal.
      #
      # Because once we're in the world of Arel we no longer have any access to the ActiveRecord model, we need to
      # be able to fetch it by name; this is what ObjectidColumns::ObjectidColumnsManager.for_table is for.
      module ToSql
        def visit_BSON_ObjectId(o, a)
          column = column_for(a)
          column_name = column.name

          manager = ObjectidColumns::ObjectidColumnsManager.for_table(a.relation.name)
          unless manager
            raise %{ObjectidColumns: You're trying to evaluate a SQL statement (in Arel, probably via ActiveRecord)
that contains a BSON ObjectId value -- you're trying to use the value '#{o}'
(of class #{o.class.name}) with column #{column_name.inspect} of table
#{a.relation.name.inspect}. However, we can't find any record of any ObjectId
columns being declared for that table anywhere.

As a result, we don't know whether this column should be treated as a binary or
a hexadecimal ObjectId, and hence don't know how to transform this value properly.}
          end

          unless manager.is_objectid_column?(column_name)
            raise %{ObjectidColumns: You're trying to evaluate a SQL statement (in Arel, probably via ActiveRecord)
that contains a BSON ObjectId value -- you're trying to use the value '#{o}'
(of class #{o.class.name}) with column #{column_name.inspect} of table
#{a.relation.name.inspect}.

While we can find a record of some ObjectId columns being declared for
that table, they don't appear to include #{column_name.inspect}. As such,
we don't knwo whether this column should be treated as a binary or a hexadecimal
ObjectId, and hence don't know how to transform this value properly.}
          end

          value = manager.to_valid_value_for_column(column_name, o)
          quote(value, column)
        end
      end
    end
  end
end
