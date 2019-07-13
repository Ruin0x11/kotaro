local hotload = {
   debug = true
}

local function escape_for_gsub(s)
   return string.gsub(s, "([^%w])", "%%%1")
end

local function string_strip_prefix(s, prefix)
   return string.gsub(s, "^" .. escape_for_gsub(prefix), "")
end

local function string_strip_suffix(s, suffix)
   return string.gsub(s, escape_for_gsub(suffix) .. "$", "")
end

local function string_split(str,sep)
   sep = sep or "\n"
   local ret={}
   local n=1
   for w in str:gmatch("([^"..sep.."]*)") do
      ret[n] = ret[n] or w
      if w=="" then
         n = n + 1
      end
   end
   return ret
end

local function string_tostring_raw(tbl)
   if type(tbl) ~= "table" then
      return tostring(tbl)
   end

   local mt = getmetatable(tbl)
   setmetatable(tbl, {})
   local s = tostring(tbl)
   setmetatable(tbl, mt)
   return s
end

local function table_replace_with(tbl, other)
   if tbl == other then
      return tbl
   end

   for k, _ in pairs(tbl) do
      tbl[k] = nil
   end

   for k, v in pairs(other) do
      tbl[k] = v
   end

   return tbl
end

local function table_set(tbl)
   local set = {}
   for _, v in ipairs(tbl) do
      set[v] = true
   end
   return set
end

local stdlib = table_set {
   "string",
   "math",
   "table",
}

-- To determine the require path of a chunk, it is necessary to keep a
-- cache. If a chunk is hotloaded, the table it returns will be merged
-- into the one already existing in any upvalues, but the table
-- upvalue that was created inside the chunk itself will still
-- reference a completely different table (the one that was merged
-- into the existing one). Since this upvalue can be local there may
-- be no way to access it, so in the end there can be more than one
-- table at the same require path. This cache table is a mapping from
-- a table to its require path.
--
-- TODO: actually you can use a function called debug.setupvalue to
-- modify upvalues. it should be used instead.
local require_path_cache = setmetatable({}, { __mode = "k" })

local function print_debug(s, ...)
   if hotload.debug then
      print(string.format(s, ...))
   end
end

local global_require = require

--- Loads a chunk from a package search path ignoring
--- `package.loaded`. If no environment is passed, the returned chunk
--- will have access to the global environment.
-- @tparam string path
-- @tparam[opt] table env
local function hotload_loadfile(path, env)
   local resolved = package.searchpath(path, package.path)

   if resolved == nil then
      if stdlib[path] then
         local pkg = global_require(path)
         if pkg then
            return pkg
         end
      end

      resolved = package.searchpath(path, package.cpath)
      if resolved then
         return global_require(path)
      end
   end

   if resolved == nil then
      local paths = ""
      for _, s in ipairs(string_split(package.path, ";")) do
         paths = paths .. "\n" .. s
      end
      return nil, string.format("Cannot find path \"%s\":%s", path, paths)
   end

   local chunk, err = loadfile(resolved)
   if chunk == nil then
      return nil, err
   end

   env = env or _G
   setfenv(chunk, env)

   local success, err = xpcall(chunk, debug.traceback)
   if not success then
      return nil, err
   end

   local result = err
   return result
end

local IS_HOTLOADING = false
local HOTLOAD_DEPS = false
local HOTLOADED = {}
local LOADING = {}

-- Converts a filepath to a uniquely identifying Lua require path.
-- Examples:
-- api/chara/IChara.lua -> api.chara.IChara
-- mod/elona/init.lua   -> mod.elona
function hotload.convert_to_require_path(path)
   local path = path

   -- HACK: needs better normalization to prevent duplicate chunks. If
   -- this is not completely unique then two require paths could end
   -- up referring to the same file, breaking hotloading. The
   -- intention is any require path uniquely identifies a return value
   -- from `require`.
   path = string_strip_suffix(path, ".lua")
   path = string.gsub(path, "/", ".")
   path = string.gsub(path, "\\", ".")
   path = string_strip_suffix(path, ".init")

   return path
end

