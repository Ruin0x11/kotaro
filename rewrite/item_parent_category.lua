local mapping = {
  ["bug"]                     = "elona.bug",
  ["crop_herb"]               = "elona.food",
  ["crop_seed"]               = "elona.food",
  ["drink_alcohol"]           = "elona.drink",
  ["drink_potion"]            = "elona.drink",
  ["equip_ammo_arrow"]        = "elona.equip_ammo",
  ["equip_ammo_bolt"]         = "elona.equip_ammo",
  ["equip_ammo_bullet"]       = "elona.equip_ammo",
  ["equip_ammo_energy_cell"]  = "elona.equip_ammo",
  ["equip_back_cloak"]        = "elona.equip_back",
  ["equip_back_girdle"]       = "elona.equip_cloak",
  ["equip_body_mail"]         = "elona.equip_body",
  ["equip_body_robe"]         = "elona.equip_body",
  ["equip_head_hat"]          = "elona.equip_head",
  ["equip_head_helm"]         = "elona.equip_head",
  ["equip_leg_heavy_boots"]   = "elona.equip_leg",
  ["equip_leg_shoes"]         = "elona.equip_leg",
  ["equip_melee_axe"]         = "elona.equip_melee",
  ["equip_melee_broadsword"]  = "elona.equip_melee",
  ["equip_melee_club"]        = "elona.equip_melee",
  ["equip_melee_halberd"]     = "elona.equip_melee",
  ["equip_melee_hammer"]      = "elona.equip_melee",
  ["equip_melee_hand_axe"]    = "elona.equip_melee",
  ["equip_melee_lance"]       = "elona.equip_melee",
  ["equip_melee_long_sword"]  = "elona.equip_melee",
  ["equip_melee_scythe"]      = "elona.equip_melee",
  ["equip_melee_short_sword"] = "elona.equip_melee",
  ["equip_melee_staff"]       = "elona.equip_melee",
  ["equip_neck_armor"]        = "elona.equip_neck",
  ["equip_ranged_bow"]        = "elona.equip_ranged",
  ["equip_ranged_crossbow"]   = "elona.equip_ranged",
  ["equip_ranged_gun"]        = "elona.equip_ranged",
  ["equip_ranged_laser_gun"]  = "elona.equip_ranged",
  ["equip_ranged_thrown"]     = "elona.equip_ranged",
  ["equip_ring_ring"]         = "elona.equip_ring",
  ["equip_shield_shield"]     = "elona.equip_shield",
  ["equip_wrist_gauntlet"]    = "elona.equip_wrist",
  ["equip_wrist_glove"]       = "elona.equip_wrist",
  ["food_flour"]              = "elona.food",
  ["food_fruit"]              = "elona.food",
  ["food_noodle"]             = "elona.food",
  ["food_vegetable"]          = "elona.food",
  ["furniture_altar"]         = "elona.furniture_altar",
  ["furniture_bed"]           = "elona.misc_item",
  ["furniture_instrument"]    = "elona.furniture",
  ["furniture_well"]          = "elona.furniture_well",
  ["junk_in_field"]           = "elona.furniture",
  ["junk_town"]               = "elona.junk_in_field",
  ["misc_item_crafting"]      = "elona.misc_item",
  ["ore_valuable"]            = "elona.ore",
  ["scroll_deed"]             = "elona.scroll"
}

local item_parent_category = {}

function item_parent_category:new()
   return setmetatable({}, {__index = item_parent_category})
end
function item_parent_category:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   local id = node:index("_id")
   if not id or id:type() ~= "expression" then
      return false
   end

   return mapping[id:evaluate()]
end
function item_parent_category:execute(node)
   local id = node:index("_id"):evaluate()

   local parents = { "\"" .. mapping[id] .. "\"" }

   local Codegen = require("kotaro.parser.codegen")
   local expr = Codegen.gen_constructor_expression(parents)
   node:modify_index("parents", expr)
   -- node:modify_index("category", nil)
   -- node:modify_index("subcategory", nil)
   -- node:modify_index("tags", nil)
end

return require("rewrite.lib.refactoring")(item_parent_category)
