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



## Installation

Add this line to your application's Gemfile:

    gem 'objectid_columns'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install objectid_columns

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it ( http://github.com/<my-github-username>/objectid_columns/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
