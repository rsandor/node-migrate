Migrate - A database agnostic migration system for Node.js
================================================================================

By Ryan Sandor Richards

SQLite 3 Contribution by Curtis Schlak

Introduction
--------------------------------------------------------------------------------
Migrate is a tool that allows you to define database schema migrations with
javascript. It borrows very heavily from the ruby migration system and contains 
many of the same features. If you are unfamiliar with how migrations work don't 
fret, just read on and everything will be explained!

Requirements
--------------------------------------------------------------------------------
1. Node.js - http://github.com/ry/node
2. node-mysql - https://github.com/felixge/node-mysql
3. node-sqlite3 - https://github.com/developmentseed/node-sqlite3

Please note that at the current time we only support MySQL and SQLite 3 but
other DBMS' are on their way (next up: Postgres).

Installation
--------------------------------------------------------------------------------
1. Download the Migrate source - http://github.com/rsandor/node-migrate
2. Fill out the supplied "config.js"

Where, exactly, you include the migrate source in your project matters very
little as long as both migrate.js and config.js are in the same directory and
the node-mysql and migration paths in the configuration file are relative to
the directory where the migrate.js file resides.

The configuration file has the following keys:

* `dbms` - The database management system to use (currently we only support a
  a value of either `'mysql'` or `'sqlite3'`).
* `migration_path` - Relative path to the directory in which migrations are
  stored.
* `mysql` - Just a simple client configuration for mysql. Fill out your username,
  password, and any other information needed to connect to the database via
  node-mysql's `Client` class.
* `sqlite3` - Just a simple client configuration for SQLite 3. Fill out the
  filename for the database to which you would like to connect.

How do I use migrate?
--------------------------------------------------------------------------------
Once you have the configuration file filled you you can create a new migration
from the command line:

`node migrate.js create create_users_table`

This command will create a blank migration and stick it in the migrations folder
that you supplied in the configuration file. Once you fill out the migration's
up and down functions you can then apply the migration to your schema like so:

`node migrate.js migrate`

That command will determine if there are any migrations that have not been
applied and apply them sequentially until they are all done or one of them
fails.

If you wish to roll back any migrations that's super simple too, just use:

`node migrate.js rollback`

By default this will roll back only a single migration, but you can provide
a numeric parameter to tell it how many migrations you'd like it to roll back.
For instance, here's how you would roll back five migrations:

`node migrate.js rollback 5`

What is a migration?
--------------------------------------------------------------------------------
A migration is a programmatic way of defining incremental database schema 
changes. It has an "up" method for describing how to apply the changes, and a 
"down" method for removing them. Here is an example migration:
    var create_users_table = new Migration({
      up: function() {
        this.create_table('users', function(t) {
          t.integer('id');
          t.string('email');
          t.string('password');
          t.primary_key('id');
        });
      },
      down: function() {
        this.drop_table('users');
      }
    });
In the above migration the "up" function creates a table named "users" with
three fields (id, email, and password) and a primary key on id. The "down"
function reverses these changes and simply drops the entire "users" table.

When you run the migration it gets converted into a collection of database
agnostic objects which are then translated into SQL for the appropriate DBMS.

What can I do in a migration?
--------------------------------------------------------------------------------
The "up" and "down" methods of a migration support the exact same set of methods
. This means you can create and destroy schema information in both methods. The
Migration object supports the following methods:

### create_table(name, body)

This method creates a table with the given name and passes the newly created table 
representation to the supplied `body` closure. 
From within the body closure one can execute methods on the table to add columns
and indices. Here is a complete list of all the "table" methods available:

* `t.column(name, type, options)` - Creates a column with the given name, type
  and additional options. Additional options include: `limit`, `not_null`, 
  `precision`, `scale`, and `default_value`. `limit` controls the number of 
  bytes to use for the integer type, `not_null` is used to determine if the 
  column is allowed to be null, `precision` and `scale` are used for the 
  decimal data type, and `default_value` allows you to set the default value
  for the column.
* `t.primary_key(name)` - Sets the primary key for the table to the column with
  the given name.
* `t.index(name)` - Sets an index on the table for the column with the given name

Finally the body also contains shortcut functions for each abstract data-type
tracked by Migrate. Each function has the form `t.type(name, options)` where name
and options are as explained in the `t.column` method. Here's a complete list:

