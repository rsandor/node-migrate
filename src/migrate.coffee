###
 * migrate.js - A database agnostic migration module for Node.js.
 * Copyright (c) 2010 - 2011 Ryan Sandor Richards
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
###

###
Supported Data-types
### 
DATA_TYPES = [
  'string',
  'text',
  'integer',
  'float',
  'decimal',
  'datetime',
  'timestamp',
  'time',
  'date',
  'binary',
  'boolean'
];

# Handy options merging function
merge = (base, ext) ->
	rv = {}
	for k, v of base
		rv[k] = if ext[k]? then ext[k] else base[k]
	rv
	
# Determines if a given type is valid
valid_type = (type) -> DATA_TYPES.indexOf(type) >= 0

Module = (fn) -> fn()


###
Create table rule representation.
###
class CreateTable
	@type_helper = (type) -> ->
		return unless arguments.length
		column = { type: type }
		
		if typeof(arguments[0]) == "string"
			column.name = arguments[0]
			if arguments[1] and typeof(arguments[1]) == "object"
				column = merge column, arguments[2]
		else if typeof(arguments[0]) == "object"
			column = merge column, arguments[0]
		else
			return
		
		@column column
			
	constructor: (name) ->
		[@columns, @indices, @primary_key_name] = [[], [], null]
	
	column: ->
		column =
      name: null
      type: null
      limit: null
      not_null: null
      precision: null
      scale: null
      default_value: null
      auto_increment: null

		return unless arguments.length > 0
		
		if typeof(arguments[0]) == 'string'
			column.name = arguments[0]
			if arguments.length > 1
				column.type = arguments[1]
			if arguments[2] and typeof(arguments[2]) == "object"
				column = merge column, arguments[2]
		else if typeof(arguments[0]) == 'object'
			column = merge column, arguments[0]
			return unless column.name? and column.type?
		
		@columns.push(column) if valid_type column.type
		
		# Create typed helper functions
		for type in DATA_TYPES
			@[type] = CreateTable.type_helper(type)
	
	primary_key: (name) ->
		@primary_key_name = name if name?
	
	index: (name, options) ->
		@indices.push(name) if name?
	


###
Drop table representation.
###
class DropTable
	constructor: (@name) ->

###
Rename table representation.
###
class RenameTable
	constructor: (@old_name, @new_name) ->
 
###
Change/Modify Table Representation.
###
class ChangeTable extends CreateTable
	constructor: (name) ->
		super(name)
		@remove_columns = []
		@change_columns = []
	 	@remove_indices = []
	  @rename_columns = {}
		@remove_key = false
	
	rename: (name, column) ->
		@rename_columns[name] = @column column
	
	change: ->
		@column.apply @, arguments
		@change_columns.push @columns.pop()
	
	remove: (name) ->
		@remove_columns.push name
	
	remove_index: (name) ->
		@remove_indices.push name
	
	remove_primary_key: ->
		@remove_key = true


###
Add Column Representation.
###
class AddColumn
	constructor: (@table_name, @name, @type, options) ->
		if typeof(options) == "object"
			@[k] = v for k, v of options


###
Rename Column Representation.
###
class RenameColumn
	constructor: (@table_name, @name, column) ->
		@new_name = column.name
		delete column.name
		@[k] = v for k, v of column


###
Change column representation.
###
class ChangeColumn
	constructor: (@table_name, @name, @type, options) ->
		if typeof(options) == "object"
			@[k] = v for k, v of options


###
Remove Column Represenatation.
###
class RemoveColumn
	constructor: (@table_name, @name) ->

	
###
Add Index Represenatation.
###
class AddIndex
	constructor: (@table_name, @name, options) ->
		if typeof(options) == "object"
			@[k] = v for k, v of options


###
Remove Index Represenatation.
###
class RemoveIndex
	constructor: (@table_name, @name) ->


