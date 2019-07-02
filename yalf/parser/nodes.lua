local class = require("thirdparty.pl.class")

local base_node = {}

function base_node:init_fields()
   self.type = nil
   self.parent = nil
   self.children = {}
end

function base_node:__eq()
   error("unimplemented")
end

function base_node:clone()
   error("unimplemented")
end

function base_node:replace()
   error("unimplemented")
end

function base_node:set_prefix(prefix)
   error("unimplemented")
end

function base_node:get_prefix()
   error("unimplemented")
end

local node = class(base_node)

function node:_init(_type, children, prefix)
   self:init_fields()

   assert(_type)
   self.type = _type
   self.children = children or {}
   for _, v in ipairs(self.children) do
      assert(v.parent == nil)
      v.parent = self
   end

   if prefix then
      self:set_prefix(prefix)
   end
end

function node:set_prefix(prefix)
   if #self.children > 0 then
      self.children[1]:set_prefix(prefix)
   end
end

function node:get_prefix()
   if #self.children == 0 then
      return ""
   end
   return self.children[1]:get_prefix()
end

function node:__eq(other)
   if not self.type == other.type then
      return false
   end
   if not #self.children == #other.children then
      return false
   end
   for i=1,#self.children do
      if self.children[i] ~= other.children[i] then
         return false
      end
   end
   return true
end

local leaf
function node:__tostring()
   local code = ""
   for _, v in ipairs(self.children) do
      code = code .. tostring(v)
   end
   return code
end

function node:clone()
   local children = {}
   for _, v in ipairs(self.children) do
      children[#children+1] = v:clone()
   end
   return node(self.type, children)
end

function node:set_child(i, child)
   child.parent = self
   self.children[i].parent = nil
   self.children[i] = child
end

function node:insert_child(i, child)
   child.parent = self
   table.insert(self.children, i, child)
end

function node:append_child(child)
   child.parent = self
   table.insert(self.children, child)
end

local leaf = class(base_node)

function leaf:_init(_type, value, prefix, line, column)
   self:init_fields()

   assert(value, _type)
   self.value = value
   assert(_type)
   self.type = _type

   self.line = line or 0
   self.column = column or 0
   self._prefix = prefix or {}
end

function leaf:__eq(other)
   return self.type == other.type and self.value == other.value
end

function leaf:__tostring()
   local prefix = ""
   for _, v in ipairs(self._prefix) do
      prefix = prefix .. v.Data
   end

   return prefix .. tostring(self.value)
end

function leaf:clone()
   return leaf(self.type, self.value, self._prefix, self.line, self.column)
end

function leaf:set_prefix(prefix)
   self._prefix = prefix
end

function leaf:get_prefix()
   return self._prefix
end

return { node = node, leaf = leaf }
