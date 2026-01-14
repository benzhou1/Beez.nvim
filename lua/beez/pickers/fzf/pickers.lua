local M = {}

local match_commit_hash = function(line, opts)
  if type(opts.fn_match_commit_hash) == "function" then
    return opts.fn_match_commit_hash(line, opts)
  else
    return line:match("[^ ]+")
  end
end

--- Show picker of commits and open diffview with the selected commit
function M.git_commit_diff(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    actions = {
      ---@diagnostic disable-next-line: redefined-local
      ["enter"] = function(selected, opts)
        local commit_hash = match_commit_hash(selected[1], opts)
        if commit_hash then
          require("diffview").open({ commit_hash .. "^.." .. commit_hash })
        end
      end,
    },
  })
  require("fzf-lua.providers.git").commits(opts)
end

--- Picker for git branches
function M.git_branches(opts)
  require("fzf-lua.providers.git").branches(opts)
end

--- Compare current file with a branch
function M.git_compare_path_with_branch(path, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    actions = {
      ["enter"] = function(selected, _)
        local branch = selected[1]:match("[^ ]+")
        if branch:find("%*") ~= nil then
          return
        end
        require("diffview").open({ branch, "--", path })
      end,
    },
  })
  M.git_branches(opts)
end

--- Compare current project with a branch
function M.git_compare_project_with_branch(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    actions = {
      ["enter"] = function(selected, _)
        local branch = selected[1]:match("[^ ]+")
        if branch:find("%*") ~= nil then
          return
        end
        require("diffview").open({ branch })
      end,
    },
  })
  M.git_branches(opts)
end

return M
