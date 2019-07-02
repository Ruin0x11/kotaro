local nodes = require("yalf.parser.nodes")
local node = nodes.node
local leaf = nodes.leaf
local lexer = require("pl.lexer")

local a = node("test", {leaf("asd", "dood"),leaf("zxc", "zxc")})
local b = node("test", {leaf("asd", "dood"),leaf("zxc", "zxc")})

-- print(a == b)


local visitors = require("yalf.visitor.visitors")
local print_visitor = visitors.print_visitor
local visitor = visitors.visitor

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

local cst_parser = require("yalf.parser.cst_parser")
local a, new = cst_parser(sourceText):parse()
if not a then
   print(new)
end

local f1 = io.open("/tmp/f1", "w")
local f2 = io.open("/tmp/f2", "w")
f1:write(sourceText)
f2:write(tostring(new))
f1:close()
f2:close()

if new ~= sourceText then
   os.execute("diff /tmp/f1 /tmp/f2 --color=always")
end

local ex = require("yalf.visitor.refactoring").exchange_refactoring()

local r = visitors.refactoring_visitor:new({ex})

visitor.visit(r, new)

print(tostring(new))

-- visitor.visit(print_visitor:new(), new)
