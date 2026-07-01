local M = {}

local REF_PREFIX = "refs/pi-checkpoints/"
local UUID_PATTERN = "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "CodeDiff pi-rewind" })
end

local function trim(value)
  return vim.trim(tostring(value or ""))
end

local function has_prefix(value, prefix)
  return type(value) == "string" and value:sub(1, #prefix) == prefix
end

local function git_lines(git_root, args)
  local cmd = { "git", "-C", git_root }
  vim.list_extend(cmd, args)

  local output = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return nil, table.concat(output or {}, "\n")
  end

  return output, nil
end

local function git_one(git_root, args)
  local lines, err = git_lines(git_root, args)
  if not lines then
    return nil, err
  end

  return trim(lines[1] or ""), nil
end

local function git_output(git_root, args)
  local cmd = { "git", "-C", git_root }
  vim.list_extend(cmd, args)

  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil, output
  end

  return output, nil
end

local session_user_message_cache = {}
local diff_status_filters = {}
local git_diff_filter_patched = false

local function find_pi_session_file(session_id)
  if not session_id or session_id == "" then
    return nil
  end

  local sessions_dir = vim.fn.expand("~/.pi/agent/sessions")
  if vim.fn.isdirectory(sessions_dir) ~= 1 then
    return nil
  end

  local matches = vim.fn.globpath(sessions_dir, "**/*" .. session_id .. "*.jsonl", false, true)
  if type(matches) == "table" and #matches > 0 then
    table.sort(matches, function(a, b)
      return vim.fn.getftime(a) > vim.fn.getftime(b)
    end)
    return matches[1]
  end

  -- Filename normally contains the session id. Fall back to header scanning for
  -- older/renamed files without pulling every session into memory at once.
  local all_sessions = vim.fn.globpath(sessions_dir, "**/*.jsonl", false, true)
  if type(all_sessions) ~= "table" then
    return nil
  end

  for _, file in ipairs(all_sessions) do
    local fh = io.open(file, "r")
    if fh then
      local first_line = fh:read("*l") or ""
      fh:close()
      if first_line:find('"id":"' .. session_id .. '"', 1, true) then
        return file
      end
    end
  end

  return nil
end

local function timestamp_to_ms(value)
  if type(value) == "number" then
    -- Pi session message timestamps are Unix milliseconds.
    return value
  end

  if type(value) ~= "string" or value == "" then
    return nil
  end

  local year, month, day, hour, min, sec, millis = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)%.?(%d*)Z?$")
  if not year then
    return nil
  end

  local epoch = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec),
    isdst = false,
  })
  if not epoch then
    return nil
  end

  -- os.time treats the table as local time, while Pi entry timestamps are ISO UTC.
  local offset = os.difftime(os.time(os.date("*t", epoch)), os.time(os.date("!*t", epoch)))
  millis = (millis or "") .. "000"
  return (epoch + offset) * 1000 + (tonumber(millis:sub(1, 3)) or 0)
end

local function compact_text(value)
  value = tostring(value or "")
  value = value:gsub("%s+", " ")
  return trim(value)
end

local function truncate_text(value, max_len)
  value = compact_text(value)
  max_len = max_len or 100
  if #value <= max_len then
    return value
  end
  return value:sub(1, math.max(1, max_len - 1)) .. "…"
end

local function user_content_text(content)
  if type(content) == "string" then
    return content
  end

  if type(content) ~= "table" then
    return ""
  end

  local parts = {}
  for _, block in ipairs(content) do
    if type(block) == "string" then
      table.insert(parts, block)
    elseif type(block) == "table" then
      if block.type == "text" and type(block.text) == "string" then
        table.insert(parts, block.text)
      elseif type(block.text) == "string" then
        table.insert(parts, block.text)
      elseif block.type == "image" then
        table.insert(parts, "[image]")
      end
    end
  end

  return table.concat(parts, "\n")
end

local function is_user_message_entry(entry)
  return type(entry) == "table"
    and entry.type == "message"
    and type(entry.message) == "table"
    and entry.message.role == "user"
end

local function parse_session_entries(session_file)
  local fh = io.open(session_file, "r")
  if not fh then
    return nil
  end

  local entries = {}
  local by_id = {}
  local leaf_id = nil

  for line in fh:lines() do
    local ok, entry = pcall(vim.json.decode, line)
    if ok and type(entry) == "table" then
      table.insert(entries, entry)
      if entry.type ~= "session" and entry.id then
        by_id[entry.id] = entry
        leaf_id = entry.id
      end
    end
  end
  fh:close()

  return entries, by_id, leaf_id
end

local function current_branch_entries(entries, by_id, leaf_id)
  if not leaf_id then
    return entries or {}
  end

  local path = {}
  local seen = {}
  local entry = by_id[leaf_id]
  while entry and not seen[entry.id] do
    seen[entry.id] = true
    table.insert(path, entry)
    entry = entry.parentId and by_id[entry.parentId] or nil
  end

  local branch = {}
  for i = #path, 1, -1 do
    table.insert(branch, path[i])
  end
  return branch
end

