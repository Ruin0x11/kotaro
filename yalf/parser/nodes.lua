local class = require("thirdparty.pl.class")

local node = class()

function node:_init(_type, children, prefix)
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

function node:is_leaf()
   return false
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
   if self.type ~= other.type then
      return false
   end
   if #self.children ~= #other.children then
      return false
   end
   for i=1,#self.children do
      if self.children[i] ~= other.children[i] then
         return false
      end
   end
   return true
end

function node:__tostring()
   local code = ""
   for _, v in ipairs(self.children) do
      code = code .. tostring(v)
   end
   return code
end

function node:get_value()
   local code = ""
   for _, v in ipairs(self.children) do
      code = code .. v:get_value()
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

function node:remove_child(i)
   local child = self.children[i]
   child.parent = nil
   table.remove(self.children, i)
   return child
end

local leaf = class()

function leaf:_init(_type, value, prefix, line, column)
   self.children = nil

   self.value = value
   self.type = _type
   self.line = line or 0
   self.column = column or 0
   self._prefix = prefix or {}
   self.is_leaf = true
end

function leaf:is_leaf()
   return true
end

function leaf:__eq(other)
   return self.type == other.type and self.value == other.value
end

function leaf:prefix_to_string()
   local prefix = ""
   for _, v in ipairs(self._prefix) do
      prefix = prefix .. v.Data
   end
   return prefix
end

function leaf:__tostring()
   return self:prefix_to_string() .. tostring(self.value)
end

function leaf:get_value()
   return tostring(self.value)
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
