return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "MeanderingProgrammer/render-markdown.nvim", ft = { "markdown", "codecompanion" } },
  },
  event = "VeryLazy",
  opts = {
    opts = {
      log_level = "DEBUG", -- TRACE|DEBUG|ERROR|INFO
    },
    display = {
      diff = {
        provider = "mini_diff",
      },
      chat = {
        show_settings = true,
      },
    },
    adapters = {
      anthropic = function()
        return require("codecompanion.adapters").extend("anthropic", {
          env = {
            api_key = "ANTHROPIC_API_KEY",
          },
          schema = {
            model = {
              default = "claude-3-7-sonnet-20250219",
            },
            extended_thinking = {
              default = false,
            },
          },
        })
      end,
    },
    strategies = {
      chat = {
        adapter = "anthropic",
        roles = {
          llm = function(adapter)
            return "CodeCompanion (" .. adapter.formatted_name .. ")"
          end,
          user = "Me",
        },
        keymaps = {
          close = {
            modes = {
              n = "q",
            },
            index = 3,
            callback = "keymaps.close",
            description = "Close Chat",
          },
          stop = {
            modes = {
              n = "<C-c>",
            },
            index = 4,
            callback = "keymaps.stop",
            description = "Stop Request",
          },
        },
      },
      inline = {
        adapter = "anthropic",
      },
    },
  },
}
