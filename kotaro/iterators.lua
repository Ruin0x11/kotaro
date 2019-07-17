local iterators = {}

local function depth_first_postorder(state, ind)
   local old = ind.node

   if not old then
      return nil
   end

   local new
   if ind.first then
      ind.first = false
      new = old
   else
      if state.backward then
         new = ind.node.left
      else
         new = ind.node.right
      end
   end

   if new then
      if #new > 1 then
         -- This node contains children. Start at the last child at
         -- the bottom of the tree.
         if state.backward then
            new = new:last_leaf()
         else
            new = new:first_leaf()
         end
      end
   else
      -- Reached the first child in the node's parent.
      new = ind.node.parent
   end

   if new == state.start then
      -- The first node is visited as the first one in the iterator
      -- (as is standard in DFS), so don't visit it again.
      return nil
   end

   return { node = new }, old
end

local function depth_first_preorder(state, ind)
   local old = ind.node

   if not old then
      return nil
   end

   local new
   if #old > 1 then
      -- This node contains children. Start at first direct child.
      if state.backward then
         new = old[#old]
      else
         new = old[2]
      end
   else
      if state.backward then
         new = ind.node.left
      else
         new = ind.node.right
      end

      if not new then
         -- Travel back up the stack to the next node in the previously
         -- visited parent, if any.
         local parent = ind.node.parent
         while not new and parent do
            if state.backward then
               new = parent.left
            else
               new = parent.right
            end
            parent = parent.parent
         end
      end
   end

   return { node = new }, old
end

function iterators.iter_depth_first(cst, postorder, backward)
   return postorder and depth_first_postorder or depth_first_preorder,
     { backward = backward, start = cst },
     { node = cst, first = true }
end

local function breadth_first(state, ind)
   local new = ind.container:pop()
   if not new then
      return nil
   end

   local start, finish, step
   if state.backward then
      start = #new
      finish = 2
      step = -1
   else
      start = 2
      finish = #new
      step = 1
   end

   for i=start, finish, step do
      local child = new[i]
      if not ind.discovered[child] then
         ind.discovered[child] = true
         ind.container:push(child)
      end
   end

   return ind, new
end

local queue = {}
function queue:new()
   return setmetatable({ first = {}, second = {} }, { __index = queue })
end
function queue:push(item)
   table.insert(self.first, item)
end
function queue:pop()
   if #self.second == 0 then
      for i=#self.first,1,-1 do
         local item = table.remove(self.first, i)
         table.insert(self.second, item)
      end
   end

   return table.remove(self.second)
end

local stack = {}
function stack:new()
   return setmetatable({ stack = {} }, { __index = stack })
end
function stack:push(item)
   table.insert(self.stack, item)
end
function stack:pop()
   return table.remove(self.stack)
end

function iterators.iter_breadth_first(cst, postorder, backward)
   local container = queue:new()
   container:enqueue(cst)
   return breadth_first, { backward = backward }, { container = container, discovered = {} }
end

local function left(state, node)
   if not node or node == "stop" then
      return nil
   end
   if not node[2] then
      return "stop", node
   end

   return node[2], node
end

-- iterates the first child of every node recursively.
function iterators.iter_left(cst)
   return left, {}, cst[2]
end

local function right(state, node)
   if not node or node == "stop" then
      return nil
   end
   if #node == 1 then
      return "stop", node
   end
   if not node[#node] then
      return "stop", node
   end

   return node[#node], node
end

-- iterates the last child of every node recursively.
function iterators.iter_right(cst)
   local start
   if #cst == 1 then
      start = "stop"
   else
      start = cst[#cst]
   end

   return right, {}, start
end

return iterators
