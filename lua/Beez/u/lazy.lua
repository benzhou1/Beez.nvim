local M = {}

---@alias Beez.u.plugin.spec.delkeys string | string[]

--- Delete keys from a table
---@param tbl table
---@param keys Beez.u.plugin.spec.delkeys[]
---@return table
local function del_table_keys(tbl, keys)
  for _, key in ipairs(keys) do
    if type(key) == "string" then
      tbl[key] = nil
    else
      local v = tbl
      local _k = nil
      for _, k in ipairs(key) do
        if v ~= nil then
          v = v[k]
        end
        _k = k
      end
      if v ~= nil then
        v[_k] = nil
      end
    end
  end
  return tbl
end

--- Merges multiple plugin specifications into one.
---@param base table
---@vararg table[]
---@return table
function M.spec(base, ...)
  ---@type table[]
  local specs = { ... }

  --- New opts fuction that merges all opts
  local function opts()
    local merged_opts = base.opts or {}
    -- Handle if base opts is a function
    if type(merged_opts) ~= "table" then
      merged_opts = merged_opts()
    end

    for _, spec in ipairs(specs) do
      if spec.opts and type(spec.opts) == "table" then
        merged_opts = vim.tbl_deep_extend("force", merged_opts, spec.opts or {})

      -- opts is a function
      elseif spec.opts then
        -- opts can return del keys table to remove keys from previous opts
        local new_opts, del_keys = spec.opts(merged_opts)
        if del_keys then
          for _, dk in ipairs(del_keys) do
            del_table_keys(merged_opts, dk)
          end
        end
        merged_opts = vim.tbl_deep_extend("force", merged_opts, new_opts)
      end
    end
    return merged_opts
  end

  local config = nil
  local has_config = false
  for _, spec in ipairs(specs) do
    if spec.config ~= nil then
      has_config = true
      break
    end
  end

  if has_config then
    --- New config fuction that merges all the configs
    config = function(_, opts)
      local config_opts = {}
      for _, spec in ipairs(specs) do
        if spec.config ~= nil then
          -- config can return a table to previous configs
          local new_config_opts = spec.config(_, opts, config_opts)
          config_opts = vim.tbl_deep_extend("force", config_opts, new_config_opts or {})
        end
      end

      if base.config ~= nil then
        base.config(_, opts, config_opts)
      end
    end
  end

  --- New keys function that merges all the keys
  local function keys()
    local merged_keys = base.keys or {}
    -- Handle if base keys is a function
    if type(merged_keys) ~= "table" then
      merged_keys = merged_keys()
    end

    for _, spec in ipairs(specs) do
      if spec.keys and type(spec.keys) == "table" then
        for _, k in pairs(spec.keys) do
          table.insert(merged_keys, k)
        end

      -- keys is a function
      elseif spec.keys then
        -- opts can return del keys table to remove keys from previous keys
        local new_keys, del_keys = spec.keys(merged_keys)
        if del_keys then
          for _, dk in ipairs(del_keys) do
            del_table_keys(merged_keys, dk)
          end
        end
        for _, k in pairs(new_keys) do
          table.insert(merged_keys, k)
        end
      end
    end
    return merged_keys
  end

  local new_spec = vim.tbl_deep_extend("keep", {
    opts = opts,
    config = config,
    keys = keys,
  }, base)

  -- Merge all specs, ignoring opts, config, keys
  for _, spec in ipairs(specs) do
    local spec_copy = vim.deepcopy(spec)
    spec_copy.opts = nil
    spec_copy.config = nil
    spec_copy.keys = nil
    new_spec = vim.tbl_deep_extend("force", new_spec, spec_copy)
  end
  return new_spec
end

return M
