local M = {}

-- Function to get file information and format it as a prompt
-- @param file_path string: Path to the file relative to cwd
-- @return table: Contains path, content, and formatted prompt
function M.get_project_file(file_path)
  -- Get the absolute path by joining cwd with the relative path
  local cwd = vim.fn.getcwd()
  local abs_path = cwd .. "/" .. file_path

  -- Check if file exists
  if vim.fn.filereadable(abs_path) == 0 then
    return {
      path = abs_path,
      content = nil,
      prompt = "**Error**: File not found: " .. abs_path,
    }
  end

  -- Read file content
  local content = table.concat(vim.fn.readfile(abs_path), "\n")

  -- Format the prompt in markdown
  local prompt = "**filePath**: " .. abs_path .. "\n\n**content**:\n```\n" .. content .. "\n```"

  return {
    path = abs_path,
    content = content,
    prompt = prompt,
  }
end

return M