local function gen_require(chunk_loader)
   return function(path, do_hotload)
      local req_path = hotload.convert_to_require_path(path)

      if LOADING[req_path] then
         error("Loop while loading " .. req_path)
      end

      do_hotload = do_hotload or HOTLOAD_DEPS

      -- Don't hotload again if the req_path was already hotloaded
      -- earlier.
      if do_hotload and HOTLOADED[req_path] then
         do_hotload = false
      end

      if not do_hotload and package.loaded[req_path] then
         return package.loaded[req_path]
      end

      print_debug("HOTLOAD %s", req_path)
      LOADING[req_path] = true
      local result, err = chunk_loader(req_path)
      LOADING[req_path] = false
      print_debug("HOTLOAD RESULT %s", tostring(result))

      if err then
         IS_HOTLOADING = false
         error("\n\t" .. err, 0)
      end

      if IS_HOTLOADING and result == "no_hotload" then
         print_debug("Not hotloading: %s", req_path)
         return package.loaded[req_path]
      end

      if type(package.loaded[req_path]) == "table"
         and type(result) == "table"
      then
         print_debug("Hotload: %s %s <- %s", req_path, string_tostring_raw(package.loaded[req_path]), string_tostring_raw(result))
         if result.on_hotload then
            result.on_hotload(package.loaded[req_path], result)
         else
            table_replace_with(package.loaded[req_path], result)
         end
         print_debug("Hotload result: %s", string_tostring_raw(package.loaded[req_path]))
      elseif result == nil then
         package.loaded[req_path] = true
      else
         package.loaded[req_path] = result
      end

      if do_hotload then
         HOTLOADED[req_path] = true
      end

      if type(result) == "table" then
         require_path_cache[result] = req_path
      end

      return package.loaded[req_path]
   end
end

--- Version of `require` for the global environment that will respect
--- hotloading and mod environments, and also allow requiring
--- non-public files.
-- @function hotload.require
hotload.require = gen_require(hotload_loadfile)

--- Reloads a path or a class required from a path that has been
--- required already by updating its table in-place. If either the
--- result of `require` or the existing item in package.loaded are not
--- tables, the existing item is overwritten instead.
-- @tparam string|table path
-- @tparam bool also_deps If true, also hotload any nested
-- dependencies loaded with `require` that any hotloaded chunk tries
-- to load.
-- @treturn table
function hotload.hotload(path_or_class, also_deps)
   if type(path_or_class) == "table" then
      local path = hotload.get_require_path(path_or_class)
      if path == nil then
         error("Unknown require path for " .. tostring(path_or_class))
      end

      path_or_class = path
   end

   return hotload.hotload_path(path_or_class, also_deps)
end

--- Reloads a path that has been required already by updating its
--- table in-place. If either the result of `require` or the existing
--- item in package.loaded are not tables, the existing item is
--- overwritten instead.
-- @tparam string path
-- @tparam bool also_deps If true, also hotload any nested
-- dependencies loaded with `require` that any hotloaded chunk tries
-- to load.
-- @treturn table
function hotload.hotload_path(path, also_deps)
   -- The require path can come from an editor that preserves an
   -- "init.lua" at the end. We still need to strip "init.lua" from
   -- the end if that's the case, in order to make the paths
   -- "api/Api.lua" and "api/Api/init.lua" resolve to the same thing.
   path = hotload.convert_to_require_path(path)

   HOTLOADED = {}

   local loaded = package.loaded[path]
   if not loaded then
      print_debug("Tried to hotload '%s', but path was not yet loaded. Requiring normally.", path)
      return hotload.require(path, false)
   end

   if also_deps then
      -- Enable hotloading for any call to a hooked `require` until
      -- the top-level `hotload` call finishes.
      HOTLOAD_DEPS = true
   end

   print_debug("Begin hotload: %s", path)
   IS_HOTLOADING = path
   local result = hotload.require(path, true)
   IS_HOTLOADING = false

   if also_deps then
      HOTLOAD_DEPS = false
   end

   return result
end

--- Returns the currently hotloading path if hotloading is ongoing.
--- Used to implement specific support for hotloading in global
--- variables besides the entries in package.loaded.
-- @treturn bool
function hotload.is_hotloading()
   return IS_HOTLOADING
end

if hotload.is_hotloading() then
   return "no_hotload"
end

--- Overwrites Lua's builtin `require` with a version compatible with
--- the hotloading system.
function hotload.hook_global_require()
   require = function(path)
      -- ignore second argument (`hotload`)
      return hotload.require(path)
   end
end

-- Given a table loaded with require, a class/interface table or a
-- class instance, returns its require path.
function hotload.get_require_path(tbl)
   assert(type(tbl) == "table")

   if tbl.__class then
      tbl = tbl.__class
   end

   local path = require_path_cache[tbl]
   print(require"inspect"(require_path_cache))

   if path == nil then
      error(string.format("Cannot find require path for %s (%s)", tostring(tbl), string_tostring_raw(tbl)))
   end

   return path
end

function hotload.is_loaded(path)
   return package.loaded[path] ~= nil
end

return setmetatable(hotload, { __call = function(self, ...) return hotload.hotload(...) end })