###
Migration object.
###
class Migration
	sql = ''
	
	constructor: (@options) ->
		@reset()
	
	reset: ->
		@sql = ''
	
	encode: (rule) ->
		@sql += encoding if (encoding = encoder.encode rule)?
	
	toString: ->
		@sql

	up: ->
		reset()
		@options.up.apply(this) if @options.up?
	
	down: ->
		reset()
		@options.down.apply(this) if @options.down?
	
	_with_body: (rule, body) ->
		if body? and typeof(body) == 'function'
			body(rule)
		@encode rule
	
	create_table: (name, body) ->
		@_with_body new CreateTable(name), body

	drop_table: (name) ->
		@encode new DropTable(name)
	
	change_table: (name, body) ->
		@_with_body new ChangeTable(name), body
		
	rename_table: (old_name, new_name) ->
		@encode new RenameTable(old_name, new_name)
	
	add_column: (table, column, type, options) ->
		@encode new AddColumn(table, column, type, options)
	
	rename_column: (table, column, new_column) ->
		@encode new RenameColumn(table, column, new_column)
	
	change_column: (table, column, type, options) ->
		@encode new ChangeColumn(table, column, type, options)

  remove_column: (table, column) ->
    @encode new RemoveColumn(table, column)

	add_index: (table_name, column_name, options) ->
		@encode new AddIndex(table_name, column_name, options)
  
	remove_index: (table_name, index_name) ->
    @encode new RemoveIndex(table_name, index_name)

	execute: (s) ->
		@sql += s


###
Holds the SQL encoders.
###
Encoders = {};

###
Translates migrations into valid MySQL.
###
Encoders['mysql'] = Module ->
	types =
    'integer': 'INT'
    'string': 'VARCHAR'
    'text': 'TEXT'
    'float': 'FLOAT'
    'decimal': 'DECIMAL'
    'datetime': 'DATETIME'
    'timestamp': 'TIMESTAMP'
    'time': 'TIME'
    'date': 'DATE'
    'binary': 'VARBINARY'
    'boolean': 'TINYINT'
   
  # Intensely helpful function for creating a MySQL type from a column object.
  parse_type = (column) ->
    # type, limit, precision, scale
    type = types[column.type] if column.type?
    
		switch column.type
			when 'integer'
				type = switch column.limit
					when 1 then 'TINYINT'
					when 2 then 'SMALLINT'
					when 3 then 'MEDIUMINT'
					when 8 then 'BIGINT'
					else 'INT'
			when 'string', 'binary'
				type += if column.limit? then "(#{column.limit})" else "(255)"
			when 'decimal'
				if column.precision? and column.scale?
					type += "(#{column.precision}, #{column.scale})"
				else if column.precision?
					type += "(" + column.precision + ")";

		type += ' NOT NULL' if column.not_null
		type += ' AUTO_INCREMENT' if column.auto_increment
		
		if column.default_value?
			type += ' DEFAULT '
			if column.type == 'string' or column.type == 'text'
				type += "'" + column.default_value + "'"
			else
				type += column.default_value
		
    type
  
  # The following functions do the the actual work of generating the SQL for the encode function.
	create_table = (table) ->
		[sql, defs] = ["CREATE TABLE " + table.name, []]
		for column in table.columns
			defs.push "\t#{table.columns[i].name} #{@parse_type table.columns[i]}"
		
		if table.primary_key_name?
			defs.push "\tPRIMARY KEY (#{table.primary_key_name})"
		
		sql += " (\n #{defs.join(',\n')}\n)" if defs.length
		sql += ";\n"
		
		for (i = 0; i < table.indices.length; i++)
		for index in table.indices
      sql += "ALTER TABLE #{table.name} ADD INDEX (#{index});\n";
		
		return sql
		
	drop_table = (table) ->
		"DROP TABLE #{table.name};\n"

	rename_table = (table) ->
		"RENAME TABLE #{table.old_name} to #{table.new_name};\n"
  
	change_table = (table) ->
		[sql, defs] = ["ALTER TABLE #{table.name}", []]
		
		for column in table.columns
			defs.push "\tADD COLUMN #{column.name} #{parse_type column}"
		
		for index in table.indices
			defs.push "\tADD INDEX(#{index})"
		
		if table.primary_key_name?
			defs.push "\tADD PRIMARY KEY(#{table.primary_key_name})"
		
		for column in table.remove_columns
			defs.push "\tDROP COLUMN #{column}"
			
    if table.remove_key?
      defs.push "\tDROP PRIMARY KEY"
    
    for index in table.remove_indices
      defs.push "\tDROP INDEX #{index}"

		for column in table.change_columns
			defs.push "\tMODIFY COLUMN #{column.name} #{parse_type column}"
   
		for name, column of table.rename_columns
			defs.push "\tCHANGE COLUMN #{name} #{column.name} #{parse_type column}"
   
    if defs.length
      sql += "\n#{defs.join(',\n')}"
      
   sql + ";\n";
  
  add_column = (column) ->
		"ALTER TABLE #{column.table_name} ADD COLUMN #{column.name} #{parse_type column};\n"
  
	rename_column = (column) ->
    "ALTER TABLE #{column.table_name} CHANGE COLUMN #{column.name} #{column.new_name} #{parse_type column};\n"

  change_column = (column) ->
    "ALTER TABLE #{column.table_name} MODIFY COLUMN #{column.name} #{parse_type(column)};\n";
  
	remove_column = (column) ->
    "ALTER TABLE #{column.table_name} DROP COLUMN #{column.name};\n"
  
	add_index = (index) ->
		"ALTER TABLE #{index.table_name} ADD INDEX (#{index.name});\n"
  
  remove_index = (index) ->
		"ALTER TABLE #{index.table_name} DROP INDEX (#{index.name});\n"

  return ->
		encode: (o) ->
			return change_table(o) if (o instanceof ChangeTable)
      return create_table(o) if (o instanceof CreateTable)
      return drop_table(o) if (o instanceof DropTable)
			return rename_table(o) if (o instanceof RenameTable)
      return add_column(o) if (o instanceof AddColumn)
			return rename_column(o) if (o instanceof RenameColumn)
			return change_column(o) if (o instanceof ChangeColumn)
			return remove_column(o) if (o instanceof RemoveColumn)
			return add_index(o) if (o instanceof AddIndex)
			return remove_index(o) if (o instanceof RemoveIndex)
			throw "Error: MySQL Encoder Encountered Unknown Rule Type."
			

