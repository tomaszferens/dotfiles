return {
  "esmuellert/codediff.nvim",
  cmd = { "CodeDiff", "CodeDiffPiLastTurn", "CodeDiffPiMessages" },
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
        formatters = {
          -- codediff renders untracked files with git's raw "??" status code;
          -- show them as "A" like other added files (untracked color kept so
          -- staged vs untracked stay distinguishable).
          file = function(ctx)
            if ctx.status == "??" then
              ctx.status = "A"
            end
            return require("codediff.ui.explorer.formatters").file(ctx)
          end,
        },
      },
    })

    -- codediff exposes explorer.file_filter.ignore in the README, but that hides
    -- files from the explorer entirely. We want zip/png/etc. to stay visible there
    -- while skipping expensive diff rendering, so patch the internal render entry
    -- points instead.
    local lifecycle = require("codediff.ui.lifecycle")
    local view = require("codediff.ui.view")
    local pi_rewind = require("utils.codediff_pi_rewind")

    -- CodeDiff explorer sessions start with an empty placeholder diff result
    -- until the scheduled first file selection runs. Replacing one CodeDiff tab
    -- with another can briefly resume that placeholder; normalize it so the
    -- renderer treats it as an empty diff instead of crashing on nil changes.
    local core = require("codediff.ui.core")
    if not core._pi_empty_diff_guard_patched then
      local original_render_diff = core.render_diff
      core.render_diff = function(left_bufnr, right_bufnr, original_lines, modified_lines, lines_diff)
        lines_diff = lines_diff or {}
        lines_diff.changes = lines_diff.changes or {}
        lines_diff.moves = lines_diff.moves or {}
        return original_render_diff(left_bufnr, right_bufnr, original_lines, modified_lines, lines_diff)
      end
      core._pi_empty_diff_guard_patched = true
    end

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

    local function normalize_codediff_path(path)
      if type(path) == "table" then
        path = path.relative ~= "" and path.relative or path.absolute
      end
      if type(path) ~= "string" or path == "" then
        return nil
      end

      return require("utils.ai").strip_cwd(path)
    end

    local pending_comments = setmetatable({}, { __mode = "k" })

    local function send_to_agent(text)
      local herdr = require("utils.herdr")
      if herdr.available() then
        return herdr.send(text)
      end
      return require("utils.ai").send(text)
    end

    local function codediff_reference(session, current_buf, visual)
      local path_ref
      if current_buf == session.original_bufnr then
        path_ref = session.original
      elseif current_buf == session.modified_bufnr then
        path_ref = session.modified
      else
        local buffer_name = vim.api.nvim_buf_get_name(current_buf)
        if buffer_name:match("^codediff://") or vim.fn.filereadable(buffer_name) == 1 then
          path_ref = buffer_name
        end
      end

      local path = normalize_codediff_path(path_ref)
        or normalize_codediff_path(session.modified)
        or normalize_codediff_path(session.original)
      if not path then
        return nil
      end

      local reference = "@" .. path
      if not visual then
        return reference
      end

      local start_line = vim.fn.line("v")
      local end_line = vim.fn.line(".")
      if start_line > end_line then
        start_line, end_line = end_line, start_line
      end
      vim.cmd([[execute "normal! \<Esc>"]])

      if start_line == end_line then
        return string.format("%s#L%d", reference, start_line)
      end
      return string.format("%s#L%d-L%d", reference, start_line, end_line)
    end

    local function prompt_ai_with_codediff_reference(diff_tab)
      local lifecycle = require("codediff.ui.lifecycle")
      local session = lifecycle.get_session(diff_tab)
      if vim.api.nvim_get_current_tabpage() ~= diff_tab or not session then
        return false
      end

      local current_buf = vim.api.nvim_get_current_buf()
      if vim.bo[current_buf].filetype == "codediff-explorer" then
        return false
      end

      local visual = vim.fn.mode():match("^[vV\22]") ~= nil
      local pending = pending_comments[session]
      if visual or not pending then
        local reference = codediff_reference(session, current_buf, visual)
        if not reference then
          vim.notify("No file path available for this CodeDiff buffer", vim.log.levels.WARN)
          return true
        end
        pending = { reference = reference, comment = pending and pending.comment or "" }
        pending_comments[session] = pending
      end

      vim.schedule(function()
        local input = require("snacks.input").input({
          prompt = pending.reference .. " - ",
          default = pending.comment,
        }, function(comment)
          if comment == nil then
            return
          end

          pending_comments[session] = nil
          comment = vim.trim(comment)
          local text = comment == "" and pending.reference or (pending.reference .. " - " .. comment)
          send_to_agent(text .. " ")
        end)

        input:on({ "TextChanged", "TextChangedI" }, function()
          if input:valid() then
            pending.comment = input:text()
          end
        end, { buf = true })
      end)

      return true
    end

    require("utils.herdr").codediff_option_a_handler = function()
      return prompt_ai_with_codediff_reference(vim.api.nvim_get_current_tabpage())
    end

    local function set_ai_comment_keymap(buf, diff_tab)
      if vim.b[buf].codediff_ai_hunk_tab == diff_tab then
        return
      end

      vim.b[buf].codediff_ai_hunk_tab = diff_tab
      vim.keymap.set({ "n", "x" }, "<M-a>", function()
        prompt_ai_with_codediff_reference(diff_tab)
      end, { buffer = buf, desc = "Comment on CodeDiff selection for AI" })
    end

    local function set_pi_rewind_keymaps(buf, diff_tab)
      if vim.b[buf].codediff_pi_rewind_tab == diff_tab then
        return
      end
      if vim.bo[buf].filetype ~= "codediff-explorer" then
        return
      end

      vim.b[buf].codediff_pi_rewind_tab = diff_tab
      vim.keymap.set("n", "l", function()
        pi_rewind.pick_user_message({ tabpage = diff_tab, prompt_on_fail = true })
      end, { buffer = buf, desc = "Pick Pi user-message checkpoint diff" })
      vim.keymap.set("n", "L", function()
        pi_rewind.prompt_last_turn({ tabpage = diff_tab })
      end, { buffer = buf, desc = "Paste Pi checkpoint diff spec" })
    end

    local function set_codediff_buffer_keymaps(buf, diff_tab)
      set_gf_keymap(buf, diff_tab)
      set_pi_rewind_keymaps(buf, diff_tab)

      local session = lifecycle.get_session(diff_tab)
      if session and (buf == session.original_bufnr or buf == session.modified_bufnr) then
        set_ai_comment_keymap(buf, diff_tab)
      end
    end

    vim.api.nvim_create_user_command("CodeDiffPiLastTurn", function(opts)
      if opts.args and vim.trim(opts.args) ~= "" then
        pi_rewind.open_spec(opts.args)
      else
        pi_rewind.open_last_turn({ prompt_on_fail = true })
      end
    end, {
      nargs = "*",
      force = true,
      desc = "Open CodeDiff for the latest pi-rewind turn checkpoint",
    })

    vim.api.nvim_create_user_command("CodeDiffPiMessages", function()
      pi_rewind.pick_user_message({ prompt_on_fail = true })
    end, {
      force = true,
      desc = "Pick a Pi user-message checkpoint diff",
    })

    local gf_augroup = vim.api.nvim_create_augroup("CodeDiffGf", { clear = true })

    vim.api.nvim_create_autocmd("User", {
      pattern = "CodeDiffOpen",
      callback = function()
        local diff_tab = vim.api.nvim_get_current_tabpage()
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(diff_tab)) do
          set_codediff_buffer_keymaps(vim.api.nvim_win_get_buf(win), diff_tab)
        end

        vim.api.nvim_create_autocmd("BufEnter", {
          group = gf_augroup,
          callback = function()
            if vim.api.nvim_get_current_tabpage() == diff_tab then
              set_codediff_buffer_keymaps(vim.api.nvim_get_current_buf(), diff_tab)
            end
          end,
        })
      end,
    })
  end,
}
