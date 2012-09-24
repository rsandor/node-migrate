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


sys = require 'util'
{exec} = require 'child_process'
fs = require 'fs'
config = require './config'


{ Migration } = require './rules'
Encoders = require './encoders'


[encoder, mysql, client] = [null, null, null]

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
		migration.setEncoder encoder
		
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