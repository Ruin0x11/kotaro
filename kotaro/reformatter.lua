local fun = require("fun")
local format_state = require("kotaro.format_state")
local priority_queue = require("kotaro.priority_queue")
local class = require("pl.class")
local utils = require("kotaro.utils")

local reformatter = {}

-- most of this is just ported from yapf's reformatter.py

local function count_chars(str, pattern)
   return select(2, string.gsub(str, pattern, ""))
end

local function intersection(a, b)
   local res = {}
   for k, _ in pairs(a) do
      if b[k] then
         res[k] = true
      end
   end
   return res
end

local NO_BLANK_LINES = 1
local ONE_BLANK_LINE = 2
local TWO_BLANK_LINES = 3

local function calculate_number_of_newlines(first_token, indent_depth, prev_uwline, final_lines)
   if prev_uwline == nil or first_token.leaf_type == "Eof" then
      -- First or last line in the file.
      first_token.newlines = 0
      return 0
   end

   local first_token_lineno
   if first_token.leaf_type == "Comment" then
      first_token_lineno = first_token.line - count_chars(first_token.value, "\n")
   else
      first_token_lineno = first_token.line
   end

   local prev_token = prev_uwline.tokens[#prev_uwline.tokens]
   local prev_token_lineno = prev_token.line
   if prev_token.leaf_type == "String" then
      prev_token_lineno = prev_token_lineno + count_chars(prev_token.value, "\n")
   end

   if first_token_lineno - prev_token_lineno > 1 then
      return ONE_BLANK_LINE
   end

   return NO_BLANK_LINES
end

local function format_first_token(first_token, indent_depth, prev_uwline, final_lines, config)
   local newlines = calculate_number_of_newlines(first_token, indent_depth, prev_uwline, final_lines)
   first_token:add_prefix(newlines, 0, indent_depth, config)
end

local function retain_required_vertical_spacing_between_tokens(cur_tok, prev_tok, lines)
   if not prev_tok then
      return
   end

   local prev_lineno
   if prev_tok.leaf_type == "String" or prev_tok.leaf_type == "Comment" then
      prev_lineno = prev_tok.line + count_chars(prev_tok.value, "\n")
   else
      prev_lineno = prev_tok.line
   end

   local cur_lineno
   if prev_tok.leaf_type == "Comment" then
      cur_lineno = cur_tok.line - count_chars(cur_tok.value, "\n")
   else
      cur_lineno = cur_tok.line
   end

   local required_newlines = cur_lineno - prev_lineno
   if not (cur_tok.leaf_type == "Comment" and prev_tok.leaf_type ~= "Comment") then
      if lines and (lines[cur_lineno] or lines[prev_lineno]) then
         local desired_newlines = count_chars(cur_tok._prefix, "\n")
         local whitespace_lines = fun.range(prev_lineno+1, cur_lineno):totable()
         local deletable_lines = count_chars(intersection(lines, whitespace_lines))
         required_newlines = math.max(required_newlines - deletable_lines, desired_newlines)
      end
   end

   cur_tok:adjust_newlines_before(required_newlines)
end

local function retain_vertical_spacing_before_comments(uwline)
end

local function retain_horizontal_spacing(uwline, config)
   local function retain(node, first_column, depth)
      local prev = node.prev_token
      if not prev then
         return
      end

      local cur_lineno = node.line
      local prev_lineno = prev.line
      local prev_is_multiline_string = prev.leaf_type == "String" and string.find(prev.value, "\n")
      if prev_is_multiline_string then
         prev_lineno = prev_lineno + count_chars(prev.value, "\n")
      end

      if cur_lineno ~= prev_lineno then
         node.spaces_required_before = node.column - first_column + depth * config.indent_width
         return
      end

      local cur_column = node.column
      local prev_column = prev.column
      local prev_len = string.len(prev.value)

      if prev_is_multiline_string then
         local spl = utils.split_string(node.value, "\n")
         prev_len = node.column + string.len(spl[#spl])
      end

      node.spaces_required_before = cur_column - (prev_column + prev_len)
   end

   for _, tok in ipairs(uwline.tokens) do
      retain(tok, uwline.tokens[1].column, uwline.depth)
   end
end

local function retain_required_vertical_spacing(uwline, prev_uwline, lines)
   if uwline.disabled and (not prev_uwline or prev_uwline.disable) then
      lines = {}
   end

   local prev_tok
   if prev_uwline then
      prev_tok = prev_uwline.tokens[#prev_uwline.tokens]
   end

   for _, cur_tok in ipairs(uwline.tokens) do
      retain_required_vertical_spacing_between_tokens(cur_tok, prev_tok, lines)

      prev_tok = cur_tok

      if uwline.disable then
         lines = {}
      end
   end
end

local function can_place_on_single_line(uwline, config)
   local must_split = fun.iter(uwline.tokens):any(function(t) return t.must_split end)
   if must_split then
      return false
   end

   local last = uwline.tokens[#uwline.tokens]
   if last == nil then
      return true
   end

   local indent_amount = config.indent_width * uwline.depth
   return last.total_length + indent_amount < config.column_limit
end

local function emit_line_unformatted(state)
   local prev_lineno
   while state.next_token do
      local prev_token = state.next_token.prev_token
      local the_prev_lineno = prev_token.line

      if prev_token.leaf_type == "String" then
         the_prev_lineno = the_prev_lineno + count_chars(prev_token.value, "\n")
      end

      local do_newline = prev_lineno and state.next_token.line > the_prev_lineno

      prev_lineno = state.next_token.line
      state:add_token_to_state(do_newline)
   end
end

local ordered_penalty = class()
function ordered_penalty:_init(penalty, count)
   self.penalty = penalty
   self.count = count
end
function ordered_penalty:__eq(other)
   return self.penalty == other.penalty and
      self.count == other.count
end
function ordered_penalty:__lt(other)
   if self.penalty == other.penalty then
      return self.count < other.count
   end
   return self.penalty < other.penalty
end
function ordered_penalty:__le(other)
   if self.penalty == other.penalty then
      return self.count <= other.count
   end
   return self.penalty <= other.penalty
end
function ordered_penalty:__tostring()
   return string.format("(penalty:%d, count:%d)", self.penalty, self.count)
end

local function add_next_state_to_queue(penalty, prev_node, do_newline, count, pqueue)
   local must_split = prev_node.state:calc_must_split()
   if do_newline and not prev_node.state:calc_can_split(must_split) then
      -- print("nl",prev_node.state.next_node and prev_node.state.next_node.value,prev_node.state:hash())
      return count
   end
   if not do_newline and must_split then
      -- print("nonl",prev_node.state.next_node and prev_node.state.next_node.value,prev_node.state:hash())
      return count
   end

   local node = { state = prev_node.state:clone(), newline = do_newline, prev_node = prev_node }
   penalty = penalty + node.state:add_token_to_state(do_newline, true, must_split)
   pqueue:enqueue(node, ordered_penalty(penalty, count))
   -- print("append",node.state:hash(), node.state)
   return count + 1
end

local function reconstruct_path(state, current)
   local path_reverse = {}
   while current.prev_node do
      path_reverse[#path_reverse+1] = current
      current = current.prev_node
   end

   for i = #path_reverse, 1, -1 do
      local node = path_reverse[i]
      state:add_token_to_state(node.newline)
   end
end


--- Version of tostring that bypasses metatables.
function string.tostring_raw(tbl)
   if type(tbl) ~= "table" then
      return tostring(tbl)
   end

   local mt = getmetatable(tbl)
   setmetatable(tbl, {})
   local s = tostring(tbl)
   setmetatable(tbl, mt)
   return s
end
local function analyze_solution_space(state)
   local count = 0
   local seen = {}
   local pqueue = priority_queue("min")

   local node = { state = state, newline = false, prev_node = nil }
   pqueue:enqueue(node, ordered_penalty(0, count))

   count = count + 1
   local found = false
   while not pqueue:empty() do
      local penalty
      node, penalty = pqueue:dequeue()
      if not node.state.next_token then
         found = true
         break
      end

      if count > 10000 then
         node.state.ignore_stack_for_comparison = true
      end

      local hash = node.state:hash()

      if not seen[hash] then
         seen[hash] = true

         count = add_next_state_to_queue(penalty.penalty, node, false, count, pqueue)
         count = add_next_state_to_queue(penalty.penalty, node, true, count, pqueue)
      end
   end

   if not found then
      print("--------- no solution")
      return false
   end

   reconstruct_path(state, node)

   return true
end

local function format_final_lines(final_lines)
   local formatted_code = {}

   for _, line in ipairs(final_lines) do
      local formatted_line = {}
      for _, tok in ipairs(line.tokens) do
         formatted_line[#formatted_line+1] = tok._prefix
         formatted_line[#formatted_line+1] = tok.value
      end

      formatted_code[#formatted_code+1] = table.concat(formatted_line)
   end

   return table.concat(formatted_code, "")
end

function reformatter.reformat(uwlines, lines, config)
   config = config or {}

   for _, uwline in ipairs(uwlines) do
      uwline:calc_formatting_info(config)
   end

   local indent_width = config.indent_width

   local final_lines = {}
   local prev_uwline = nil

   for _, uwline in ipairs(uwlines) do
      print(uwline)
      local first_token = uwline.tokens[1]
      format_first_token(first_token, uwline.depth, prev_uwline, final_lines, config)

      local indent_amount = indent_width * uwline.depth
      local state = format_state(uwline, indent_amount, config)
      state:move_to_next_token()

      if not uwline.disabled then
         if uwline.tokens[1] then
            if uwline.tokens[1].leaf_type == "Comment" then
            elseif uwline.tokens[#uwline.tokens].leaf_type == "Comment" then
            end
         end
         if prev_uwline and prev_uwline.disabled then
            retain_required_vertical_spacing_between_tokens(uwline.tokens[1],
                                                            prev_uwline.tokens[#prev_uwline.tokens],
                                                            lines)
         end

         if fun.iter(uwline.tokens):any(function(t) return t.leaf_type == "Comment" end) then
            retain_vertical_spacing_before_comments(uwline)
         end
      end

      if uwline.disabled then
         retain_horizontal_spacing(uwline, config)
         retain_required_vertical_spacing(uwline, prev_uwline, lines)
         emit_line_unformatted(state)
      elseif can_place_on_single_line(uwline, config) then
         while state.next_token ~= nil do
            state:add_token_to_state()
         end
      else
         if not analyze_solution_space(state) then
            state = format_state(uwline, indent_amount, config)
            state:move_to_next_token()
            retain_horizontal_spacing(uwline, config)
            retain_required_vertical_spacing(uwline, prev_uwline, lines)
            emit_line_unformatted(state)
         end
      end

      final_lines[#final_lines+1] = uwline
      prev_uwline = uwline
   end

   return format_final_lines(final_lines)
end

return reformatter