###
Translates migrations into valid SQLite 3.
###
Encoders['sqlite3'] = Module ->
  # Mapping of abstract migrate types to concrete SQLite 3 types
  var types =
    'integer': 'INT'
    'string': 'VARCHAR'
    'text': 'TEXT'
    'float': 'FLOAT'
    'decimal': 'DECIMAL'
    'datetime': 'DATETIME'
    'timestamp': 'TIMESTAMP'
    'time': 'TIME'
    'date': 'DATE'
    'binary': 'VARBINARY'
    'boolean': 'TINYINT'
   
  # Intensely helpful function for creating a SQLite type from a column object.
  parse_type = (column) ->
    # type, limit, precision, scale
    type = types[column.type] if column.type?
    
		switch column.type
			when 'integer'
				type = switch column.limit
					when 1 then 'TINYINT'
					when 2 then 'SMALLINT'
					when 3 then 'MEDIUMINT'
					when 8 then 'BIGINT'
					else 'INT'
			when 'string', 'binary'
				type += if column.limit? then "(#{column.limit})" else "(255)"
			when 'decimal'
				if column.precision? and column.scale?
					type += "(#{column.precision}, #{column.scale})"
				else if column.precision?
					type += "(" + column.precision + ")";

		type += ' NOT NULL' if column.not_null
		type += ' AUTOINCREMENT' if column.auto_increment
		
		if column.default_value?
			type += ' DEFAULT '
			if column.type == 'string' or column.type == 'text'
				type += "'" + column.default_value + "'"
			else
				type += column.default_value
		
    type
  
  # The following functions do the the actual work of generating the SQL for the encode function.
  create_table = (table) ->
    [sql, defs] = ["CREATE TABLE #{table.name}", []]
    
		for column in table.columns
			defs.push "\t#{column.name} #{parse_type column}"
		
    if table.primary_key_name
      defs.push "\tPRIMARY KEY (#{table.primary_key_name})"

		sql += "(\n#{defs.join(',\n')}\n)" if defs.length
    sql += ";\n";
  
		for index in table.indices
			sql += "\tCREATE INDEX IF NOT EXISTS ix_#{table.name}_#{index} ON #{table.name}(#{index});"

    sql
  
	drop_table = (table) ->
		"DROP TABLE #{table.name};\n";
  
  rename_table = (table) ->
    "ALTER TABLE #{table.old_name} RENAME TO #{table.new_name};\n"
  
  change_table = (table) ->
    if table.primary_key_name or table.remove_columns.length or table.remove_key or table.change_columns.length or table.rename_columns.length
      throw 'You can only add columns to tables in a change_table migration.'

    [sql, defs] = ["ALTER TABLE #{table.name}", []]
    
		for column in table.columns
			defs.push "\tADD COLUMN #{table.columns[i].name} #{parse_type table.columns[i]}"
    
		sql += "(\n#{defs.join(',\n')}\n)" if defs.length
    
		for index in table.indices
			sql += "\nCREATE INDEX IF NOT EXISTS ix_" + table.name + "_" + index + " ON " + table.name + "(" + index + ");";
		
		for index in table.remove_indices
      sql += "\nDROP INDEX IF EXISTS ix_" + table.name + "_" + index + " ON " + table.name + "(" + index + ");";

		sql
  
  add_column = (column) ->
    "ALTER TABLE " + column.table_name + " ADD COLUMN " + column.name + " " + parse_type(column) + ";\n"
  
	rename_column = (column) ->
		exit('You can only add columns to tables in a change_table migration.')
  
  change_column = (column) ->
		exit('You can only add columns to tables in a change_table migration.')
  
  remove_column = (column) ->
		exit('You can only add columns to tables in a change_table migration.')
  
  add_index = (index) ->
    "CREATE INDEX IF NOT EXISTS ix_" + index.table_name + "_" + index.name + " ON " + index.table_name + "(" + index.name + ");"
  
  remove_index = (index) ->
		"DROP INDEX IF EXISTS ix_" + index.table_name + "_" + index.name + " ON " + index.table_name + "(" + index.name + ");"
  
	return
		encode: ->
			return change_table(o) if (o instanceof ChangeTable)
      return create_table(o) if (o instanceof CreateTable)
      return drop_table(o) if (o instanceof DropTable)
			return rename_table(o) if (o instanceof RenameTable)
      return add_column(o) if (o instanceof AddColumn)
			return rename_column(o) if (o instanceof RenameColumn)
			return change_column(o) if (o instanceof ChangeColumn)
			return remove_column(o) if (o instanceof RemoveColumn)
			return add_index(o) if (o instanceof AddIndex)
			return remove_index(o) if (o instanceof RemoveIndex)
			throw "Error: SQLite 3 Encoder Encountered Unknown Rule Type.";


