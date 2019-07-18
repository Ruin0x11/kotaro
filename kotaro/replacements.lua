local utils = require("kotaro.utils")
local diff = require("thirdparty.diff")

local replacements = {}

function replacements:new()
   return setmetatable({ replacements = {} }, { __index = replacements })
end

-- Generate a list of edits to transform string `a` into string `b`.
local function generate_edit_list(a, b, file)
   local the_diff = diff.diff(a, b)

   local result = {}

   local offset = 0
   local start_offset = 1
   local current_out
   local current_in

   local function add()
      if not current_in and not current_out then
         -- no change
      else
         if not current_in then
            -- only deletion
            current_in = ""
         end
         if not current_out then
            -- only insertion
            current_out = ""
         end

         local r = {
            file = file,
            offset = start_offset + 1,
            length = offset - start_offset,
            text = current_in,
         }

         table.insert(result, r)

         current_out = nil
         current_in = nil
      end
   end

   -- Combine consecutive "in" and "out" chunks. When a "same" chunk
   -- is reached the resulting edit is made by replacing all "in" text
   -- with "out" text starting from the position of the last "same"
   -- chunk.
   for i, r in ipairs(the_diff) do
      local text = r[1]
      local kind = r[2]

      if kind == "same" then
         add()
         offset = offset + #text
         start_offset = offset
      elseif kind == "out" then
         offset = offset + #text

         if current_out then
            current_out = current_out .. text
         else
            current_out = text
         end
      elseif kind == "in" then
         if current_in then
            current_in = current_in .. text
         else
            current_in = text
         end
      end
   end

   add()

   return result
end

function replacements:diff(a, b, file)
   local edits = generate_edit_list(a, b, file)

   for _, e in ipairs(edits) do
      table.insert(self.replacements, e)
   end
end

function replacements:write(stream)
   for _, v in ipairs(self.replacements) do
      stream:write(v.file)
      stream:write(":")
      stream:write(tostring(v.offset))
      stream:write(":")
      stream:write(tostring(v.length))
      stream:write(":")
      stream:write(utils.escape_string(v.text))
      stream:write("\n")
   end
end

return replacements
