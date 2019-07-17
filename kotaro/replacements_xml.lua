-- TODO: use less bloated diff library
local diff_match_patch = require("thirdparty.diff_match_patch")

-- Outputs a clang-format-compatible replacements XML tree.
local replacements_xml = {}

function replacements_xml:new()
   return setmetatable({ replacements = {} }, { __index = replacements_xml })
end

function replacements_xml:diff(a, b)
   self.replacements = {}
   local the_diff = diff.diff(a, b)

   for _, i in ipairs(the_diff) do
      local text =
   end
end

-- from penlight
local escape_table = {
   ["'"] = "&apos;",
   ["\""] = "&quot;",
   ["<"] = "&lt;",
   [">"] = "&gt;",
   ["&"] = "&amp;"
}
local function xml_escape(str)
   return (string.gsub(str, "['&<>\"]", escape_table))
end

function replacements_xml:write(stream)
   stream:write("<?xml version='1.0'?>\n")
   stream:write("<replacements xml:space='preserve' incomplete_format='false'>\n")

   for _, r in ipairs(self.replacements) do
      stream:write("<replacement offset='")
      stream:write(tostring(r.offset))
      stream:write("' length='")
      stream:write(tostring(r.length))
      stream:write("'>")
      stream:write(xml_escape(r.text))
      stream:write("'</replacement>\n")
   end

   stream:write("</replacements>")
end

return replacements_xml