# The real "beef" is here, this section handles the command-line usage of the module.
sys = require('util')
{exec} = require('child_process')
fs = require('fs')
config = require('./config')
  
var encoder, mysql, client;

# Usage text
usage = [
  "migrate.js usage:",
  "\tnode migrate.js create <name> - Create a new migration with the given name",
  "\tnode migrate.js migrate - Run pending migrations",
  "\tnode migrate.js rollback [n] - Roll back by a number of migrations."
].join("\n");
  

# Migration template (for generating new migrations)
migration_template = [
  "var %name = new Migration({",
  "\tup: function() {",
  "\t},", 
  "\tdown: function() {",
  "\t}", 
  "});"
].join("\n");


###
Gracefully exits the script and closes any open DB connections.
###
exit = (msg) ->
  sys.puts(msg)if (msg)
  client.end() if (client)
    

###
Creates a new migration.
###
create = ->
  exit("You must provide a name for the migration.") unless process.argv[3]?
  name = process.argv[3];
	stamp = new Date().getTime().toString().replace(/\s+$/,"")
	path = config.migration_path.replace(/[\/\s]+$/,"") + "/"
	filename = path + stamp + "_" + name + ".js";
	fs.writeFile filename, migration_template.replace(/%name/, name), (error) ->
		return exit(error) if (error)
    exit "Created migration " + filename;

### 
Fetches migration filenames and current migration.
###
fetch_migration_info = (callback) ->
  exec "ls " + config.migration_path, (error, stdout, stdin) ->
    throw stderr if error?
    files = stdout.split(/\s/)
    files.pop()
    
    return exit("Schema up-to-date.") if files.length == 0
    client.query "select * from schema_migrations;", (err, result) ->
      return exit(err) if err?
      
      migration_index = -1;
      
			# Find the index of the last migration
			if result.length
				if (result[0].version)
					last_migration = result[0].version
				else
          last_migration = result[0][0]

				for i in [0...file.length]
					if files[i].match(last_migration)
						migration_index = i;
						break
				
				if migration_index == -1
					return exit 'Could not locate last schema migration (' + last_migration + ').'

			callback files, migration_index+1