local function normalize_repo_path(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end

  path = path:gsub("^@", ""):gsub("\\", "/")
  path = path:gsub("^%./", "")
  path = path:gsub("^/Users/[^/]+/projects/[^/]+/", "")
  path = path:gsub("^/", "")
  return path ~= "" and path or nil
end

local function add_touched_path(message, path, timestamp)
  path = normalize_repo_path(path)
  if not path then
    return
  end

  message.touched_paths = message.touched_paths or {}
  message.touched_paths[path] = true
  if timestamp and ((message.last_touched_timestamp or 0) < timestamp) then
    message.last_touched_timestamp = timestamp
  end
end

local function add_paths_from_shell_command(message, command, timestamp)
  if type(command) ~= "string" then
    return
  end

  -- Capture repo-looking paths from commands like `rm apps/foo.ts`, prettier,
  -- codegen, etc. This is intentionally broad: it is only used as a display
  -- filter for the selected user-message diff.
  for candidate in command:gmatch("[%w%._@/-]+%.[%w_%-]+") do
    if candidate:find("/", 1, true) then
      add_touched_path(message, candidate, timestamp)
    end
  end
end

local function collect_touched_paths(message, entry)
  if not message or entry.type ~= "message" or type(entry.message) ~= "table" then
    return
  end

  local entry_timestamp = timestamp_to_ms(entry.message and entry.message.timestamp) or timestamp_to_ms(entry.timestamp)
  local msg = entry.message
  if msg.role == "assistant" and type(msg.content) == "table" then
    for _, block in ipairs(msg.content) do
      if type(block) == "table" and block.type == "toolCall" then
        local name = block.name
        local args = block.arguments or {}
        if (name == "edit" or name == "write") and args.path then
          add_touched_path(message, args.path, entry_timestamp)
        elseif name == "bash" then
          add_paths_from_shell_command(message, args.command, entry_timestamp)
        elseif name == "ctx_execute" then
          add_paths_from_shell_command(message, args.code or args.command, entry_timestamp)
        elseif name == "ctx_batch_execute" and type(args.commands) == "table" then
          for _, command in ipairs(args.commands) do
            add_paths_from_shell_command(message, command.command, entry_timestamp)
          end
        end
      end
    end
  elseif msg.role == "toolResult" then
    if msg.toolName == "edit" or msg.toolName == "write" then
      local text = user_content_text(msg.content)
      add_touched_path(message, text:match(" in ([%w%._@/-]+%.[%w_%-]+)"), entry_timestamp)
      add_touched_path(message, text:match(" to ([%w%._@/-]+%.[%w_%-]+)"), entry_timestamp)
    end
  end
end

local function touched_path_list(message)
  local paths = {}
  for path in pairs(message.touched_paths or {}) do
    table.insert(paths, path)
  end
  table.sort(paths)
  return paths
end

local function session_file_stamp(session_file)
  return tostring(vim.fn.getftime(session_file)) .. ":" .. tostring(vim.fn.getfsize(session_file))
end

local function load_session_user_messages(session_id)
  local session_file = find_pi_session_file(session_id)
  if not session_file then
    session_user_message_cache[session_id] = false
    return nil
  end

  local stamp = session_file_stamp(session_file)
  local cached = session_user_message_cache[session_id]
  if type(cached) == "table" and cached.file == session_file and cached.stamp == stamp then
    return cached.messages
  end

  local entries, by_id, leaf_id = parse_session_entries(session_file)
  if not entries then
    session_user_message_cache[session_id] = false
    return nil
  end

  local messages = {}
  local current_message = nil
  for _, entry in ipairs(current_branch_entries(entries, by_id, leaf_id)) do
    if is_user_message_entry(entry) then
      local ts = timestamp_to_ms(entry.message.timestamp) or timestamp_to_ms(entry.timestamp)
      if ts then
        current_message = {
          index = #messages + 1,
          id = entry.id,
          session_id = session_id,
          timestamp = ts,
          text = user_content_text(entry.message.content),
          touched_paths = {},
        }
        table.insert(messages, current_message)
      end
    else
      collect_touched_paths(current_message, entry)
    end
  end

  for _, message in ipairs(messages) do
    message.only_paths = touched_path_list(message)
  end

  for i, message in ipairs(messages) do
    message.index = i
    message.next_timestamp = messages[i + 1] and messages[i + 1].timestamp or nil
  end

  session_user_message_cache[session_id] = {
    file = session_file,
    stamp = stamp,
    messages = #messages > 0 and messages or nil,
  }
  return #messages > 0 and messages or nil
end

local function latest_user_timestamp_before(session_id, checkpoint_timestamp)
  local messages = load_session_user_messages(session_id)
  if not messages then
    return nil
  end

  local latest = nil
  for _, message in ipairs(messages) do
    if message.timestamp <= checkpoint_timestamp then
      latest = message.timestamp
    else
      break
    end
  end

  return latest
end

local function git_root_sync(path)
  local target = path
  if not target or target == "" then
    target = vim.fn.getcwd()
  end

  if vim.fn.isdirectory(target) ~= 1 then
    target = vim.fn.fnamemodify(target, ":h")
  end

  local lines = vim.fn.systemlist({ "git", "-C", target, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 or not lines or not lines[1] then
    return nil
  end

  return trim(lines[1]):gsub("\\", "/")
end

local function current_codediff_session(tabpage)
  local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
  if not ok then
    return nil
  end

  tabpage = tabpage or vim.api.nvim_get_current_tabpage()
  return lifecycle.get_session(tabpage)
end

local function resolve_git_root(opts)
  opts = opts or {}
  if opts.git_root and opts.git_root ~= "" then
    return opts.git_root
  end

  local session = current_codediff_session(opts.tabpage)
  if session and session.git_root and session.git_root ~= "" then
    return session.git_root
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local current_name = vim.api.nvim_buf_get_name(current_buf)
  return git_root_sync(current_name) or git_root_sync(vim.fn.getcwd())
end

local function strip_checkpoint_prefix(value)
  if has_prefix(value, REF_PREFIX) then
    return value:sub(#REF_PREFIX + 1)
  end
  return value
end

local function parse_checkpoint_id(id)
  id = strip_checkpoint_prefix(id)

  local session_id, turn_index, timestamp = id:match("^turn%-(" .. UUID_PATTERN .. ")%-(%d+)%-(%d+)$")
  if session_id then
    return {
      id = id,
      kind = "turn",
      session_id = session_id,
      turn_index = tonumber(turn_index) or 0,
      timestamp = tonumber(timestamp) or 0,
    }
  end

  session_id, timestamp = id:match("^resume%-(" .. UUID_PATTERN .. ")%-(%d+)$")
  if session_id then
    return {
      id = id,
      kind = "resume",
      session_id = session_id,
      turn_index = 0,
      timestamp = tonumber(timestamp) or 0,
    }
  end

  session_id, timestamp = id:match("^before%-restore%-(" .. UUID_PATTERN .. ")%-(%d+)$")
  if session_id then
    return {
      id = id,
      kind = "before-restore",
      session_id = session_id,
      turn_index = 0,
      timestamp = tonumber(timestamp) or 0,
    }
  end

  return {
    id = id,
    kind = "unknown",
    session_id = nil,
    turn_index = 0,
    timestamp = 0,
  }
end

local function parse_commit_message(cp, lines)
  for _, line in ipairs(lines or {}) do
    if line:match("^sessionId%s+") then
      cp.session_id = trim(line:match("^sessionId%s+(.+)$"))
    elseif line:match("^trigger%s+") then
      cp.trigger = trim(line:match("^trigger%s+(.+)$"))
    elseif line:match("^turn%s+") then
      cp.turn_index = tonumber(line:match("^turn%s+(%d+)$")) or cp.turn_index
    elseif line:match("^description%s+") then
      cp.description = trim(line:match("^description%s+(.+)$"))
    elseif line:match("^branch%s+") then
      cp.branch = trim(line:match("^branch%s+(.+)$"))
    elseif line:match("^created%s+") then
      cp.created = trim(line:match("^created%s+(.+)$"))
    end
  end
end

local function load_checkpoint(git_root, ref)
  ref = trim(ref)
  if ref == "" then
    return nil
  end

  local id = strip_checkpoint_prefix(ref)
  local cp = parse_checkpoint_id(id)
  cp.ref = has_prefix(ref, REF_PREFIX) and ref or (REF_PREFIX .. id)

  local sha = git_one(git_root, { "rev-parse", "--verify", cp.ref })
  if not sha or sha == "" then
    return nil
  end
  cp.sha = sha

  local commit_lines = git_lines(git_root, { "cat-file", "commit", sha })
  parse_commit_message(cp, commit_lines or {})

  if cp.timestamp == 0 then
    local unix_time = git_one(git_root, { "show", "-s", "--format=%ct", sha })
    cp.timestamp = (tonumber(unix_time) or 0) * 1000
  end

  return cp
end

local function load_checkpoints(git_root)
  -- One git process instead of N refs × (rev-parse + cat-file). This is the
  -- hot path for pressing `l`, so batch all checkpoint metadata with
  -- for-each-ref and parse commit bodies locally.
  local field_sep = string.char(0x1f)
  local record_sep = string.char(0x1e)
  local output, err = git_output(git_root, {
    "for-each-ref",
    "--format=%(refname)%1f%(objectname)%1f%(committerdate:unix)%1f%(contents)%1e",
    REF_PREFIX,
  })
  if not output then
    return nil, err or "failed to list pi-rewind checkpoint refs"
  end

  local checkpoints = {}
  for record in output:gmatch("([^" .. record_sep .. "]*)" .. record_sep) do
    record = record:gsub("^\n", "")
    if record ~= "" then
      local p1 = record:find(field_sep, 1, true)
      local p2 = p1 and record:find(field_sep, p1 + 1, true)
      local p3 = p2 and record:find(field_sep, p2 + 1, true)
      if p1 and p2 and p3 then
        local ref = record:sub(1, p1 - 1)
        local sha = record:sub(p1 + 1, p2 - 1)
        local unix_time = tonumber(record:sub(p2 + 1, p3 - 1)) or 0
        local body = record:sub(p3 + 1)

        local id = strip_checkpoint_prefix(ref)
        local cp = parse_checkpoint_id(id)
        cp.ref = ref
        cp.sha = sha
        parse_commit_message(cp, vim.split(body, "\n", { plain = true }))
        if cp.timestamp == 0 then
          cp.timestamp = unix_time * 1000
        end

        if cp.session_id then
          table.insert(checkpoints, cp)
        end
      end
    end
  end

  table.sort(checkpoints, function(a, b)
    if a.timestamp == b.timestamp then
      return (a.turn_index or 0) < (b.turn_index or 0)
    end
    return (a.timestamp or 0) < (b.timestamp or 0)
  end)

  return checkpoints, nil
end

local function eligible_previous(cp, latest)
  if cp.session_id ~= latest.session_id then
    return false
  end
  if cp.id == latest.id or cp.kind == "before-restore" then
    return false
  end
  if (cp.timestamp or 0) > (latest.timestamp or 0) then
    return false
  end
  return cp.kind == "resume" or cp.kind == "turn"
end

local function find_previous_eligible_before(checkpoints, latest, before_timestamp)
  local previous = nil
  for _, cp in ipairs(checkpoints) do
    if eligible_previous(cp, latest) and (cp.timestamp or 0) < before_timestamp then
      previous = cp
    end
  end
  return previous
end

local function checkpoint_prompt_key(cp)
  local description = cp and cp.description or ""
  return description:match('^"([^"]*)"')
end

local function pi_prompt_label(message)
  local text = tostring((message and message.text) or "")
  if #text <= 60 then
    return text
  end
  return text:sub(1, 59) .. "…"
end

local function checkpoint_matches_message(cp, message)
  local key = checkpoint_prompt_key(cp)
  return key ~= nil and key == pi_prompt_label(message)
end

local function checkpoint_index(checkpoints, target)
  for i, cp in ipairs(checkpoints) do
    if cp.id == target.id then
      return i
    end
  end
  return nil
end

local function find_prompt_group_baseline(checkpoints, latest)
  local latest_index = checkpoint_index(checkpoints, latest)
  if not latest_index then
    return nil
  end

  local latest_prompt = checkpoint_prompt_key(latest)
  local first_index = latest_index

  for i = latest_index - 1, 1, -1 do
    local cp = checkpoints[i]
    if cp.session_id == latest.session_id and cp.kind ~= "before-restore" then
      local same_prompt = latest_prompt and checkpoint_prompt_key(cp) == latest_prompt
      local earlier_internal_turn = cp.kind == "turn" and (cp.turn_index or 0) < (checkpoints[first_index].turn_index or 0)
      if same_prompt or (not latest_prompt and earlier_internal_turn) then
        first_index = i
      else
        break
      end
    end
  end

  for i = first_index - 1, 1, -1 do
    local cp = checkpoints[i]
    if eligible_previous(cp, latest) then
      return cp
    end
  end

  return nil
end

local function find_previous_checkpoint(checkpoints, latest)
  -- pi-rewind 0.5 checkpoints at every Pi internal turn_end. A single user
  -- prompt can span multiple internal turns, so "last turn" must diff from the
  -- checkpoint before the latest user message, not from the immediately
  -- previous checkpoint.
  local user_timestamp = latest_user_timestamp_before(latest.session_id, latest.timestamp or 0)
  if user_timestamp then
    local previous = find_previous_eligible_before(checkpoints, latest, user_timestamp)
    if previous then
      return previous
    end
  end

  -- If the Pi session file is unavailable, fall back to grouping adjacent
  -- checkpoints with the same prompt label (or decreasing internal turnIndex).
  return find_prompt_group_baseline(checkpoints, latest)
    or find_previous_eligible_before(checkpoints, latest, latest.timestamp or 0)
end

local function latest_session_id_from_checkpoints(checkpoints, opts)
  if opts and opts.session_id then
    return opts.session_id
  end

  for i = #checkpoints, 1, -1 do
    local cp = checkpoints[i]
    if cp.kind == "turn" and cp.session_id then
      return cp.session_id
    end
  end

  for i = #checkpoints, 1, -1 do
    if checkpoints[i].session_id then
      return checkpoints[i].session_id
    end
  end

  return nil
end

local function checkpoint_is_in_message_window(cp, message)
  return cp.session_id == message.session_id
    and cp.kind == "turn"
    and (cp.timestamp or 0) >= message.timestamp
    and (not message.next_timestamp or (cp.timestamp or 0) < message.next_timestamp)
end

local function find_latest_checkpoint_for_user_message(checkpoints, message)
  local latest = nil

  -- Prefer the checkpoint whose pi-rewind prompt label matches this branch
  -- message. This avoids borrowing checkpoints from abandoned /tree branches
  -- that happen to be chronologically between two current-branch messages.
  for _, cp in ipairs(checkpoints) do
    if checkpoint_is_in_message_window(cp, message) and checkpoint_matches_message(cp, message) then
      latest = cp
    end
  end
  if latest then
    return latest
  end

  -- Fallback for older/malformed checkpoint labels.
  for _, cp in ipairs(checkpoints) do
    if checkpoint_is_in_message_window(cp, message) then
      latest = cp
    end
  end

  return latest
end

local function initial_baseline_for_messages(checkpoints, session_id, first_timestamp)
  local baseline = nil
  for _, cp in ipairs(checkpoints) do
    if cp.session_id == session_id and cp.kind ~= "before-restore" and (cp.timestamp or 0) < first_timestamp then
      baseline = cp
    end
  end
  return baseline
end

local function first_checkpoint_after(checkpoints, session_id, timestamp)
  for _, cp in ipairs(checkpoints) do
    if cp.session_id == session_id and cp.kind == "turn" and (cp.timestamp or 0) > timestamp then
      return cp
    end
  end
  return nil
end

local function pair_display_target(checkpoints, message, latest)
  if not latest then
    return first_checkpoint_after(checkpoints, message.session_id, message.last_touched_timestamp or message.timestamp)
  end

  -- pi-rewind sometimes creates the last checkpoint before a later mutating
  -- shell command in the same assistant turn (for example `rm file.ts`). The
  -- deletion then only appears in the next checkpoint, which chronologically
  -- belongs to the next user message. Keep the per-message path filter, but
  -- let this message use the first later checkpoint so those late changes do
  -- not disappear completely.
  if message.last_touched_timestamp and message.last_touched_timestamp > (latest.timestamp or 0) then
    return first_checkpoint_after(checkpoints, message.session_id, message.last_touched_timestamp) or latest
  end

  return latest
end

local function assign_user_message_diff_pairs(checkpoints, messages, session_id)
  if not messages or #messages == 0 then
    return
  end

  local baseline = initial_baseline_for_messages(checkpoints, session_id, messages[1].timestamp)
  for _, message in ipairs(messages) do
    message.diff_pair = nil
    local latest = find_latest_checkpoint_for_user_message(checkpoints, message)
    local display_to = pair_display_target(checkpoints, message, latest)
    if display_to and baseline then
      message.diff_pair = { from = baseline, to = display_to }
      if latest then
        baseline = latest
      end
    elseif latest then
      -- If there is no earlier resume/turn checkpoint, use the old timestamp
      -- fallback rather than showing stale changes from another branch.
      local previous = find_previous_eligible_before(checkpoints, latest, message.timestamp)
      if previous then
        message.diff_pair = { from = previous, to = display_to or latest }
        baseline = latest
      end
    end
  end
end

local function find_pair_for_user_message(checkpoints, message)
  local latest = find_latest_checkpoint_for_user_message(checkpoints, message)
  if not latest then
    return nil, "No pi-rewind file-change checkpoint for this user message"
  end

  local previous = find_previous_eligible_before(checkpoints, latest, message.timestamp)
  if not previous then
    return nil, "No baseline checkpoint before this user message"
  end

  return { from = previous, to = pair_display_target(checkpoints, message, latest) or latest }, nil
end

local function find_latest_turn_pair(git_root, opts)
  opts = opts or {}
  local checkpoints, err = load_checkpoints(git_root)
  if not checkpoints then
    return nil, err
  end

  local latest = nil
  for i = #checkpoints, 1, -1 do
    local cp = checkpoints[i]
    local session_matches = not opts.session_id or cp.session_id == opts.session_id
    if session_matches and cp.kind == "turn" then
      latest = cp
      break
    end
  end

  if not latest then
    return nil, "No pi-rewind turn checkpoint found for this repository"
  end

  local previous = find_previous_checkpoint(checkpoints, latest)
  if not previous then
    return nil, "Found a pi-rewind turn checkpoint, but no previous checkpoint to diff against"
  end

  return { from = previous, to = latest }, nil
end

local function normalize_checkpoint_ref(token)
  token = trim(token)
  if token == "" then
    return nil
  end

  if has_prefix(token, REF_PREFIX) then
    return token
  end

  if has_prefix(token, "pi-checkpoints/") then
    return "refs/" .. token
  end

  local maybe_cp = parse_checkpoint_id(token)
  if maybe_cp.kind ~= "unknown" then
    return REF_PREFIX .. maybe_cp.id
  end

  return token
end

local function resolve_revision(git_root, token)
  local revision = normalize_checkpoint_ref(token)
  if not revision then
    return nil, "empty revision"
  end

  local resolved, err = git_one(git_root, { "rev-parse", "--verify", revision })
  if not resolved or resolved == "" then
    return nil, string.format("Could not resolve revision %q%s", token, err and (": " .. err) or "")
  end

  return resolved, nil
end

local function checkpoint_by_token(checkpoints, token)
  local normalized = normalize_checkpoint_ref(token)
  local wanted_id = normalized and strip_checkpoint_prefix(normalized) or strip_checkpoint_prefix(token)

  for _, cp in ipairs(checkpoints) do
    if cp.ref == normalized or cp.id == wanted_id or cp.sha == token then
      return cp
    end
  end

  return nil
end

local function find_pair_for_checkpoint(git_root, token)
  local checkpoints, err = load_checkpoints(git_root)
  if not checkpoints then
    return nil, err
  end

  local target = checkpoint_by_token(checkpoints, token)
  if not target then
    return nil, "Checkpoint not found: " .. token
  end

  local previous = find_previous_checkpoint(checkpoints, target)
  if not previous then
    return nil, "No previous checkpoint found for: " .. target.id
  end

  return { from = previous, to = target }, nil
end

local function parse_json_spec(spec)
  if not vim.json or spec:sub(1, 1) ~= "{" then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, spec)
  if not ok or type(decoded) ~= "table" then
    return nil
  end

  local from = decoded.from or decoded.fromRef or decoded.base or decoded.previous
  local to = decoded.to or decoded.toRef or decoded.target or decoded.current
  local checkpoint = decoded.checkpoint or decoded.id or decoded.ref

  if from and to then
    return { from = tostring(from), to = tostring(to) }
  end
  if checkpoint then
    return { checkpoint = tostring(checkpoint) }
  end

  return nil
end

local function parse_text_spec(spec)
  spec = trim(spec)
  if spec == "" or spec == "auto" then
    return { auto = true }
  end

  local json_spec = parse_json_spec(spec)
  if json_spec then
    return json_spec
  end

  local from, to = spec:match("^(.+)%.%.(.+)$")
  if from and to then
    return { from = trim(from), to = trim(to) }
  end

  local parts = vim.split(spec:gsub(",", " "), "%s+", { trimempty = true })
  if #parts >= 2 then
    return { from = parts[1], to = parts[2] }
  end

  if #parts == 1 then
    return { checkpoint = parts[1] }
  end

  return nil
end

local function status_count(status_result)
  status_result = status_result or {}
  return #(status_result.unstaged or {}) + #(status_result.staged or {}) + #(status_result.conflicts or {})
end

local function focus_file_for(git_root, opts)
  opts = opts or {}
  local session = current_codediff_session(opts.tabpage)
  if session and session.explorer and session.explorer.current_file_path then
    return session.explorer.current_file_path
  end

  local current_name = vim.api.nvim_buf_get_name(0)
  if current_name ~= "" then
    local root = git_root:gsub("[/\\]$", "")
    local normalized = current_name:gsub("\\", "/")
    if has_prefix(normalized, root .. "/") then
      return normalized:sub(#root + 2)
    end
  end

  return nil
end

local function create_info_buffer(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].swapfile = false
  pcall(vim.api.nvim_buf_set_name, bufnr, "CodeDiff Pi Rewind [" .. bufnr .. "]")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
  return bufnr
end

local function show_info(lines, opts)
  opts = opts or {}
  local tabpage = opts.tabpage or vim.api.nvim_get_current_tabpage()
  local session = current_codediff_session(tabpage)
  local bufnr = create_info_buffer(lines)

  if session then
    if vim.api.nvim_tabpage_is_valid(tabpage) then
      pcall(vim.api.nvim_set_current_tabpage, tabpage)
    end
    if session.layout == "inline" then
      require("codediff.ui.view.inline_view").show_welcome(tabpage, bufnr)
    else
      require("codediff.ui.view.side_by_side").show_welcome(tabpage, bufnr)
    end
    return true
  end

  vim.cmd("tabnew")
  vim.api.nvim_win_set_buf(0, bufnr)
  return true
end

local function default_no_diff_lines(message)
  local lines = {
    "No file changes for this Pi user message.",
  }

  if message and message.text then
    table.insert(lines, "")
    table.insert(lines, truncate_text(message.text, 240))
  end

  return lines
end

local function path_is_within(path, root)
  if not path or not root or root == "" then
    return false
  end
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

local function path_matches_any(path, roots)
  path = normalize_repo_path(path)
  if not path then
    return false
  end

  for _, root in ipairs(roots or {}) do
    root = normalize_repo_path(root)
    if root and (path_is_within(path, root) or path_is_within(root, path)) then
      return true
    end
  end

  return false
end

local function filter_status_result(status_result, only_paths)
  if not only_paths or #only_paths == 0 then
    return status_result
  end

  local function keep(file)
    return path_matches_any(file.path, only_paths) or path_matches_any(file.old_path, only_paths)
  end

  local filtered = {
    unstaged = {},
    staged = {},
    conflicts = {},
  }

  for _, file in ipairs(status_result.unstaged or {}) do
    if keep(file) then
      table.insert(filtered.unstaged, file)
    end
  end
  for _, file in ipairs(status_result.staged or {}) do
    if keep(file) then
      table.insert(filtered.staged, file)
    end
  end
  for _, file in ipairs(status_result.conflicts or {}) do
    if keep(file) then
      table.insert(filtered.conflicts, file)
    end
  end

  return filtered
end

local function diff_filter_key(git_root, from_revision, to_revision)
  git_root = tostring(git_root or ""):gsub("/+$", "")
  return table.concat({ git_root, tostring(from_revision or ""), tostring(to_revision or "") }, "\0")
end

local function ensure_git_diff_filter_patch()
  if git_diff_filter_patched then
    return
  end

  local ok, git = pcall(require, "codediff.core.git")
  if not ok or type(git.get_diff_revisions) ~= "function" then
    return
  end

  if git._pi_rewind_original_get_diff_revisions then
    git_diff_filter_patched = true
    return
  end

  local original_get_diff_revisions = git.get_diff_revisions
  git._pi_rewind_original_get_diff_revisions = original_get_diff_revisions
  git.get_diff_revisions = function(rev1, rev2, git_root, callback)
    local filter = diff_status_filters[diff_filter_key(git_root, rev1, rev2)]
    if not filter or type(callback) ~= "function" then
      return original_get_diff_revisions(rev1, rev2, git_root, callback)
    end

    return original_get_diff_revisions(rev1, rev2, git_root, function(err, status_result)
      if not err and status_result then
        local ok_filter, filtered = pcall(filter, status_result)
        if ok_filter and filtered then
          status_result = filtered
        end
      end
      callback(err, status_result)
    end)
  end

  git_diff_filter_patched = true
end

local function register_diff_status_filter(git_root, from_revision, to_revision, only_paths)
  if not only_paths or #only_paths == 0 then
    return
  end

  local paths = vim.deepcopy(only_paths)
  diff_status_filters[diff_filter_key(git_root, from_revision, to_revision)] = function(status_result)
    return filter_status_result(status_result, paths)
  end
  ensure_git_diff_filter_patch()
end

local function open_explorer(git_root, from_revision, to_revision, opts)
  opts = opts or {}
  local from_sha, from_err = resolve_revision(git_root, from_revision)
  if not from_sha then
    notify(from_err, vim.log.levels.ERROR)
    return false
  end

  local to_sha, to_err = resolve_revision(git_root, to_revision)
  if not to_sha then
    notify(to_err, vim.log.levels.ERROR)
    return false
  end

  register_diff_status_filter(git_root, from_sha, to_sha, opts.only_paths)

  local git = require("codediff.core.git")
  git.get_diff_revisions(from_sha, to_sha, git_root, function(err, status_result)
    vim.schedule(function()
      if err then
        notify("Failed to compute checkpoint diff: " .. err, vim.log.levels.ERROR)
        return
      end

      status_result = filter_status_result(status_result, opts.only_paths)

      if status_count(status_result) == 0 then
        show_info(opts.no_diff_lines or { "No file changes between the selected pi-rewind checkpoints." }, opts)
        notify("No file changes between the selected pi-rewind checkpoints", vim.log.levels.INFO)
        return
      end

      local view = require("codediff.ui.view")
      local current_tab = opts.tabpage or vim.api.nvim_get_current_tabpage()
      local old_session = current_codediff_session(current_tab)
      local layout = opts.layout or (old_session and old_session.layout) or nil
      local replace_current = old_session ~= nil and opts.replace_current ~= false

      local session_config = {
        mode = "explorer",
        git_root = git_root,
        original_path = "",
        modified_path = "",
        original_revision = from_sha,
        modified_revision = to_sha,
        layout = layout,
        explorer_data = {
          status_result = status_result,
          focus_file = focus_file_for(git_root, opts),
        },
      }

      view.create(session_config, "")

      if replace_current then
        local new_tab = vim.api.nvim_get_current_tabpage()
        if new_tab ~= current_tab and vim.api.nvim_tabpage_is_valid(current_tab) then
          -- Close the previous CodeDiff tab by number without briefly entering it.
          -- Entering the newly-created placeholder diff tab before its scheduled
          -- initial file selection can make codediff resume an empty diff result
          -- (`{}`), which crashes render_diff on `ipairs(lines_diff.changes)`.
          local old_tabnr = vim.api.nvim_tabpage_get_number(current_tab)
          pcall(vim.cmd, old_tabnr .. "tabclose")
          if vim.api.nvim_tabpage_is_valid(new_tab) then
            pcall(vim.api.nvim_set_current_tabpage, new_tab)
          end
        end
      end

      if opts.label then
        notify(opts.label, vim.log.levels.INFO)
      end
    end)
  end)

  return true
end

local function describe_pair(pair)
  local to = pair and pair.to
  if not to then
    return "Opened pi-rewind checkpoint diff"
  end

  local turn = to.turn_index and to.turn_index > 0 and ("turn " .. to.turn_index) or "last turn"
  if to.description and to.description ~= "" then
    return "Opened pi-rewind " .. turn .. ": " .. to.description
  end

  return "Opened pi-rewind " .. turn .. " diff"
end

function M.open_pair(opts)
  opts = opts or {}
  local git_root = resolve_git_root(opts)
  if not git_root then
    notify("Not in a git repository", vim.log.levels.ERROR)
    return false
  end

  if not opts.from or not opts.to then
    notify("open_pair requires from and to revisions", vim.log.levels.ERROR)
    return false
  end

  return open_explorer(git_root, opts.from, opts.to, opts)
end

function M.open_spec(spec, opts)
  opts = opts or {}
  local git_root = resolve_git_root(opts)
  if not git_root then
    notify("Not in a git repository", vim.log.levels.ERROR)
    return false
  end

  local parsed = parse_text_spec(spec)
  if not parsed then
    notify("Paste from..to, two refs, a checkpoint id, or a JSON object with from/to", vim.log.levels.ERROR)
    return false
  end

  if parsed.auto then
    return M.open_last_turn(vim.tbl_extend("force", opts, { prompt_on_fail = false }))
  end

  if parsed.from and parsed.to then
    return open_explorer(git_root, parsed.from, parsed.to, vim.tbl_extend("force", opts, {
      label = "Opened pasted pi-rewind checkpoint diff",
    }))
  end

  if parsed.checkpoint then
    local pair, err = find_pair_for_checkpoint(git_root, parsed.checkpoint)
    if not pair then
      notify(err, vim.log.levels.ERROR)
      return false
    end

    return open_explorer(git_root, pair.from.ref, pair.to.ref, vim.tbl_extend("force", opts, {
      label = describe_pair(pair),
    }))
  end

  notify("Could not understand pi-rewind checkpoint spec", vim.log.levels.ERROR)
  return false
end

local function format_user_message_label(message)
  local status = message.diff_status == "diff" and "[diff]" or "[no diff]"
  local text = truncate_text(message.text ~= "" and message.text or "(empty user message)", 220)
  return string.format("%-9s %s", status, text)
end

function M.open_user_message_diff(message, opts)
  opts = opts or {}
  if not message then
    notify("No Pi user message selected", vim.log.levels.WARN)
    return false
  end

  local git_root = resolve_git_root(opts)
  if not git_root then
    notify("Not in a git repository", vim.log.levels.ERROR)
    return false
  end

  local pair = message.diff_pair
  local pair_err
  if not pair then
    local checkpoints, err = load_checkpoints(git_root)
    if not checkpoints then
      notify(err or "failed to load pi-rewind checkpoints", vim.log.levels.ERROR)
      return false
    end

    message.session_id = message.session_id or latest_session_id_from_checkpoints(checkpoints, opts)
    if not message.session_id then
      notify("Could not identify a Pi session for this repository", vim.log.levels.ERROR)
      return false
    end

    pair, pair_err = find_pair_for_user_message(checkpoints, message)
  end

  if not pair then
    show_info(default_no_diff_lines(message), opts)
    notify(pair_err or "No file changes for this Pi user message", vim.log.levels.INFO)
    return false
  end

  return open_explorer(git_root, pair.from.ref, pair.to.ref, vim.tbl_extend("force", opts, {
    label = "Opened Pi user message diff: " .. truncate_text(message.text, 80),
    no_diff_lines = default_no_diff_lines(message),
    only_paths = message.only_paths,
  }))
end

function M.pick_user_message(opts)
  opts = opts or {}
  local git_root = resolve_git_root(opts)
  if not git_root then
    notify("Not in a git repository", vim.log.levels.ERROR)
    return false
  end

  local checkpoints, err = load_checkpoints(git_root)
  if not checkpoints then
    notify(err or "failed to load pi-rewind checkpoints", vim.log.levels.ERROR)
    return false
  end

  local session_id = latest_session_id_from_checkpoints(checkpoints, opts)
  if not session_id then
    notify("No pi-rewind checkpoints found for this repository", vim.log.levels.WARN)
    return false
  end

  local messages = load_session_user_messages(session_id)
  if not messages then
    notify("No Pi session user messages found; opening latest turn diff", vim.log.levels.WARN)
    return M.open_last_turn(opts)
  end

  assign_user_message_diff_pairs(checkpoints, messages, session_id)

  local items = {}
  for i = #messages, 1, -1 do
    local message = messages[i]
    message.diff_status = message.diff_pair and "diff" or "no diff"
    table.insert(items, message)
  end

  vim.ui.select(items, {
    prompt = "Pi user-message diff (latest first):",
    format_item = format_user_message_label,
    snacks = {
      layout = {
        preset = "select",
        layout = {
          width = 0.9,
          min_width = 100,
          max_width = 999,
        },
      },
    },
  }, function(choice)
    if not choice then
      return
    end

    M.open_user_message_diff(choice, opts)
  end)

  return true
end

function M.prompt_last_turn(opts)
  opts = opts or {}
  vim.ui.input({
    prompt = "Pi checkpoint spec (empty=auto, or from..to / checkpoint id): ",
  }, function(input)
    if input == nil then
      return
    end

    if trim(input) == "" then
      M.open_last_turn(vim.tbl_extend("force", opts, { prompt_on_fail = false }))
      return
    end

    M.open_spec(input, opts)
  end)
end

function M.open_last_turn(opts)
  opts = opts or {}
  local git_root = resolve_git_root(opts)
  if not git_root then
    notify("Not in a git repository", vim.log.levels.ERROR)
    return false
  end

  local pair, err = find_latest_turn_pair(git_root, opts)
  if not pair then
    if opts.prompt_on_fail ~= false then
      notify((err or "No automatic checkpoint pair found") .. "; paste checkpoint refs instead", vim.log.levels.WARN)
      M.prompt_last_turn(opts)
    else
      notify(err or "No automatic checkpoint pair found", vim.log.levels.WARN)
    end
    return false
  end

  return open_explorer(git_root, pair.from.ref, pair.to.ref, vim.tbl_extend("force", opts, {
    label = describe_pair(pair),
  }))
end

return M
