local code_convert_visitor = require("kotaro.visitor.code_convert_visitor")
local rewriting_visitor = require("kotaro.visitor.rewriting_visitor")
local parenting_visitor = require("kotaro.visitor.parenting_visitor")
local parenting_visitor = require("kotaro.visitor.parenting_visitor")
local split_penalty_visitor = require("kotaro.visitor.split_penalty_visitor")
local reformatting_visitor = require("kotaro.visitor.reformatting_visitor")
local visitor = require("kotaro.visitor")
local utils = require("kotaro.utils")
local cst_parser = require("kotaro.parser.cst_parser")

local kotaro = {}

local function file2src(file)
   local inf = io.open(file, 'r')
   if not inf then
      return nil, "Failed to open `"..file.."` for reading"
   end

   local s = inf:read('*all')
   inf:close()

   return s
end

function kotaro.output_ast_as_code(ast, stream)
   -- Don't convert the whole AST to a string at once, to prevent
   -- out-of-memory errors. Instead visit each node individually.
   visitor.visit(code_convert_visitor:new(stream), ast)
end

function kotaro.ast_to_file(cst, file)
   assert(file)

   local inf = io.open(file, 'w')
   if not inf then
      return false, "Failed to open `"..file.."` for writing"
   end

   kotaro.output_ast_as_code(cst, inf)

   inf:close()

   return true
end

function kotaro.file_to_ast(file)
   assert(type(file) == "string", "'file' must be a string")

   local src, err = file2src(file)
   if not src then return nil, err end

   return kotaro.source_to_ast(src, file)
end

function kotaro.source_to_ast(src, filename)
   assert(type(src) == "string", "'src' must be a string")

   local ok, cst = cst_parser(src, filename):parse()
   if not ok then return nil, cst end

   cst:changed()

   return cst
end

local function edit_file(file, cb, opts)
   opts = opts or {}

   local cst, err = kotaro.file_to_ast(file)
   if not cst then
      return nil, err
   end

   local copy = cst:clone()

   cb(copy)

   if opts.in_place then
      local ok, err = kotaro.ast_to_file(copy)
      if not ok then
         return nil, err
      end
   end

   if opts.as_cst then
      return copy
   end

   return copy:as_code()
end

local function edit_src(src, cb, opts)
   opts = opts or {}

   local cst, err = kotaro.source_to_ast(src)
   if not cst then
      return nil, err
   end

   local copy = cst:clone()

   cb(copy)

   if opts.as_cst then
      return copy
   end

   return copy:as_code()
end

local function format_cst(cst)
   visitor.visit(split_penalty_visitor:new(), cst)
   visitor.visit(reformatting_visitor:new(), cst)
end

function kotaro.format_file(file, opts)
   assert(type(file) == "string", "'file' must be a string")
   return edit_file(file, format_cst, opts)
end

function kotaro.format_source(src, opts)
   assert(type(src) == "string", "'src' must be a string")
   return edit_src(src, format_cst, opts)
end

function kotaro.rewrite_file(file, refactorings, opts)
   assert(type(file) == "string", "'file' must be a string")
   assert(type(refactorings) == "table", "'refactorings' must be a table")

   local function rewrite_cst(cst)
      local rf = rewriting_visitor:new(refactorings)
      visitor.visit(rf, cst)
      rf:do_rewrite()
   end

   return edit_file(file, rewrite_cst, opts)
end

function kotaro.rewrite_source(src, refactorings, opts)
   assert(type(src) == "string", "'src' must be a string")

   local function rewrite_cst(cst)
      local rf = rewriting_visitor:new(refactorings)
      visitor.visit(rf, cst)
      rf:do_rewrite()
   end

   return edit_src(src, rewrite_cst, opts)
end

return kotaro
