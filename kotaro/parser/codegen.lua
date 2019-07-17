local NodeTypes = require("kotaro.parser.node_types")
local cst_parser = require("kotaro.parser.cst_parser")
local lexer = require("kotaro.parser.lexer")

local Codegen = {}

function Codegen.make_prefix(s)
   local leading = {}
   for i=1,#s do
      table.insert(leading, { Type = "Whitespace", Line = nil, Char = nil, Data = string.sub(s, i, i)})
   end
   return leading
end

function Codegen.lex_one_token(src)
   local l = lexer(src)
   return l:emit()
end

function Codegen.gen_symbol(value)
   return NodeTypes.leaf("Symbol", value, Codegen.make_prefix(""), -1, -1)
end

function Codegen.gen_keyword(value)
   return NodeTypes.leaf("Keyword", value, Codegen.make_prefix(""), -1, -1)
end

local function is_valid_lua_ident(str)
   return type(str) == "string" and string.match(str, "^[_%a][_%w]*$")
end

function Codegen.gen_ident(str)
   if not is_valid_lua_ident(str) then
      error(string.format("'%s' is not a valid Lua identifier", tostring(str)))
   end

   return NodeTypes.leaf("Ident", str, Codegen.make_prefix(""), -1, -1)
end

function Codegen.gen_string(value)
   return NodeTypes.leaf("String", string.format("\"%s\"", value), Codegen.make_prefix(""), -1, -1)
end

function Codegen.convert_leaf_to_expression(ident)
   if type(ident) == "string" then
      ident = Codegen.gen_ident(ident)
   end
   assert(ident.leaf_type == "Ident")
   return NodeTypes.expression({NodeTypes.suffixed_expression({ident})})
end

function Codegen.gen_expression_from_code(code)
   local a, new = cst_parser(code):parse_expression()
   assert(a, new)

   return new
end

function Codegen.gen_expression(value)
   local ops = {}
   local _type = type(value)

   if _type == "table" then
      if value[1] == "expression" then
         return value
      elseif value.leaf_type == "Ident" then
         return Codegen.convert_leaf_to_expression(value)
      else
         -- HACK
         local inspect = require("inspect")
         return Codegen.gen_expression_from_code(inspect(value))
      end
   end

   if _type == "number" then
      local leaf = NodeTypes.leaf("Number", tostring(value))
      if value < 0 then
         ops = { NodeTypes.leaf("Symbol", "-"), leaf }
      else
         ops = { leaf }
      end
   elseif _type == "string" then
      -- this handles the case of idents ("string") and strings ("\"string\"")
      local ok, tok = pcall(function() return Codegen.lex_one_token(value) end)
      if not ok then
         error(string.format("source string '%s' does not form a valid Lua string or identifier. Error message:\n    %s", value, tok))
      end

      ops = { NodeTypes.suffixed_expression({tok}) }
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

function Codegen.gen_key_value_pair(key, value)
   if not value then
      -- array syntax, which omits key
      local actual_value = key

      local expr
      if type(actual_value) == "table" and actual_value[1] == "expression" then
         expr = actual_value
      else
         expr = Codegen.gen_expression(actual_value)
      end

      return expr
   end

   local key_expr

   if is_valid_lua_ident(key) then
      key_expr = Codegen.convert_leaf_to_expression(key)
   else
      local expr = Codegen.gen_expression(key)
      key_expr = NodeTypes.constructor_key(Codegen.gen_symbol("["), expr, Codegen.gen_symbol("]"))
   end

   local value_expr = Codegen.gen_expression(value)
   value_expr:set_prefix(" ")

   return NodeTypes.key_value_pair(key_expr, Codegen.gen_symbol("="):set_prefix(" "), value_expr)
end

function Codegen.gen_parenthesized_expression(expr)
   local l_lparen = Codegen.gen_symbol("(")
   local l_rparen = Codegen.gen_symbol(")")
   local p = NodeTypes.parenthesized_expression(l_lparen, expr, l_rparen)

   p:set_prefix(expr:prefix_to_string() or "")
   expr:set_prefix("")

   return p
end

return Codegen
