-- visitor for extracting comments in node prefixes to full CST nodes.
--
-- for the purposes of source code analysis, putting comments in the
-- prefixes significantly reduces complexity. however, when formatting
-- it is far more useful to have them as individual elements.
--
-- note that after this pass is complete, it is an error to use the
-- metatable methods of CST nodes since comments will be spliced into
-- each node table, breaking the assumptions each method makes about
-- the position of CST elements.
local comment_extract_visitor = {}

local BYTE_DASH = string.byte("-")
local BYTE_CR = string.byte("\n")
local BYTE_LF = string.byte("\r")
local BYTE_SPACE = string.byte(" ")
local BYTE_TAB = string.byte("\t")
local BYTE_POUND = string.byte("#")
local BYTE_BANG = string.byte("!")

function comment_extract_visitor:new()
   local o = setmetatable({ }, { __index = comment_extract_visitor })
   return o
end

function comment_extract_visitor:visit_leaf(node)
   local prefix = node._prefix

   local i = 1
   local long_str = false
   local c, leading_white
   local result = {}

   local function peek(n)
      return prefix:sub(i+n, i+n)
   end

   local function get()
      local c = peek(0)
      i = i + 1
      return c
   end

   while true do
      c = string.sub(prefix, i, i)
      if c == '#' and peek(1) == '!' and self.line == 1 then
         -- #! shebang for linux scripts
         get()
         get()
         leading_white = "#!"
         while peek() ~= '\n' and peek() ~= '' do
            leading_white = leading_white .. get()
         end
         local token = {
            Type = 'Comment',
            CommentType = 'Shebang',
            Data = leading_white,
            Line = self.line,
            Char = self.char
         }
         result[#result+1] = token
         leading_white = ""
      end
      if c == ' ' or c == '\t' then
         --whitespace
         --leading_white = leading_white..get()
         local c2 = get() -- ignore whitespace
      elseif c == '\n' or c == '\r' then
         local nl = get()
         if leading_white ~= "" then
            local token = {
               Type = 'Comment',
               CommentType = long_str and 'LongComment' or 'Comment',
               Data = leading_white,
               Line = self.line,
               Char = self.char,
            }
            result[#result+1] = token
            leading_white = ""
         end
      elseif c == '-' and peek(1) == '-' then
         --comment
         get()
         get()
         leading_white = leading_white .. '--'
         local _, wholeText = self:tryGetLongString()
         if wholeText then
            leading_white = leading_white..wholeText
            long_str = true
         else
            while peek() ~= '\n' and peek() ~= '' do
               leading_white = leading_white..get()
            end
         end
      else
         break
      end
   end

   node._parsed_prefix = result
end

function comment_extract_visitor:visit_node(node, visit)
   visit(self, node, visit)
end

return comment_extract_visitor
