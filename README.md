# ObjectidColumns

Transparely store MongoDB [ObjectId](http://docs.mongodb.org/manual/reference/object-id/) values (the primary key of
all MongoDB tables) in ActiveRecord objects in a relational database. You can store values as:

* A binary column (`BINARY`, `VARBINARY`, `BLOB`, _etc._) of length at least 12; the ObjectId value will be stored as
  pure binary data &mdash; the most efficient format. (Most databases, including MySQL and PostgreSQL, can index this
  column and work with it just like a String; it just takes half as much space (!).)
* A String column (`CHAR`, `VARCHAR`, _etc._) of length at least 24; the ObjectId value will be stored as a hexadecimal
  string.

(Note that it is not possible to store binary data transparently in a String column, because not all byte sequences
are valid binary data in all possible character sets.)

Once declared, an ObjectId column will return instances of either `BSON::ObjectId` or `Moped::BSON::ObjectId`
(depending on which one you have loaded) when you access an attribute of a model that you've declared as an ObjectId
column. It will accept a String (in either hex or binary formats) or an instance of either of those classes when
assigning to the column.

This gem requires either the `moped` gem (which defines `Moped::BSON::ObjectId`) or the `bson` gem (which defines
`BSON::ObjectId`) for the actual ObjectId classes it uses. It declares an official dependency on neither, because we
want to allow you to use either one. It will accept either one when assigning ObjectIds; it will return ObjectIds as
whichever one you have loaded, (currently) preferring `BSON::ObjectId` if you have both.

## Installation

Add this line to your application's Gemfile:

    gem 'objectid_columns'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install objectid_columns

## Usage

If you name your object-ID columns with `_oid` at the end, simply do this:

    class MyModel < ActiveRecord::Base
      has_objectid_columns
    end

This will automatically find any columns that end in `_oid` and make them ObjectId columns. When reading them, you will
get back an instance of an ObjectId class (from `moped` or `bson`, depending on which one you have loaded; see the
introduction for more). When writing them, you can assign a String in hex or binary formats, or an instance of either
of the supported ObjectId classes.

If you didn't name your columns this way, or _don't_ want to pick up columns ending in `_oid`, just name them
explicitly:

    class MyModel < ActiveRecord::Base
      has_objectid_columns :some_oid, :foo
    end

This will not only define `some_oid` and `foo` as being ObjectId columns,

Note that trying to declare a column

Once you have done this:

    my_model = MyModel.find(...)
    my_model.

Note that to assign a binary-format string, it must have an encoding of `Encoding::BINARY` (which is an alias for
`Encoding::ASCII-8BIT`). (If your string has a different encoding, it may be coming from a source that does not
actually support full binary data transparently, which _will_ cause big problems.)

### Setting the Preferred Class

If you have both the `bson` and `moped` gems defined, then, by default, ObjectId columns will be returned as instances
of `bson`'s `BSON::ObjectId` class. If you want to use `moped`'s instead, do this:

    ObjectidColumns.preferred_bson_class = Moped::BSON::ObjectId

### Extensions

This gem extends String with a single method, `#to_bson_id`; it simply returns an instance of the preferred BSON class
from that String if it's in either the valid hex or the valid binary format, or raises `ArgumentError` otherwise.

This gem also extends whatever BSON ObjectId classes are loaded with methods `to_bson_id` (which just returns `self`),
and the method `to_binary`, which returns a binary String of length 12 for that object ID.

## Contributing

1. Fork it ( http://github.com/<my-github-username>/objectid_columns/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
