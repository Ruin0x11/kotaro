local class = require("pl.class")
local tablex = require("pl.tablex")
local utils = require("kotaro.utils")
local tree_utils = require("kotaro.parser.tree_utils")

local hash
if jit then
   hash = require("thirdparty.luaxxhash")
end

local format_state = class()

local function split(str, sep)
   local fields = {}
   local pattern = string.format("([^%s]+)", sep)
   string.gsub(str, pattern, function(c) fields[#fields+1] = c end)
   return fields
end

local paren_state = class()
function paren_state:_init(indent, last_space)
   self.indent = indent
   self.last_space = last_space
   self.closing_scope_indent = 0
   self.split_before_closing_bracket = false
   self.num_line_splits = 0
end

function paren_state:__eq(other)
   return self.indent == other.indent
      and self.last_space == other.last_space
      and self.closing_scope_indent == other.closing_scope_indent
      and self.split_before_closing_bracket == other.split_before_closing_bracket
      and self.num_line_splits == other.num_line_splits
end

function paren_state:hash()
   return hash(string.format("%d%d%d%s%d",
                             self.indent,
                             self.last_space,
                             self.closing_scope_indent,
                             self.split_before_closing_bracket,
                             self.num_line_splits))
end

function format_state:_init(line, first_indent, config)
   self.line = line
   self.column = first_indent
   self.first_indent = first_indent
   self.next_token = line.tokens[1]
   self.lowest_level_on_line = 0
   self.paren_level = 0
   self.paren_stack = {paren_state(first_indent, first_indent)}
   self.newline = false
   self.config = config
end

function format_state:__eq(other)
   if not self.ignore_stack_for_comparison then
      if #self.paren_stack ~= #other.paren_stack then
         return false
      end
      for i, v in ipairs(self.paren_stack) do
         if v ~= other.paren_stack[i] then
            return false
         end
      end
   end

   return self.line == other.line
      and self.column == other.column
      and self.first_indent == other.first_indent
      and self.next_token == other.next_token
      and self.lowest_level_on_line == other.lowest_level_on_line
      and self.paren_level == other.paren_level
      and self.newline == other.newline
      and self.config == other.config
end

function format_state:clone()
   local new = format_state(self.line, self.first_indent, self.config)
   new.column = self.column
   new.next_token = self.next_token
   new.lowest_level_on_line = self.lowest_level_on_line
   new.paren_level = self.paren_level
   new.paren_stack = tablex.deepcopy(self.paren_stack)
   new.newline = self.newline
   return new
end

function format_state:hash()
   local stack = 0
   for _, v in ipairs(self.paren_stack) do
      -- stack = stack + v:hash()
   end
   return hash(string.format("%d%s%d%d%d%s",
                             self.column,
                             self.next_token,
                             self.lowest_level_on_line,
                             self.paren_level,
                             stack,
                             self.newline))
end

function format_state:calc_must_split()
   local current = self.next_token
   local prev = current.prev_token

   return current.must_split
end

function format_state:calc_can_split()
   local current = self.next_token
   local prev = current.prev_token

   return current.can_split
end

function format_state:add_token_on_current_line(dry_run)
   local current = self.next_token
   local prev = current.prev_token
   local last = self.paren_stack[#self.paren_stack]
   local spaces = current.spaces_required_before

   if not dry_run and current.leaf_type ~= "Eof" then
      current:add_prefix(0, spaces, nil, self.config)
   end

   if tree_utils.opens_scope(prev) then
      if current.leaf_type ~= "Comment" then
         -- foo = {a,
         --        b,
         --       }
         last.closing_scope_indent = self.column - 1
         if self.config.align_closing_bracket_with_visual_indent then
            last.closing_scope_indent = last.closing_scope_indent + 1
         end
         last.indent = self.column + spaces
      else
         last.closing_scope_indent = last.indent + self.config.continuation_indent_width
      end
   end

   self.column = self.column + spaces
end

local function is_compound_statement(token)
   return utils.set({"then", "do", "repeat", "else"})[token.value]
end

function format_state:calc_newline_column()
   local current = self.next_token
   local prev = current.prev_token
   local last = self.paren_stack[#self.paren_stack]

   if current.spaces_required_before > 2 or self.line.disabled then
      return current.spaces_required_before
   end

   if tree_utils.opens_scope(current) then
      if self.paren_level > 0 then
         return last.indent
      else
         return self.first_indent
      end
   end

   if tree_utils.closes_scope(current) then
      if tree_utils.opens_scope(prev)
         or (prev.leaf_type == "Comment" and prev.prev_token and tree_utils.opens_scope(prev.prev_token))
      then
         return math.max(0, last.indent - self.config.continuation_indent_width)
      end
      return last.closing_scope_indent
   end

   if is_compound_statement(self.line.tokens[1])
   and (not self.config.dedent_closing_brackets
        or self.config.split_before_first_argument)
   then
      local spl = split(self.line.tokens[1]._prefix, "\n")
      local token_indent = string.len(spl[#spl]) + self.config.indent_width
      if token_indent == last.indent then
         return last.indent + self.config.continuation_indent_width
      end
   end

   if current.value == ":" then
      return last.indent + 4
   end

   return last.indent
end

function format_state:add_token_on_newline(dry_run, must_split)
   local current = self.next_token
   local prev = current.prev_token
   local last = self.paren_stack[#self.paren_stack]

   self.column = self:calc_newline_column()

   if not dry_run then
      local indent_level = self.line.depth
      local spaces = self.column
      if spaces > 0 then
         spaces = spaces - indent_level * self.config.indent_width
      end
      current:add_prefix(1, spaces, indent_level, self.config)
   end

   if current.leaf_type ~= "Comment" then
      last.last_space = self.column
   end
   self.lowest_level_on_line = self.paren_level

   if tree_utils.opens_scope(prev) or prev.leaf_type == "Comment" and prev.prev_token and opens_scope(prev.prev_token) then
      last.closing_scope_indent = math.max(0, last.indent - self.config.continuation_indent_width)
   end

   last.split_before_closing_bracket = true

   local penalty = current.split_penalty

   if must_split then
      return penalty
   end

   if not utils.set({"do", "then", "repeat", "else"})[current.value] then
      last.num_line_splits = last.num_line_splits + 1
      penalty = penalty + self.config.split_penalty_for_added_line_split * last.num_line_splits
   end

   if tree_utils.opens_scope(current) and tree_utils.opens_scope(prev) then
      local prev_token = prev.prev_token
      if not prev_token or not prev_token.leaf_type == "Ident" then
         penalty = penalty + 10
      end
   end

   return penalty + 10
end

function format_state:add_token_to_state(do_newline, dry_run, must_split)
   local penalty = 0
   if do_newline then
      penalty = self:add_token_on_newline(dry_run, must_split)
   else
      self:add_token_on_current_line(dry_run)
   end

   return self:move_to_next_token() + penalty
end

function format_state:move_to_next_token()
   local current = self.next_token
   if current == nil then
      return
   end

   if not tree_utils.opens_scope(current) and not tree_utils.closes_scope(current) then
      self.lowest_level_on_line = math.min(self.lowest_level_on_line, self.paren_level)
   end

   if tree_utils.opens_scope(current) then
      local last = self.paren_stack[#self.paren_stack]
      local new_indent = self.config.continuation_indent_width + last.last_space
      self.paren_stack[#self.paren_stack+1] = paren_state(new_indent, last.last_space)
      self.paren_level = self.paren_level + 1
   end

   if #self.paren_stack > 1 and tree_utils.closes_scope(current) then
      local last = self.paren_stack[#self.paren_stack]
      local sec_last = self.paren_stack[#self.paren_stack-1]
      sec_last.last_space = last.last_space

      self.paren_stack[#self.paren_stack] = nil
      self.paren_level = self.paren_level - 1
   end

   local is_multiline_string = current.leaf_type == "string" and string.find(current.value, "\n")
   if is_multiline_string then
      self.column = self.column + string.len(split(current.value, "\n")[1])
   else
      self.column = self.column + string.len(current.value)
   end

   self.next_token = self.next_token.next_token

   local penalty = 0
   if self.column > self.config.column_limit then
      local excess_characters = self.column - self.config.column_limit
      penalty = penalty + self.config.split_penalty_excess_character * excess_characters
   end

   if is_multiline_string then
      local spl = split(current.value, "\n")
      self.column = self.column + string.len(spl[#spl])
   end

   return penalty
end

return format_state
