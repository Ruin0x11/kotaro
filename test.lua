local nodes = require("yalf.parser.nodes")
local node = nodes.node
local leaf = nodes.leaf
local lexer = require("pl.lexer")

local a = node("test", {leaf("asd", "dood"),leaf("zxc", "zxc")})
local b = node("test", {leaf("asd", "dood"),leaf("zxc", "zxc")})

-- print(a == b)


local visitors = require("yalf.visitor.visitors")
local print_visitor = visitors.print_visitor

-- print_visitor():visit(a)

local inf = io.open(arg[1], 'r')
if not inf then --comment
   print("Failed to open `"..arg[1].."` for reading")
   return
end
--
local sourceText = inf:read('*all')
inf:close()

local l = require("yalf.parser.lexer")(sourceText)
local i = require("inspect")

local s = ""
while true do
   local t = l:emit()
   -- print(i(t))
   if t.Type == "Eof" then
      break
   end
   for _, v in ipairs(t.LeadingWhite) do
      s = s .. v.Data
   end
   s = s .. t.Data
end
s = s .. "\n"

local _, new = require("yalf.parser.cst_parser")(sourceText):parse()

local f1 = io.open("/tmp/f1", "w")
local f2 = io.open("/tmp/f2", "w")
f1:write(sourceText)
f2:write(tostring(new))
f1:close()
f2:close()

if new ~= sourceText then
   os.execute("diff /tmp/f1 /tmp/f2 --color=always")
end
