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

merge = (base, ext) ->
	rv = {}
	for k, v of base
		rv[k] = if ext[k]? then ext[k] else base[k]
	rv
	
valid_type = (type) -> DATA_TYPES.indexOf(type) >= 0

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

	setEncoder: (@encoder) ->

	reset: ->
		@sql = ''

	encode: (rule) ->
		@sql += encoding if (encoding = @encoder.encode rule)?

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

exports.Migration = Migration

