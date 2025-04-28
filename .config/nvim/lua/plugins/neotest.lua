return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    "nvim-neotest/neotest-jest",
    "marilari88/neotest-vitest",
    "nvim-neotest/neotest-plenary",
  },
  event = "VeryLazy",
  keys = {
    {
      "<leader>tt",
      function()
        require("neotest").summary.open()
        vim.defer_fn(function()
          require("neotest").run.run(vim.fn.expand("%"))
        end, 150)
      end,
      mode = { "n" },
    },
  },
  config = function()
    require("neotest").setup({
      discovery = {
        enabled = false,
      },
      adapters = {
        require("neotest-jest")({
          jestCommand = function(path)
            local test_command = require("utils.get_test_command")

            return test_command.getTestCommand(path, "jest")
          end,
          jestConfigFile = function(file)
            local util = require("utils.util")

            local nearest_project_json_path = util.find_project_json_ancestor(file)
            local project_path = util.path.join(nearest_project_json_path, "jest.config.ts")

            if util.path.exists(project_path) then
              return project_path
            end

            local nearest_package_json_path = util.find_package_json_ancestor(file)
            local path = util.path.join(nearest_package_json_path, "jest.config.ts")

            return path
          end,
          env = { CI = true },
          cwd = function(path)
            return vim.fn.getcwd()
          end,
        }),
        require("neotest-vitest")({
          vitestCommand = function(path)
            local test_command = require("utils.get_test_command")
            local command = test_command.getTestCommand(path, "vitest")

            return command
          end,
          vitestConfigFile = function(path)
            local test_config_file = require("utils.get_test_config_file")
            local config_file_path = test_config_file.getVitestConfig(path)

            return config_file_path
          end,
          cwd = function(path)
            local app_specific_vitest = require("utils.app_specific_vitest")
            local util = require("utils.util")
            local cwd = vim.fn.getcwd()

            for _, path_pattern in ipairs(app_specific_vitest) do
              if string.find(path, path_pattern) then
                return cwd .. "/" .. util.remove_parts(path_pattern)
              end
            end

            return cwd
          end,
        }),
        require("neotest-plenary"),
      },
    })
  end,
}
