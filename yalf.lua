local code_convert_visitor = require("yalf.visitor.code_convert_visitor")
local refactoring_visitor = require("yalf.visitor.refactoring_visitor")
local parenting_visitor = require("yalf.visitor.parenting_visitor")
local parenting_visitor = require("yalf.visitor.parenting_visitor")
local split_penalty_visitor = require("yalf.visitor.split_penalty_visitor")
local reformatting_visitor = require("yalf.visitor.reformatting_visitor")
local visitor = require("yalf.visitor")
local utils = require("yalf.utils")
local cst_parser = require("yalf.parser.cst_parser")

local yalf = {}

local function file2src(file)
   local inf = io.open(file, 'r')
   if not inf then
      print()
      return false, "Failed to open `"..file.."` for reading"
   end
   local s = inf:read('*all')
   inf:close()

   return true, s
end

local function cst2file(cst, file)
   assert(file)

   local inf = io.open(file, 'w')
   if not inf then
      print()
      return false, "Failed to open `"..file.."` for writing"
   end

   -- Don't convert the whole AST to a string at once, to prevent
   -- out-of-memory errors. Instead visit each node individually.
   visitor.visit(code_convert_visitor:new(inf), cst)

   inf:close()

   return true
end

local function cst2src(cst)
   local string_io = utils.string_io()
   local v = code_convert_visitor:new(string_io)
   visitor.visit(v, cst)
   return string_io.stream
end

local function src2cst(src)
   local ok, cst = cst_parser(src):parse()
   if not ok then return false, cst end

   visitor.visit(parenting_visitor:new(), cst)

   return true, cst
end

local function edit_file(file, cb, opts)
   opts = opts or {}

   local ok, src = file2src(file)
   if not ok then
      return false, src
   end

   local ok, cst = src2cst(src)
   if not ok then
      return false, cst
   end

   local copy = cst:clone()

   cb(copy)

   if opts.in_place then
      local ok, err = cst2file(copy)
      if not ok then
         return false, err
      end
   end

   return true, copy
end

local function edit_src(src, cb, opts)
   opts = opts or {}

   local ok, cst = src2cst(src)
   if not ok then
      return false, cst
   end

   local copy = cst:clone()

   cb(copy)

   local new_src = cst2src(copy)

   return true, new_src
end

local function format_cst(cst)
   visitor.visit(parenting_visitor:new(), cst)
   visitor.visit(split_penalty_visitor:new(), cst)
   visitor.visit(reformatting_visitor:new(), cst)
end

function yalf.format_file(file)
   assert(type(file) == "string", "'file' must be a string")
   return edit_file(file, format_cst)
end

function yalf.format_source(src)
   assert(type(src) == "string", "'src' must be a string")
   return edit_src(src, format_cst)
end

function yalf.refactor_file(file, refactorings)
   assert(type(file) == "string", "'file' must be a string")
   assert(type(refactorings) == "table", "'refactorings' must be a table")

   local function refactor_cst(cst)
      local rf = refactoring_visitor:new(refactorings)
      visitor.visit(rf, cst)
      rf:refactor()
   end

   return edit_file(file, refactor_cst)
end

function yalf.refactor_source(src, refactorings)
   assert(type(src) == "string", "'src' must be a string")

   local function refactor_cst(cst)
      local rf = refactoring_visitor:new(refactorings)
      visitor.visit(rf, cst)
      rf:refactor()
   end

   return edit_src(src, refactor_cst)
end

return yalf
