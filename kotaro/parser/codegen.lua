local NodeTypes = require("kotaro.parser.node_types")
local cst_parser = require("kotaro.parser.cst_parser")
local lexer = require("kotaro.parser.lexer")
local utils = require("kotaro.utils")

local Codegen = {}

function Codegen.make_prefix(s)
   return s
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

function Codegen.gen_ident(str)
   if not utils.is_valid_lua_ident(str) then
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

function Codegen.string_to_leaf(str)
   local ok, tok = pcall(function() return Codegen.lex_one_token(str) end)
   if not ok then
      -- wrap as string
      str = string.format("\"%s\"", str)
      ok, tok = pcall(function() return Codegen.lex_one_token(str) end)
   end
   if not ok then
      error(string.format("Source string '%s' does not form a valid Lua string or identifier. Error message:\n    %s", str, tok))
   end

   return tok
end

function Codegen.gen_leaf(value)
   local leaf
   local _type = type(value)

   if _type == "number" then
      if value < 0 then
         error(string.format("Numeric leaf values cannot be negative, since they count as an expression. (got: %s)", value))
      end
      leaf = NodeTypes.leaf("Number", tostring(value))
   elseif _type == "string" then
      leaf = Codegen.string_to_leaf(value)
   elseif _type == "boolean" then
      leaf = NodeTypes.leaf("Boolean", tostring(value))
   elseif _type == "nil" then
      leaf = NodeTypes.leaf("Nil", tostring(value))
   else
      error(string.format("Cannot convert %s to a leaf", value))
   end

   return leaf
end

function Codegen.gen_expression(value)
   local ops = {}
   local _type = type(value)

   if _type == "table" then
      if value[1] == "expression" then
         return value
      elseif value.leaf_type == "Ident" then
         return Codegen.convert_leaf_to_expression(value)
      elseif value.clone then
         return NodeTypes.expression({value})
      else
         -- HACK
         return Codegen.gen_constructor_expression(value)
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
      local tok = Codegen.string_to_leaf(value)

      ops = { NodeTypes.suffixed_expression({tok}) }
   elseif _type == "boolean" then
      ops = { NodeTypes.leaf("Boolean", tostring(value)) }
   elseif _type == "nil" then
      ops = { NodeTypes.leaf("Nil", tostring(value)) }
   else
      error(string.format("Cannot convert %s to an expression", value))
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

   if utils.is_valid_lua_ident(key) then
      key_expr = Codegen.gen_leaf(key)
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

function Codegen.gen_constructor_expression(exprs)
   local l_lparen = Codegen.gen_symbol("{")
   local l_rparen = Codegen.gen_symbol("}")
   local p = NodeTypes.constructor_expression(l_lparen, {}, l_rparen)

   for i=1,#exprs do
      local expr = exprs[i]
      if type(expr) ~= "table" or not expr.clone then
         exprs[i] = Codegen.gen_expression(expr)
      end
   end

   local prefix = "\n   "
   if #exprs > 0 then
      prefix = prefix .. exprs[1]:calc_indent()
   end

   p:set_prefix(prefix)

   for i, v in ipairs(exprs) do
      p:insert_node(v)
      if i == 1 then
         v:set_prefix(prefix)
      else
         v:set_prefix(prefix)
      end
   end

   p[#p]:set_prefix(prefix)

   p:changed()

   return p
end

return Codegen