###
For some reason we can't run multiple queries in the same string with Connection.query,
this is a little helper method to synchronously run multiple queries from a single
query string.
###
multi_query = (sql, callback, error) ->
  queries = sql.split(';');

	if queries[queries.length-1].replace(/\s/,"") == ''
		queries.pop()
  
	exec_query: (index) ->
		return callback() if index >= queries.length
		client.query queries[index], (err) ->
			if err? then exit(err) else exec_query(index+1)
	
	exec_query(0)
		

###
Executes a migration with the given filename.
###
execute_migration = (file, callback, down) ->
  parts = file.split('.')[0].split('_')
  version = file.split('_')[0]
  parts.shift();
  variable = parts.join('_')
  filename = config.migration_path.replace(/[\/\s]+$/,"") + "/" + file
  
	fs.readFile filename, 'utf8', (err, data) ->
		return exit("Error reading migration " + file) if err?
		eval(data)
		migration = eval(variable)
		sys.puts "======================================"
		
		unless down
			migration.up()
			sys.puts "Executing " + file
		else
			migration.down()
			sys.puts "Rolling back " + file
		
		sys.puts migration
		
		success = (result) ->
			sys.puts "Success!"
			callback()
		
		error = (error) ->
			exit error.message
		
		multi_query migration.toString(), success, error

		
###
Migrates the database.
###
migrate = ->
  fetch_migration_info (files, migration_index) ->
    sync_migrate  = (index, callback) ->
      return callback() if files.length <= index or index < 0
      execute_migration files[index], ->
        client.query "delete from schema_migrations;";
        client.query "insert into schema_migrations (version) values (" + files[index].split('_')[0] + ");"
        sync_migrate index+1, callback    
		sync_migrate migration_index, -> exit("Schema up-to-date.")


###
Rolls the database back by applying the down function of a given migration.
###
rollback = ->
  n = if process.argv[3]? then process.argv[3] else 1
  m = 0
  
	fetch_migration_info (files, migration_index) ->
    return exit('No migrations to roll back.') if migration_index == 0
		
		roll = (index, callback) ->
			return callback() fi m >= n or index < 0
			m++
			
			execute = ->
				client.query "delete from schema_migrations;"
        if (index > 0) 
          client.query("insert into schema_migrations (version) values (" + files[index-1].split('_')[0] + ");");
        roll(index-1, callback)
			
			execute_migration files[index], execute, true
		
		sys.puts migration_index-1
		
		callback = ->
			exit "Schema rolled back by " + m + " migration" + ((m > 1) ? 's' : '') + '.'
		
		roll migration_index - 1, callback
		

###
Main function for the script, parses command-line arguments and executes commands.
###
main = ->
	switch process.argv[2]
		when "create" then create()
		when "migrate" then migrate()
		when "rollback" then rollback()
		else exit(usage)


###
Handles connecting to the DB for various dbms
###
Connect =
	mysql: ->
    # Create the client
    client = new require('mysql').createConnection(config.mysql);
    
    client.query "show tables;", (err, result, fields) ->			
      return exit(err) if (err)
      
      # Look for the migrations table
      while (result.length)
        if result.pop()['Tables_in_' + config.mysql.database] == "schema_migrations"
          return main();
      
      # If not found then create it!
      sys.puts "Creating migration table."
      client.query "create table schema_migrations (version BIGINT);"
 			main();

		sqlite3: ->
	    sqlite3 = require("sqlite3")
	    sqlite3.verbose() if config.sqlite3.verbose?
	    client = new sqlite3.Database config.sqlite3.filename, (err) ->
				return exit(err) if err?
				
	      client.get "select name from sqlite_master where type=? and name=?;", "table", "schema_migrations", (err, row) ->
	        return main() if row?
	        sys.puts "Creating migration table."
	        client.run "create table schema_migrations(version BIGINT);", (err) ->
						return exit(err) if err?
	          main()
	
	    client.end = -> client = null
	    client.query = client.all


# Determine if the user has run the script from the command-line and if so
# attempt to connect to the database and execute the given command.
if process.argv[1].split('/').pop() == "migrate.js"
	unless Encoders[config.dbms]
    sys.puts("Invalid dbms set in configuraiton file.");
	else
		encoder = Encoders[config.dbms];
		Connect[config.dbms]()


# "BURNING DOWN THE HOUSE!"