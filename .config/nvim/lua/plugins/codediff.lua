return {
  "esmuellert/codediff.nvim",
  cmd = "CodeDiff",
  keys = {
    { "<C-g>", "<CMD>CodeDiff<CR>", desc = "Git diff explorer" },
    { "<leader>gf", "<CMD>CodeDiff history %<CR>", desc = "File commit history" },
    { "<leader>ghh", "<CMD>CodeDiff history<CR>", desc = "Git commit history" },
  },
  config = function()
    local binary_like_suffixes = {
      ".png",
      ".jpg",
      ".jpeg",
      ".gif",
      ".webp",
      ".avif",
      ".ico",
      ".icns",
      ".bmp",
      ".tif",
      ".tiff",
      ".heic",
      ".heif",
      ".psd",
      ".zip",
      ".7z",
      ".rar",
      ".tar",
      ".tgz",
      ".tar.gz",
      ".gz",
      ".bz2",
      ".xz",
      ".pdf",
      ".mp3",
      ".wav",
      ".ogg",
      ".flac",
      ".m4a",
      ".aac",
      ".mp4",
      ".m4v",
      ".mov",
      ".avi",
      ".mkv",
      ".webm",
      ".woff",
      ".woff2",
      ".ttf",
      ".otf",
      ".eot",
      ".wasm",
      ".so",
      ".dylib",
      ".dll",
      ".exe",
      ".bin",
      ".sqlite",
      ".sqlite3",
      ".db",
    }

    local function should_skip_diff(path)
      if type(path) ~= "string" or path == "" then
        return false
      end

      local normalized = path:lower()
      for _, suffix in ipairs(binary_like_suffixes) do
        if normalized:sub(-#suffix) == suffix then
          return true
        end
      end

      return false
    end

    local function create_skipped_diff_buffer(path)
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].buftype = "nofile"
      vim.bo[bufnr].bufhidden = "wipe"
      vim.bo[bufnr].buflisted = false
      vim.bo[bufnr].swapfile = false

      pcall(vim.api.nvim_buf_set_name, bufnr, "CodeDiff Binary [" .. bufnr .. "]")

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "CodeDiff skipped rendering this binary-like file.",
        "",
        path,
        "",
        "It stays visible in the explorer, but the diff view is intentionally disabled to avoid lag.",
        "Use gf to open the real file.",
      })
      vim.bo[bufnr].modifiable = false

      return bufnr
    end

    local function show_skipped_diff(tabpage, path)
      local lifecycle = require("codediff.ui.lifecycle")
      local session = lifecycle.get_session(tabpage)
      if not session then
        return false
      end

      local info_buf = create_skipped_diff_buffer(path)
      if session.layout == "inline" then
        require("codediff.ui.view.inline_view").show_welcome(tabpage, info_buf)
      else
        require("codediff.ui.view.side_by_side").show_welcome(tabpage, info_buf)
      end

      return true
    end

    require("codediff").setup({
      keymaps = {
        view = {
          open_in_prev_tab = false,
        },
      },
      explorer = {
        view_mode = "tree",
      },
    })

    -- codediff exposes explorer.file_filter.ignore in the README, but that hides
    -- files from the explorer entirely. We want zip/png/etc. to stay visible there
    -- while skipping expensive diff rendering, so patch the internal render entry
    -- points instead.
    local lifecycle = require("codediff.ui.lifecycle")
    local view = require("codediff.ui.view")
    if not view._pi_binary_skip_patched then
      local original_view_update = view.update
      view.update = function(tabpage, session_config, auto_scroll_to_first_hunk)
        local session = lifecycle.get_session(tabpage)
        local mode = (session and session.mode) or (session_config and session_config.mode)
        local path = session_config
          and (session_config.modified_path ~= "" and session_config.modified_path or session_config.original_path)

        if mode == "explorer" and should_skip_diff(path) then
          return show_skipped_diff(tabpage, path)
        end

        return original_view_update(tabpage, session_config, auto_scroll_to_first_hunk)
      end
      view._pi_binary_skip_patched = true
    end

    local inline_view = require("codediff.ui.view.inline_view")
    if not inline_view._pi_binary_skip_patched then
      local original_show_single_file = inline_view.show_single_file
      inline_view.show_single_file = function(tabpage, file_path, opts)
        local session = lifecycle.get_session(tabpage)
        local path = (opts and opts.rel_path) or file_path

        if session and session.mode == "explorer" and should_skip_diff(path) then
          return show_skipped_diff(tabpage, path)
        end

        return original_show_single_file(tabpage, file_path, opts)
      end
      inline_view._pi_binary_skip_patched = true
    end

    local side_by_side = require("codediff.ui.view.side_by_side")
    if not side_by_side._pi_binary_skip_patched then
      local function wrap_single_file_renderer(method_name, path_resolver)
        local original = side_by_side[method_name]
        side_by_side[method_name] = function(tabpage, ...)
          local session = lifecycle.get_session(tabpage)
          local path = path_resolver(...)

          if session and session.mode == "explorer" and should_skip_diff(path) then
            return show_skipped_diff(tabpage, path)
          end

          return original(tabpage, ...)
        end
      end

      wrap_single_file_renderer("show_untracked_file", function(file_path)
        return file_path
      end)
      wrap_single_file_renderer("show_deleted_file", function(_, file_path)
        return file_path
      end)
      wrap_single_file_renderer("show_added_virtual_file", function(_, file_path)
        return file_path
      end)
      wrap_single_file_renderer("show_deleted_virtual_file", function(_, file_path)
        return file_path
      end)

      side_by_side._pi_binary_skip_patched = true
    end

    local function resolve_explorer_target(diff_tab)
      local explorer = lifecycle.get_explorer(diff_tab)
      if not explorer or not explorer.current_file_path then
        return nil
      end

      local candidate_roots = {
        explorer.git_root,
        explorer.dir2,
        explorer.dir1,
      }

      for _, root in ipairs(candidate_roots) do
        if root and root ~= "" then
          local candidate = root .. "/" .. explorer.current_file_path
          if vim.fn.filereadable(candidate) == 1 then
            return candidate
          end
        end
      end

      return nil
    end

    local function resolve_gf_target(diff_tab)
      local current_buf = vim.api.nvim_get_current_buf()
      local current_name = vim.api.nvim_buf_get_name(current_buf)
      if current_name ~= "" and vim.fn.filereadable(current_name) == 1 then
        return current_name, vim.fn.line(".")
      end

      local explorer_target = resolve_explorer_target(diff_tab)
      if explorer_target then
        return explorer_target, 1
      end

      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(diff_tab)) do
        local buf = vim.api.nvim_win_get_buf(win)
        local name = vim.api.nvim_buf_get_name(buf)
        if name ~= "" and vim.fn.filereadable(name) == 1 then
          return name, 1
        end
      end

      return nil, nil
    end

    local function set_gf_keymap(buf, diff_tab)
      if vim.b[buf].codediff_gf_tab == diff_tab then
        return
      end

      pcall(vim.keymap.del, "n", "gf", { buffer = buf })
      vim.b[buf].codediff_gf_tab = diff_tab

      vim.keymap.set("n", "gf", function()
        local target, line = resolve_gf_target(diff_tab)
        if not target then
          vim.notify("No real file available for this CodeDiff selection", vim.log.levels.WARN)
          return
        end

        vim.cmd("tabclose")
        vim.cmd(string.format("edit +%d %s", line or 1, vim.fn.fnameescape(target)))
      end, { buffer = buf, desc = "Open file and close diff" })
    end

    local gf_augroup = vim.api.nvim_create_augroup("CodeDiffGf", { clear = true })

    vim.api.nvim_create_autocmd("User", {
      pattern = "CodeDiffOpen",
      callback = function()
        local diff_tab = vim.api.nvim_get_current_tabpage()
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(diff_tab)) do
          set_gf_keymap(vim.api.nvim_win_get_buf(win), diff_tab)
        end

        vim.api.nvim_create_autocmd("BufEnter", {
          group = gf_augroup,
          callback = function()
            if vim.api.nvim_get_current_tabpage() == diff_tab then
              set_gf_keymap(vim.api.nvim_get_current_buf(), diff_tab)
            end
          end,
        })
      end,
    })
  end,
}
