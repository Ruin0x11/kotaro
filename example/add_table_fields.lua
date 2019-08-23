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