* `string`, `text`, `integer`, `float`, `decimal`, `datetime`, `timestamp`, `time`,
  `date`, `binary`, `boolean`
  
Example:
    this.create_table('high_scores', function(t) {
        t.integer('id');
        t.string('name', {limit: 32});
        t.create('score', 'integer', {limit: 8})
        t.datetime('date');
        t.primary_key('id');
        t.index('name');
    }); 
Producing SQL:
    CREATE TABLE high_scores (
        id INT,
        name VARCHAR(32),
        score BIGINT,
        date DATETIME,
        PRIMARY KEY (id),
        INDEX (name)
    );

### drop_table(name)
Simply drops a table from the schema. Example:

`this.drop_table('high_scores');`

Producing SQL:

`DROP_TABLE high_scores;`

### rename_table(old_name, new_name)
Renames a table. Example:

`this.rename_table('high_scores', 'all_time_high_scores');`

Producing SQL:

`RENAME TABLE high_scores TO all_time_high_scores;`

### change_table(name, body)

Has all of the same functionality as `create_table` except it is used to
modify existing tables and adds the following functionality to body method:

* `t.rename(old_name, new_column)` - Renames and alters a column.
* `t.change(name, type, options)` - Alters a column without changing its name.
* `t.remove(name)` - Removes a column from the table.
* `t.remove_index(name)` - Removes an index from the table.
* `t.remove_primary_key()` - Removes a primary key from the table.

Example:
    this.change_table('all_time_high_scores', function(t) {
      t.remove_index('name');
      t.remove_primary_key();
      t.remove('date');
      t.date('date');
      t.rename('score' {
        name: 'high_score',
        type: 'integer',
        limit: 4
      });
      t.change('name', 'string' {limit: 128});
    });
Producing SQL:
    ALTER TABLE all_time_high_scores
      DROP INDEX (name),
      DROP PRIMARY KEY,
      DROP COLUMN 'date',
      ADD COLUMN date DATE,
      CHANGE COLUMN score high_score INT,
      MODIFY COLUMN name VARCHAR(128);

### add_column(table_name, column_name, type, options)
Adds a column to a table. Example:

`this.add_column('all_time_high_scores', 'comment', 'string', {limit: 512});`

Producing SQL:

`ALTER TABLE all_time_high_scores ADD COLUMN comment VARCHAR(512);`

### rename_column(table_name, column_name, new_column)
Renames and modifies a column in a table. Example:
    this.rename('all_time_high_scores', 'high_score', {
      name: 'score',
      type: 'integer',
      limit: 8
    });
Producing SQL:
    ALTER TABLE all_time_high_scores CHANGE COLUMN high_score score BIGINT;

### change_column(table_name, column_name, type, options)
Changes a column's definition. Example:

`this.change_column('all_time_high_scores', 'comment', 'text');`

Producing SQL:

`ALTER TABLE all_time_high_scores MODIFY COLUMN comment TEXT;`

### remove_column(table_name, column_name)
Removes a column from a table. Example:

`this.remove_column('all_time_high_scores', 'date');`

Producing SQL:

`ALTER TABLE all_time_high_scores DROP COLUMN date;`

### add_index(table_name, column_name, options)
Adds an index to a table. Example:

`this.add_index('all_time_high_scores', 'id');`

Producing SQL:

`ALTER TABLE all_time_high_scores ADD INDEX (id);`

### remove_index(table_name, index_name)
Removes an index from a table. Example:

`this.remove_index('id');`

Producing SQL:

`ALTER TABLE all_time_high_scores DROP INDEX (id);`

### execute(sql)
Executes arbitrary SQL. Example:

`this.execute('insert into all_time_high_scores (name, score) values ('Ryan', 100000000);');`

Producing SQL:

`insert into all_time_high_scores (name, score) values ('Ryan', 100000000);`

Outtro
--------------------------------------------------------------------------------
So that about sums it up. Simple and easy ;). It's a very early alpha version so
please don't hate on only having MySQL and SQLite 3 support! If you have a
feature request feel free to send me a message and I'll try to get it in ASAP.

Thanks!

License and Legalese
--------------------------------------------------------------------------------

Copyright (c) 2010 Ryan Sandor Richards

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.