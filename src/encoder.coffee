Module = (fn) -> fn()

###
Translates migrations into valid MySQL.
###
exports.mysql = Module ->
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
exports.sqlite3 = Module ->
  # Mapping of abstract migrate types to concrete SQLite 3 types
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
			
