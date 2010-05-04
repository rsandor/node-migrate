/*
 * migrate.js - A database agnostic migration module for Node.js.
 * Copyright (c) 2010 Ryan Sandor Richards
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
 */

/**
 * Supported Data-types
 */ 
var DATA_TYPES = [
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

// Handy options merging function
function merge(base, ext) {
  var rv = {};
  for (var k in base) {
    rv[k] = ext[k] ? ext[k] : base[k];
  }
  return rv;
}

// Determines if a given type is valid
function valid_type(type) {
  for (var i = 0; i < DATA_TYPES.length; i++)
    if (type == DATA_TYPES[i])
      return true;
  return false;
}

/**
 * Create table rule representation.
 */
function CreateTable(name) {
  this.name = name;
  this.columns = [];
  this.indices = [];
  this.primary_key_name = null;

  // Adds a column to the table
  this.column = function() {
    var column = {
      name: null,
      type: null,
      limit: null,
      not_null: null,
      precision: null,
      scale: null,
      default_value: null
    };
    
    if (arguments.length < 1)
      return;
    
    if (typeof arguments[0] == "string") {
      if (arguments.length < 2)
        return;
      
      column.name = arguments[0];
      column.type = arguments[1];
      
      if (arguments[2] && typeof(arguments[2]) == "object")
        column = merge(column, arguments[2]);
    }
    else if (typeof arguments[0] == 'object') {
      column = merge(column, arguments[0]);
      if (!column.name || !column.type)
        return;
    }
    else {
      return;
    }
    
    if (!valid_type(column.type))
      return;
      
    this.columns.push(column);
  }

  // Sets the primary key for the table.
  this.primary_key = function(name) {
    if (!name)
      return;
    this.primary_key_name = name;
  }

  // Adds an index to the table.
  this.index = function(name, options) {
    if (!name)
      return;
    this.indices.push(name);
  }

  // Create the typed helper functions for quickly creating columns of
  // any given type (string, text, integer, etc.)
  for (var i = 0; i < DATA_TYPES.length; i++) {
    this[DATA_TYPES[i]] = function(type) {
      return function() {
        var column = {};
        if (arguments.length < 1)
          return;
        if (typeof arguments[0] == "string") {
          column.name = arguments[0];
          if (arguments[1] && typeof arguments[1] == "object") {
            for (var k in arguments[1])
              column[k] = arguments[1][k];
          }
        }
        else if (typeof arguments[0] == "object")
          column = arguments[0];
        else
          return;
        column.type = type;
        this.column(column);
      };
    }(DATA_TYPES[i]);
  }
}

/**
 * Drop table representation.
 */
function DropTable(name) {
  this.name = name;
}

/**
 * Rename table representation.
 */
function RenameTable(old_name, new_name) {
  this.old_name = old_name;
  this.new_name = new_name;
}
 
/**
 * Change/Modify Table Representation.
 */
function ChangeTable(name) {
  CreateTable.call(this, name);
  
  this.remove_columns = [];
  this.change_columns = [];
  this.remove_indices = [];
  this.rename_columns = {};
  this.remove_key = false;
  
  /**
   * Alters a column and renames it.
   */
  this.rename = function(old_name, new_column) {
    this.column(new_column);
    this.rename_columns[old_name] = this.columns.pop();
  }
  
  /**
   * Changes the definition of a column.
   */
  this.change = function() {
    this.column.apply(this, arguments);
    this.change_columns.push(this.columns.pop());
  }
  
  /**
   * Removes a column from the table.
   */
  this.remove = function(name) {
    this.remove_columns.push(name);
  }
  
  /**
   * Removes an index from the table.
   */
  this.remove_index = function(name) {
    this.remove_indices.push(name);
  }
  
  /**
   * Removes the primary key from this table.
   */
  this.remove_primary_key = function() {
    this.remove_key = true;
  }
}
ChangeTable.prototype = new CreateTable();

/**
 * Add Column Representation.
 */
function AddColumn(table_name, column_name, type, options) {
  this.table_name = table_name;
  this.name = column_name;
  this.type = type;
  if (options)
    for (var k in options)
      this[k] = options[k];
}

/**
 * Rename Column Representation.
 */
function RenameColumn(table_name, column_name, new_column) {  
  this.table_name = table_name;
  this.name = column_name;
  this.new_name = new_column.name;

  delete new_column.name;
  for (var k in new_column)
    this[k] = new_column[k];
}

/**
 * Change column representation.
 */
function ChangeColumn(table_name, column_name, type, options) {  
  this.table_name = table_name;
  this.name = column_name;
  this.type = type;
  if (options && typeof options == "object")
    for (var k in options)
      this[k] = options[k];
}

/**
 * Remove Column Represenatation.
 */
function RemoveColumn(table_name, column_name) {
  this.table_name = table_name;
  this.name = column_name;
}

/**
 * Add Index Represenatation.
 */
function AddIndex(table_name, index_name, options) {
  this.table_name = table_name;
  this.name = index_name;
  if (options && typeof options == "object")
    for (var k in options)
      this[k] = options[k];
}

/**
 * Remove Index Represenatation.
 */
function RemoveIndex(table_name, index_name) {
  this.table_name = table_name;
  this.name = index_name;
}

/**
 * Migration object.
 */
function Migration(opts) {
  var sql;
    
  // Encodes an object and appends it to the migrations SQL representation.
  function encode(o) {
    sql += encoder.encode(o)
  }
  
  function reset() {
    sql = "";
  }
  
  this.create_table = function(name, body) {
    var rule = new CreateTable(name);
    if (body && typeof(body) == 'function') 
      body(rule);
    encode(rule);
  }

  this.drop_table = function(name) {
    encode(new DropTable(name));
  }
  
  this.change_table = function(name, body) {
    var rule = new ChangeTable(name);
    if (body && typeof body == "function")
      body(rule);
    encode(rule);
  }
  
  this.rename_table = function(old_name, new_name) {
    encode(new RenameTable(old_name, new_name));
  }
  
  this.add_column = function(table_name, column_name, type, options) {
    encode(new AddColumn(table_name, column_name, type, options));
  }

  this.rename_column = function(table_name, column_name, new_column) {
    encode(new RenameColumn(table_name, column_name, new_column));
  }
  
  this.change_column = function(table_name, column_name, type, options) {
    encode(new ChangeColumn(table_name, column_name, type, options));
  }

  this.remove_column = function(table_name, column_name) {
    encode(new RemoveColumn(table_name, column_name));
  }

  this.add_index = function(table_name, column_name, options) {
    encode(new AddIndex(table_name, column_name, options));
  }
  
  this.remove_index = function(table_name, index_name) {
    encode(new RemoveIndex(table_name, index_name));
  }

  /**
   * Adds user-defined SQL to the migration.
   */
  this.execute = function(s) {
    sql += s;
  }

  /**
   * Converts the migration into SQL.
   */
  this.toString = function() {
    return sql;
  }

  // Migration construction or "up" method
  this.up = function() {
    reset();
    if (opts.up)
      opts.up.apply(this);
  }

  // Migration destruction or "down" method
  this.down = function() {
    reset();
    if (opts.down)
      opts.down.apply(this);
  }
}

/**
 * Holds the SQL encoders.
 */
var Encoders = {};

/**
 * Translates migrations into valid MySQL.
 */
Encoders['mysql'] = function() {
  // Mapping of abstract migrate types to concrete MySQL types
  var types = {
    'integer': 'INT',
    'string': 'VARCHAR',
    'text': 'TEXT',
    'float': 'FLOAT',
    'decimal': 'DECIMAL',
    'datetime': 'DATETIME',
    'timestamp': 'TIMESTAMP',
    'time': 'TIME',
    'date': 'DATE',
    'binary': 'VARBINARY',
    'boolean': 'TINYINT'
  }
   
  // Intensely helpful function for creating a MySQL type from a column object.
  function parse_type(column) {
    // type, limit, precision, scale
    var type = null;
    
    if (column.type == 'integer') {
      if (column.limit == 1)
        type = "TINYINT";
      else if (column.limit == 2)
        type = "SMALLINT";
      else if (column.limit == 3)
        type = "MEDIUMINT";
      else if (column.limit == 8)
        type = "BIGINT";
      else
        type = "INT";
    }
    else if (column.type == 'string' || column.type == 'binary') {
      type = types[column.type];
      if (column.limit)
        type += "(" + column.limit + ")";
      else
        type += '(255)';
    }
    else if (column.type == 'decimal') {
      type = types[column.type];
      if (column.precision && column.scale) {
        type += "(" + column.precision + "," + column.scale + ")";
      }
      else if (column.precision) {
        type += "(" + column.precision + ")";
      }
    }
    else 
      type = types[column.type];
    
    if (column.not_null)
      type += ' NOT NULL';
    
    if (column.default_value) {
      type += ' DEFAULT ';
      if (column.type == 'string' || column.type == 'text')
        type += "'" + column.default_value + "'";
      else
        type += column.default_value;
    }
    
    return type;
  }
  
  /*
   * The following functions do the the actual work of generating the SQL for the encode function.
   */
  function create_table(table) {
    var sql = "CREATE TABLE " + table.name;
    var defs = [];
    
    for (var i=0; i < table.columns.length; i++)
      defs.push("\t" + table.columns[i].name + " " + parse_type(table.columns[i]));

    for (var i=0; i < table.indices.length; i++)
      defs.push("\tADD INDEX (" + table.indices[i] + ")");
    
    if (table.primary_key_name)
      defs.push("\tPRIMARY KEY (" + table.primary_key_name + ")");

    if (defs.length)
      sql += " (\n" + defs.join(",\n") + "\n)";
    
    return sql + ";\n";
  }
  
  function drop_table(table) {
    return "DROP TABLE " + table.name + ";\n";
  }
  
  function rename_table(table) {
    return "RENAME TABLE " + table.old_name + " TO " + table.new_name + ";\n";
  }
  
  function change_table(table) {
    var sql = "ALTER TABLE " + table.name;
    var defs = [];
    
    for (var i=0; i < table.columns.length; i++)
      defs.push("\tADD COLUMN " + table.columns[i].name + " " + parse_type(table.columns[i]));
    
    for (var i=0; i < table.indices.length; i++)
      defs.push("\tADD INDEX(" + table.indices[i] + ")");

    if (table.primary_key_name)
      defs.push("\tADD PRIMARY KEY(" + table.primary_key_name + ")");

    for (var i=0; i < table.remove_columns.length; i++)
      defs.push("\tDROP COLUMN " + table.remove_columns[i]);
    
    if (table.remove_key)
      defs.push("\tDROP PRIMARY KEY");
    
    for (var i=0; i < table.remove_indices.length; i++)
      defs.push("\tDROP INDEX " + table.remove_indices[i]);

    for (var i=0; i < table.change_columns.length; i++)
      defs.push("\tMODIFY COLUMN " + table.change_columns[i].name + " " + parse_type(table.change_columns[i]));
      
    for (var name in table.rename_columns) {
      var col = table.rename_columns[name];
      defs.push("\tCHANGE COLUMN " + name + " " + col.name + " " + parse_type(col));
    }

    if (defs.length)
      sql += "\n" + defs.join(",\n");
      
    return sql + ";\n";
  }
  
  function add_column(column) {
    return "ALTER TABLE " + column.table_name + " ADD COLUMN " + 
      column.name + " " + parse_type(column) + ";\n";
  }
  
  function rename_column(column) {
    return "ALTER TABLE " + column.table_name + " CHANGE COLUMN " + 
      column.name + " " + column.new_name + " " + parse_type(column) + ";\n";
  }
  
  function change_column(column) {
    return "ALTER TABLE " + column.table_name + " MODIFY COLUMN " + 
      column.name + " " + parse_type(column) + ";\n";
  }
  
  function remove_column(column) {
    return "ALTER TABLE " + column.table_name + " DROP COLUMN " + column.name + ";\n";
  }
  
  function add_index(index) {
    return "ALTER TABLE " + index.table_name + " ADD INDEX (" + index.name + ");\n";
  }
  
  function remove_index(index) {
    return "ALTER TABLE " + index.table_name + " DROP INDEX (" + index.name + ");\n";
  }
  
  return {
    encode: function(o) {
      if (o instanceof ChangeTable)
        return change_table(o);
      else if (o instanceof CreateTable)
        return create_table(o);
      else if (o instanceof DropTable)
        return drop_table(o);
      else if (o instanceof RenameTable)
        return rename_table(o);
      else if (o instanceof AddColumn)
        return add_column(o);
      else if (o instanceof RenameColumn)
        return rename_column(o);
      else if (o instanceof ChangeColumn)
        return change_column(o);
      else if (o instanceof RemoveColumn)
        return remove_column(o);
      else if (o instanceof AddIndex)
        return add_index(o);
      else if (o instanceof RemoveIndex)
        return remove_index(o);
      else
        throw "Error: MySQL Encoder Encountered Unknown Rule Type.";
    }
  }
}();

// The real "beef" is here, this section handles the command-line usage of the module.
var sys = require('sys'),
  exec = require('child_process').exec,
  fs = require('fs'),
  config = require('./config');
var encoder, mysql, conn;  

var usage = "migrate.js usage:\n" +
  "\tnode migrate.js create <name> - Create a new migration with the given name\n" +
  "\tnode migrate.js migrate - Run pending migrations\n" +
  "\tnode migrate.js rollback [n] - Roll back by a number of migrations.";

var migration_template = "var %name = new Migration({\n" +
  "  up: function() {\n" +
  "  },\n" + 
  "  down: function() {\n" +
  "  }\n" + 
  "});"

/**
 * Gracefully exits the script and closes any open DB connections.
 */
function exit(msg) {
  if (msg)
    sys.puts(msg);
  if (conn)
    conn.close();
}

/**
 * Creates a new migration.
 */
function create() {
  if (!process.argv[3])
    exit("You must provide a name for the migration.");
  var name = process.argv[3];
  exec("date +%Y%m%d%H%M%S", function(error, stdout, stderr) {
    if (error) throw stderr;
    var filename = config.migration_path.replace(/[\/\s]+$/,"") + "/" + 
      stdout.replace(/\s+$/,"") + "_" + name + ".js";
    fs.writeFile(filename, migration_template.replace(/%name/,name), function(error) {
      if (error) exit(error);
      exit("Created migration " + filename);
    });
  });
}

/** 
 * Fetches migration filenames and current migration.
 */
function fetch_migration_info(callback) {
  exec("ls " + config.migration_path, function(error, stdout, stderr) {
    if (error) throw stderr;
    var files = stdout.split(/\s/);
    files.pop();
    
    if (files.length == 0) {
      return exit("Schema up-to-date.");
    }
    
    conn.query(
      "select * from schema_migrations;", 
      function(result) {
        var migration_index = -1;
        // Find the index of the last migration
        if (result.records.length > 0) {
          migration_index = -1;
          var last_migration = result.records[0][0];
          for (var i = 0; i < files.length; i++) {
            if (files[i].match(last_migration)) {
              migration_index = i;
              break;
            }
          }
          if (migration_index == -1) {
            return exit('Could not locate last schema migration (' + last_migration + ').');
          }
        } 
        callback(files, migration_index+1);
      },
      function(error) {
        return exit(error.message);
      }
    );
  });
}

/**
 * For some reason we can't run multiple queries in the same string with Connection.query,
 * this is a little helper method to synchronously run multiple queries from a single
 * query string.
 */
function multi_query(sql, callback, error) {
  var queries = sql.split(';');
  if (queries[queries.length-1].replace(/\s/,"") == '')
    queries.pop();
    
  function exec_query(index) {
    if (index >= queries.length) {
      callback();
      return;
    }
    conn.query(
      queries[index], 
      function(response) {
        exec_query(index+1);
      },
      function(err) {
        error(err);
      }
    );
  };
  exec_query(0);
}

/**
 * Executes a migration with the given filename.
 */
function execute_migration(file, callback, down) {
  var parts = file.split('.')[0].split('_');
  var version = file.split('_')[0];
  parts.shift();
  var variable = parts.join('_');
  var filename = config.migration_path.replace(/[\/\s]+$/,"") + "/" + file;
  
  fs.readFile(filename, function(err, data) {
    if (err) return exit("Error reading migration " + file);
    eval(data);
    var migration = eval(variable);
    
    sys.puts("======================================")
    
    if (!down) {
      migration.up();
      sys.puts("Executing " + file);
    }
    else {
      migration.down();
      sys.puts("Rolling back " + file);
    }
  
    sys.puts(migration);
    
    multi_query(
      migration.toString(), 
      function(result) {
        sys.puts("Success!");
        callback();
      },
      function(error) {
        exit(error.message);
      }
    );
  });
}

/**
 * Migrates the database.
 */
function migrate() {
  fetch_migration_info(function(files, migration_index) {
    function sync_migrate(index, callback) {
      if (files.length <= index || index < 0) {
        callback();
        return;
      }
      execute_migration(files[index], function() { 
        conn.query("delete from schema_migrations;");
        conn.query("insert into schema_migrations (version) values (" + files[index].split('_')[0] + ");");
        sync_migrate(index+1, callback); 
      });
    }
    
    sync_migrate(migration_index, function() {
      exit("Schema up-to-date.");
    });
  });
}

/**
 * Rolls the database back by applying the down function of a given migration.
 */
function rollback() {
  var n = (process.argv[3]) ? process.argv[3] : 1;
  var m = 0;
  
  fetch_migration_info(function(files, migration_index) {
    if (migration_index == 0)
      return exit('No migrations to roll back.');
    
    function roll(index, callback) {
      if (m >= n || index < 0)
        return callback();
      m++;
      execute_migration(files[index], function() {
        conn.query("delete from schema_migrations;");
        if (index > 0) 
          conn.query("insert into schema_migrations (version) values (" + files[index-1].split('_')[0] + ");");
        roll(index-1, callback); 
      }, true);
    }
    
    sys.puts(migration_index-1);
    
    roll(migration_index-1, function() {
      exit("Schema rolled back by " + m + " migration" + ((m > 1) ? 's' : '') + '.');
    });
  });
}

/**
 * Main function for the script, parses command-line arguments and executes commands.
 */
function main() {
  var command = process.argv[2];
  if (command == "create")
    create();
  else if (command == "migrate") 
    migrate();
  else if (command == "rollback") 
    rollback();
  else
    exit(usage);
}
 
/**
 * Checks provided DBMS driver paths. Returns the modified path if it is possible to derive the
 * correct path from what was given.
 */
function check_path(path, tail) {
  // Paths cannot be empty and must start with ./
  if (!path || !path.match(/^\.\/.*/))
    return false;

  // Trim trailing .js
  path = path.replace(/\.js\s*/, '');
  
  // Trim trailing slash
  path = path.replace(/\/+\s*$/, '');
  
  // Determine if we match on the tail, if not append the tail
  if (!path.match(tail+'$')) {
    path += '/' + tail;
  }

  // Detemine if the path resolves
  try {
    return fs.realpathSync(path);
  }
  catch(e) {
    return false;
  }
  
  return true;
}
 
// Determine if the user has run the script from the command-line and if so
// attempt to connect to the database and execute the given command.
if (process.argv[1].split('/').pop() == "migrate.js") {
  if (!Encoders[config.dbms])
    sys.puts("Invalid dbms set in configuraiton file.");
  encoder = Encoders[config.dbms];

  // Attempt to connect to the DB
  if (config.dbms == 'mysql') {
    var node_mysql_path = check_path(config.node_mysql_path, 'mysql');
    
    if (!node_mysql_path) {
      sys.puts("Invalid node-mysql path provided, please set node_mysql_path in config.js.");
      return;
    }
    
    mysql = require(node_mysql_path);
    conn = new mysql.Connection(
      config.host_name,
      config.user_name,
      config.password,
      config.db_name,
      config.port);  
    conn.connect(
      function() {
        // Check for migrations table
        conn.query("show tables;", function(result) {
          var found = false;
          for (var i = 0; i < result.records.length; i++) {
            if (result.records[i][0] == "schema_migrations") {
              found = true;
              break;
            }
          }
          if (!found) {
            sys.puts("Creating migration table.");
            conn.query("create table schema_migrations (version BIGINT);",
              function(result) {
                main();
              },
              function(error) {
                sys.puts('An error occured while creating he migration table.');
                sys.puts(error.message);
                conn.close();
              }
            );
          }
          else
            main();
        },
        function (error) {
          sys.puts('An error occurred while attempting to check for the migration table.');
          sys.puts(error.message);
          conn.close();
        });
      }, 
      function(error) {
        sys.puts("Error connecting to the database: " + error.message);
      }
    );
  }
}

// "BURNING DOWN THE HOUSE!"