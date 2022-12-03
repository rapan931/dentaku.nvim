vim.api.nvim_create_user_command("Dentaku", function() require("dentaku").run() end, {})
