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

`ObjectidColumns` also allows you to use ObjectId values as primary keys; it will assign them to new records by
default, and make sure `find(id)` accepts them.

This gem requires either the `moped` gem (which defines `Moped::BSON::ObjectId`) or the `bson` gem (which defines
`BSON::ObjectId`) for the actual ObjectId classes it uses. It declares an official dependency on neither, because we
want to allow you to use either one. It will accept either one when assigning ObjectIds; it will return ObjectIds as
whichever one you have loaded, (currently) preferring `BSON::ObjectId` if you have both.

ObjectidColumns supports Ruby 1.8.7, 1.9.3, 2.0.0, and 2.1.0, plus JRuby 1.7.9; it supports ActiveRecord 3.0.20,
3.1.12, 3.2.16, and 4.0.2. It supports SQLite 3.x, MySQL 5.x, and PostgreSQL 8.x. (These are just the versions it's
tested against; while it will not work with ActiveRecord 2.x, it is otherwise highly unlikely to be sensitive to
exact ActiveRecord or Ruby versions, or type of RDBMS, and generally should work with most combinations.)

Current build status: ![Current Build Status](https://api.travis-ci.org/swiftype/objectid_columns.png?branch=master)

Brought to you by the folks at [Swiftype](https://www.swiftype.com). First version written by [Andrew Geweke](https://www.github.com/ageweke).

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

This will not only define `some_oid` and `foo` as being ObjectId columns, but it will also skip the automatic detection
of columns ending in `_oid`.

Note that trying to declare a column as an ObjectId column if it isn't of a supported type (a type that ActiveRecord
considers to be `:string` or `:binary`), or if it isn't long enough to support an ObjectId (twelve characters for
binary columns, 24 for string columns); this will happen from the `has_objectid_columns` call (so at load time for the
model class).

Once you have declared such a column:

    my_model = MyModel.find(...)

    my_model.my_oid                    # => BSON::ObjectId('52eab2cf78161f1314000001')
    my_model.my_oid.to_s               # => "52eab2cf78161f1314000001" (built-in behavior from BSON::ObjectId)
    my_model.my_oid.to_binary          # => "R\xEA\xB2\xCFx\x16\x1F\x13\x14\x00\x00\x01"
    my_model.my_oid.to_binary.encoding # => #<Encoding:ASCII-8BIT>

    my_model.my_oid = BSON::ObjectId.new         # OK
    my_model.my_oid = "52eab32878161f1314000002" # OK
    my_model.my_oid = "R\xEA\xB2\xCFx\x16\x1F\x13\x14\x00\x00\x01" # OK

Note that to assign a binary-format string, it must have an encoding of `Encoding::BINARY` (which is an alias for
`Encoding::ASCII-8BIT`). (If your string has a different encoding, it may be coming from a source that does not
actually support full binary data transparently, which _will_ cause big problems.)

### Using an ObjectId for a Primary Key

You can use ObjectId values as primary keys:

    class MyModel < ActiveRecord::Base
      has_objectid_primary_key
    end

Perhaps obviously, your primary-key column must either be `:binary` of length >= 12 or `:string` of length >= 24.

If your primary-key column is not called `:id`, you must do one of two things:

* Set the primary key on the class _before_ you call `has_objectid_primary_key`, by just using the normal ActiveRecord
  `self.primary_key = :foo` syntax.
* Pass the primary key as an argument to `has_objectid_primary_key`: `has_objectid_primary_key :foo`.

(The two are exactly equivalent.)

When you do this, `ObjectidColumns` adds a `before_create` hook to your model, assigning a new ObjectId immediately
before the first time a row is saved in the database. This will not replace an existing ID, so, if you always (or
sometimes) assign a new ID yourself, `ObjectidColumns` will not overwrite your ID.

Perhaps obviously, this means that new IDs are generated and stored client-side; you almost certainly should declare
your primary-key column as `NOT NULL`, but you don't need to give it a default (and probably shouldn't, unless you're
using a database function that is capable of generating correctly-formatted ObjectId values using the correct
algorithm).

### Setting the Preferred Class

If you have both the `bson` and `moped` gems defined, then, by default, ObjectId columns will be returned as instances
of `bson`'s `BSON::ObjectId` class. If you want to use `moped`'s instead, do this:

    ObjectidColumns.preferred_bson_class = Moped::BSON::ObjectId

### Extensions

This gem extends String with a single method, `#to_bson_id`; it simply returns an instance of the preferred BSON class
from that String if it's in either the valid hex or the valid binary format, or raises `ArgumentError` otherwise.

This gem also extends whatever BSON ObjectId classes are loaded with methods `to_bson_id` (which just returns `self`),
and the method `to_binary`, which returns a binary String of length 12 for that object ID.

### Running Specs

`objectid_columns` has thorough system-level (_i.e._, integration) tests, written in RSpec. Because nearly all of its
functionality is centered around interfacing with ActiveRecord (as opposed to having significant, complex code within
its codebase directly), there are no unit tests &mdash; they would simply be setting complex expectations around calls
to ActiveRecord, making the tests fragile and not particularly useful.

In order to run these specs, you must have access to a database you can use. It's best if the database is dedicated
to running these specs. The tests create and destroy their own tables, and make every effort to clean up anything they
created at the end &mdash; so it should be possible to piggyback on top of an existing database you also use for other
things. However, it's _always_ much safer to use a dedicated database. (Note that this is intentional use of the word
"database", as opposed to "database server"; you don't need, for example, an entirely separate instance of `mysqld`
&mdash; just a separate database that you can switch to using `USE ....`.)

Once you have this set up, simply create a file at the root level of the Gem (_i.e._, inside the root
`objectid_columns` directory) called `spec_database_config.rb`, and define a constant
`OBJECTID_COLUMNS_SPEC_DATABASE_CONFIG` as so:

    OBJECTID_COLUMNS_SPEC_DATABASE_CONFIG = {
      :database_gem_name => 'mysql2',
      :require => 'mysql2',
      :config => {
        :adapter => 'mysql2',
        :database => 'objectid_columns_specs_db',
        :username => 'root'
      }
    }

The keys are as follows:

* `:database_gem_name` is the name of the RubyGem that provides access to the database &mdash; exactly as you'd put
  it in a `Gemfile`;
* `:require` is whatever should be passed to Ruby's built-in `require` statement to require the Gem &mdash;
   typically this is the same as `:database_gem_name`, but not always (this is the same as a Gemfile's `:require => ..
   ` syntax);
* `:config` is exactly what gets passed to `ActiveRecord::Base.establish_connection`, and so you can pass any
  options that it accepts (which are the same as what goes in Rails' `database.yml`).

Once you've done this, you can run the system specs using `bundle exec rspec spec/objectid_columns/system`. (Or run
them along with the unit specs with a simple `bundle exec rspec spec`.)

Note that there's also support deep in the code (in
`objectid_columns/spec/objectid_columns/helpers/database_helper.rb`)
for defining connections to [Travis CI](https://travis-ci.org/)'s database options, so that Travis can run the tests
automatically. Generally, you don't need to worry about this, but it's worth noting.

## Contributing

1. Fork it ( http://github.com/swiftype/objectid_columns/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
