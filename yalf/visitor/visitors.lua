local utils = require("yalf.utils")

-- from inspect.lua
local function smart_quote(str)
  if str:match('"') and not str:match("'") then
    return "'" .. str .. "'"
  end
  return '"' .. str:gsub('"', '\\"') .. '"'
end

local short_control_char_escapes = {
  ["\a"] = "\\a",  ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n",
  ["\r"] = "\\r",  ["\t"] = "\\t", ["\v"] = "\\v"
}
local long_control_char_escapes = {} -- \a => nil, \0 => \000, 31 => \031
for i=0, 31 do
  local ch = string.char(i)
  if not short_control_char_escapes[ch] then
    short_control_char_escapes[ch] = "\\"..i
    long_control_char_escapes[ch]  = string.format("\\%03d", i)
  end
end

local function escape(str)
  return (str:gsub("\\", "\\\\")
             :gsub("(%c)%f[0-9]", long_control_char_escapes)
             :gsub("%c", short_control_char_escapes))
end

local function dump_node(node)
   if node:type() == "leaf" then
      return string.format("%s(%s) [line=%d, column=%d, prefix='%s']",
                           string.upper(node.leaf_type), smart_quote(tostring(node.value)), node.line, node.column, escape(node:prefix_to_string()))
   else
      return string.format("%s [%d children]",
                           node[1], #node-1)
   end
end


function table.keys(tbl)
   local arr = {}
   for k, _ in pairs(tbl) do
      arr[#arr+1] = k
   end
   return arr
end

local visitor = {}

function visitor.visit_node(v, node, visit)
   for _, child in node:iter_rest() do
      local r = visitor.visit(v, child)
      if r then return r end
   end
end

function visitor.visit(v, node)
   local r

   if node[1] == "leaf" then
      r = v:visit_leaf(node)
   elseif type(node[1]) == "string" then
      r = v:visit_node(node, visitor.visit_node)
   else
      error("invalid node ".. require"inspect"(node))
   end

   if r then
      return r
   end
end

local print_visitor = {}

function print_visitor:new(stream)
   local o = setmetatable({}, { __index = print_visitor })
   o.stream = stream or { stream = io, write = function(t, ...) t.stream.write(...) end }
   o.indent = 0
   return o
end

function print_visitor:print_node(node)
   self.stream:write(string.format("%s%s\n", string.rep(' ', self.indent), dump_node(node)))
end

function print_visitor:visit_node(node, visit)
   self:print_node(node)
   self.indent = self.indent + 2
   visit(self, node, visit)
   self.indent = self.indent - 2
end

function print_visitor:visit_leaf(leaf)
   self:print_node(leaf)
end

local refactoring_visitor = {}

function refactoring_visitor:new(refactorings)
   local o = setmetatable({}, { __index = refactoring_visitor })
   o.refactorings = refactorings
   self.is_preorder = self.order == "preorder"
   return o
end

function refactoring_visitor:visit_leaf(node)
   for _, v in ipairs(self.refactorings) do
      if v:applies_to(node) then
         v:execute(node)
      end
   end
end

function refactoring_visitor:visit_node(node, visit)
   if self.is_preorder then
      visit(self, node, visit)
   end

   for _, v in ipairs(self.refactorings) do
      if v:applies_to(node) then
         v:execute(node)
      end
   end

   if not self.is_preorder then
      visit(self, node, visit)
   end
end

local parenting_visitor = {}

function parenting_visitor:new()
   return setmetatable({}, { __index = parenting_visitor })
end

function parenting_visitor:visit_leaf(node)
   node.parent = self.current_parent
end

function parenting_visitor:visit_node(node, visit)
   node.parent = self.current_parent

   local before = self.current_parent
   self.current_parent = node
   visit(self, node, visit)
   self.current_parent = before
end

local line_numbering_visitor = {}

function line_numbering_visitor:new()
   return setmetatable({ line = 1, column = 0 }, { __index = line_numbering_visitor })
end

function line_numbering_visitor:visit_leaf(node)
   local prefix = node:prefix()

   for _, c in ipairs(prefix) do
      if c.Data == "\n" then
         self.line = self.line + 1
         self.column = 0
      else
         self.column = self.column + 1
      end
   end

   node.line = self.line
   node.column = self.column

   self.column = self.column + #node.value
end

function line_numbering_visitor:visit_node(node, visit)
   visit(self, node, visit)
end

local code_convert_visitor = {}

function code_convert_visitor:new(stream, params)
   local o = setmetatable({ params = params, first_prefix = false }, { __index = code_convert_visitor })
   o.stream = stream or { stream = io, write = function(t, ...) t.stream.write(...) end }
   return o
end

function code_convert_visitor:visit_node(node, visit)
   visit(self, node, visit)
end

function code_convert_visitor:visit_leaf(leaf)
   local no_ws = self.params.no_whitespace
   if not self.first_prefix then
      self.first_prefix = true
      if self.params.no_leading_whitespace then
         no_ws = true
      end
   end
   self.stream:write(leaf:as_string(no_ws))
end

return {
   visitor = visitor,
   print_visitor = print_visitor,
   parenting_visitor = parenting_visitor,
   line_numbering_visitor = line_numbering_visitor,
   refactoring_visitor = refactoring_visitor,
   code_convert_visitor = code_convert_visitor,
   on_hotload = function(old, new)
      for k, v in pairs(old) do
         if type(v) == "table" then
            utils.replace_table(v, new[k])
         end
      end
      for k, v in pairs(new) do
         if not old[k] then
            old[k] = v
         end
      end
   end
}
