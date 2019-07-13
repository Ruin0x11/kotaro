local NodeTypes = require("yalf.parser.node_types")
local cst_parser = require("yalf.parser.cst_parser")

local Codegen = {}

function Codegen.make_prefix(s)
   local leading = {}
   for i=1,#s do

      table.insert(leading, { Type = "Whitespace", Line = nil, Char = nil, Data = string.sub(s, i, i)})
   end
   return leading
end

function Codegen.gen_symbol(value)
   return NodeTypes.leaf("Symbol", value, Codegen.make_prefix(""), -1, -1)
end

function Codegen.gen_keyword(value)
   return NodeTypes.leaf("Keyword", value, Codegen.make_prefix(""), -1, -1)
end

local function is_valid_lua_ident(str)
   return type(str) == "string" and string.match(str, "[_%a][_%w]*")
end

function Codegen.gen_ident(str)
   if not is_valid_lua_ident(str) then
      error(string.format("'%s' is not a valid Lua identifier", tostring(str)))
   end

   return NodeTypes.leaf("Ident", str, Codegen.make_prefix(""), -1, -1)
end

function Codegen.gen_expression(expr)
   local a, new = cst_parser(expr):parse_expression()
   assert(a, new)

   return new
end

function Codegen.gen_expression_from_value(value)
   local ops = {}
   local _type = type(value)
   if _type == "number" then
      local leaf = NodeTypes.leaf("Number", tostring(value))
      if value < 0 then
         ops = { NodeTypes.leaf("Symbol", "-"), leaf }
      else
         ops = { leaf }
      end
   elseif _type == "string" then
      ops = { NodeTypes.leaf("String", value) }
   elseif _type == "boolean" then
      ops = { NodeTypes.leaf("Keyword", tostring(value)) }
   end

   if #ops == 0 then
      return nil
   end

   return NodeTypes.expression(ops)
end

function Codegen.gen_statement(stmt)
   local a, new = cst_parser(stmt):parse_statement()
   assert(a, new)

   return new
end

function Codegen.gen_function_ident(name, declarer, method)
   local full = name

   if declarer then
      if method then
         full = declarer .. ":" .. name
      else
         full = declarer .. "." .. name
      end
   end

   local ok, new = cst_parser(full):parse_suffixed_expression("dots_and_colon")
   assert(ok, new)
   return new
end


function Codegen.gen_ident_list(...)
   local list = {}

   for _, str in ipairs({...}) do
      if #list == 0 then
         list[#list+1] = Codegen.gen_ident(str)
      else
         list[#list+1] = Codegen.gen_symbol(","):set_prefix(" ")
         list[#list+1] = Codegen.gen_ident(str)
      end
   end

   return list
end

function Codegen.gen_expression_list(...)
   local list = {}

   for _, obj in ipairs({...}) do
      local ok, expr

      if type(obj) == "string" then
         ok, expr = Codegen.gen_expression(obj)
         assert(ok)
      elseif type(obj) == "table" and obj[1] == "expression" then
         expr = obj
      else
         error(string.format("invalid expression '%s'", tostring(obj)))
      end

      if #list == 0 then
         list[#list+1] = expr
      else
         list[#list+1] = Codegen.gen_symbol(","):set_prefix(" ")
         list[#list+1] = expr
      end
   end

   return list
end

return Codegen
