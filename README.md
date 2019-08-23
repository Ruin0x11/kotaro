# kotaro
`kotaro` is a Lua library for rewriting Lua source code. Its primary intended use is for applying repetitive source code rewrites which are difficult to accomplish with editor macros, like adding new fields to a list of tables based on the value of one of each table's fields, or moving a table value to a different table in the same parent.

For example, if you have this code:

```lua
return {
   {
      name = "lucia"
   },
   {
      name = "shizuru"
   },
   {
      name = "akane"
   },
}
```

And want to add these table fields to a new field named `quote` on each table based on the value of `name`:

```lua
local quotes = {
   lucia = "「死ね死ね変態変態、不潔不潔不潔！」",
   shizuru = "「むぅ」",
   akane = "「ツチノコは手品」",
}
```

Then you can use this code.

```lua
local Codegen = require("kotaro.parser.codegen")

local quotes = {
   lucia = "「死ね死ね変態変態、不潔不潔不潔！」",
   shizuru = "「むぅ」",
   akane = "「ツチノコは手品」",
}

local add_table_fields = {}

function add_table_fields:new(source_field, target_field, items)
   return setmetatable({source_field = source_field, target_field = target_field, items = items}, {__index = add_table_fields})
end
function add_table_fields:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   -- index into the AST node as if it were a table.
   -- equivalent to `tbl[self.source_field]`
   local target = node:index(self.source_field)
   if not target or target:type() ~= "expression" then
      return false
   end

   -- convert the expression AST to an actual Lua value.
   local value = target:evaluate()

   return self.items[value] ~= nil
end
function add_table_fields:execute(node)
   local id = node:index(self.source_field):evaluate()
   local value = self.items[id]

   -- create a new AST node from scratch representing an expression
   -- resolving to the actual Lua value `value`.
   local expr = Codegen.gen_expression(value)

   -- equivalent to `tbl[self.target_field] = value`
   node:modify_index(self.target_field, value)

   -- mark the contents of this node as changed, which will re-run
   -- important AST analysis passes like parenting and line numbering.
   node:changed()
end

local rewrite = {
    -- these parameters are passed on the command line or from a
    -- compatible editor.
    params = {
        source_field = "string",
        target_field = "string",
    }
}

function rewrite:execute(ast, params, opts)
   return ast:rewrite(add_table_fields:new(params.source_field, params.target_field, quotes))
end

return rewrite
```

The above is a "rewrite file" for use in `kotaro`'s batch mode. You can run this rewrite from the command line like this:

```bash
kotaro rewrite example/add_table_fields.lua example/source.lua -p source_field=name -p target_field=quote
```

The resulting code will be printed to standard output.

```lua
return {
   {
      name = "lucia",
      quote = "「死ね死ね変態変態、不潔不潔不潔！」"
   },
   {
      name = "shizuru",
      quote = "「むぅ」"
   },
   {
      name = "akane",
      quote = "「ツチノコは手品」"
   },
}
```

You can also use `kotaro` from an editor by passing `-fedit_list`.

```bash
kotaro rewrite example/add_table_fields.lua example/source.lua -p source_field=name -p target_field=quote -fedit_list
example/source.lua:35:0:,\n      quote = "「死ね死ね変態変態、不潔不潔不潔！」"
example/source.lua:69:0:,\n      quote = "「むぅ」"
example/source.lua:100:0:",\n      quote = "「ツチノコは手品」
```

This will print out a list of edits with format `file:offset:length` to transform the old source into the new source, for each file edited. An example Emacs integration is included which allows the user to interactively confirm the edits in each file.

## Design
`kotaro` parses Lua source into a custom AST format which will preserve whitespace and the exact contents of all keywords/symbols, similar to `lib2to3`'s parse tree. General inspiration came from the [yapf](https://github.com/google/yapf) Python formatter, which uses `lib2to3` itself. AST manipulation is performed by calling methods on each AST node's metatable and using `kotaro.parser.codegen` to create new AST nodes, which will create the necessary symbols needed for the resulting node to be syntactically valid.

## Note
The code is completely alpha-quality. It works well enough for my needs, but it will break if the AST gets into an inconsistent state. Also, the generated code needs to be reformatted manually.

## Wishlist
- A source code formatter similar in design to `yapf`.
- File-local scope analysis, to do things like "extract function from block" or "introduce new scope".
- Scope analysis across multiple files, to determine targets for a "rename function" rewrite.
- More useful rewrites, like "move file and update `require` statements" or "extract block/expression to function".
