local pos = {
  row = 1,
  col = 1,
}

local config = {
  highlight = {
    focus = "DentakuFocus",
    flash = "DentakuFlash",
  },
  flash = {
    timeout = 80,
  },
}

local DENTAKU_MIN_ROW = 1
local DENTAKU_MAX_ROW = 5
local DENTAKU_MIN_COLUMN = 1
local DENTAKU_MAX_COLUMN = 4

local DENTAKU_HEIGHT = 35
local DENTAKU_WIDTH = 59

local OUTPUT_WIDTH = DENTAKU_WIDTH - 6

local guicursor_saved

local formula = {}

local bufnr
local winid

local before_key

local match_focus_id = nil

local win_config = {
  row = (math.ceil(vim.o.lines - DENTAKU_HEIGHT) / 2) - 1,
  col = (math.ceil(vim.o.columns - DENTAKU_WIDTH) / 2) - 1,
  relative = "editor",
  height = DENTAKU_HEIGHT,
  width = DENTAKU_WIDTH,
  bufpos = { 100, 10 },
  border = "single",
  style = "minimal",
  -- title = " Dentaku ",
  -- title_pos = "center",
}

vim.api.nvim_set_hl(0, "DentakuFocus", { link = "IncSearch" })
vim.api.nvim_set_hl(0, "DentakuFlash", { link = "Search" })

local ROWS = {
  " ┌-------------------------------------------------------┐ ",
  " |                                                       | ",
  " +-------------------------------------------------------+ ",
  " |                                                       | ",
  " +-------------+-------------+-------------+-------------+ ",
  " |             |             |             |             | ",
  " |             |             |             |             | ",
  " |      CE     |      C      |     DEL     |      /      | ",
  " |             |             |             |             | ",
  " |             |             |             |             | ",
  " +-------------+-------------+-------------+-------------+ ",
  " |             |             |             |             | ",
  " |             |             |             |             | ",
  " |      7      |      8      |      9      |      X      | ",
  " |             |             |             |             | ",
  " |             |             |             |             | ",
  " +-------------+-------------+-------------+-------------+ ",
  " |             |             |             |             | ",
  " |             |             |             |             | ",
  " |      4      |      5      |      6      |      -      | ",
  " |             |             |             |             | ",
  " |             |             |             |             | ",
  " +-------------+-------------+-------------+-------------+ ",
  " |             |             |             |             | ",
  " |             |             |             |             | ",
  " |      1      |      2      |      3      |      +      | ",
  " |             |             |             |             | ",
  " |             |             |             |             | ",
  " +-------------+-------------+-------------+-------------+ ",
  " |             |             |             |             | ",
  " |             |             |             |             | ",
  " |     +/-     |      0      |      .      |      =      | ",
  " |             |             |             |             | ",
  " |             |             |             |             | ",
  " +-------------+-------------+-------------+-------------+ ",
}

local function setpos() vim.fn.setpos(".", { bufnr, DENTAKU_HEIGHT, (DENTAKU_WIDTH + 1) / 2, 0 }) end

local function focus_key(row, col)
  if match_focus_id ~= nil then
    vim.fn.matchdelete(match_focus_id)
    match_focus_id = nil
  end
  local c = col - 1
  local r = row - 1

  local row1 = string.format([[\%%>%dc\%%<%dc\%%%dl]], (2 + c * 14), (16 + c * 14), (5 + r * 6))
  local row2 = string.format([[\%%>%dc\%%<%dc\%%%dl]], (2 + c * 14), (16 + c * 14), (11 + r * 6))

  local col1 = string.format([[\%%>%dl\%%<%dl\%%%dc]], (5 + r * 6), (11 + r * 6), (2 + c * 14))
  local col2 = string.format([[\%%>%dl\%%<%dl\%%%dc]], (5 + r * 6), (11 + r * 6), (16 + c * 14))

  local pattern = row1 .. [[\|]] .. row2 .. [[\|]] .. col1 .. [[\|]] .. col2
  match_focus_id = vim.fn.matchadd(config.highlight.focus, pattern, 100, -1)
end

local function flash_key(row, col)
  local c = col - 1
  local r = row - 1

  local pattern = string.format([[\%%>%dc\%%<%dc\%%>%dl\%%<%dl]], (2 + c * 14), (16 + c * 14), (5 + r * 6), (11 + r * 6))
  local match_flash_id = vim.fn.matchadd(config.highlight.flash, pattern, 100, -1)
  vim.defer_fn(function()
    if #vim.fn.getwininfo(winid) ~= 0 then
      vim.fn.matchdelete(match_flash_id, winid)
    end
  end, config.flash.timeout)
end

local function last_formula_is_num()
  if formula[#formula]:match("^%--%d") then
    return true
  end

  return false
end

local function last_formula_is_operator()
  if formula[#formula]:match("^[+-/*]$") then
    return true
  end

  return false
end

local function update_formula()
  vim.opt_local.modifiable = true

  local text = table.concat(formula, " "):sub(-OUTPUT_WIDTH)
  vim.api.nvim_buf_set_text(bufnr, 1, 3, 1, DENTAKU_WIDTH - 3, { string.format("%" .. OUTPUT_WIDTH .. "s", text) })

  vim.opt_local.modifiable = false
end

local function update_result()
  local f
  if last_formula_is_operator() then
    f = { unpack(formula, 1, #formula - 1) }
  else
    f = formula
  end
  vim.opt_local.modifiable = true
  local result = assert(loadstring("return " .. table.concat(f, " ")))()
  vim.api.nvim_buf_set_text(bufnr, 3, 3, 3, DENTAKU_WIDTH - 3, { string.format("%" .. OUTPUT_WIDTH .. "s", result) })

  vim.opt_local.modifiable = false
end

local function exist_window()
  if #vim.fn.getwininfo(winid) > 0 then
    return true
  end

  return false
end

local function move_focus(direction)
  if direction == "up" and pos.row ~= DENTAKU_MIN_ROW then
    pos.row = pos.row - 1
  elseif direction == "down" and pos.row ~= DENTAKU_MAX_ROW then
    pos.row = pos.row + 1
  elseif direction == "left" and pos.col ~= DENTAKU_MIN_COLUMN then
    pos.col = pos.col - 1
  elseif direction == "right" and pos.col ~= DENTAKU_MAX_COLUMN then
    pos.col = pos.col + 1
  end

  focus_key(pos.row, pos.col)
end

local function clear_all()
  formula = { "0" }
  update_result()
  update_formula()
end

local function clear_only_last()
  if before_key == "=" then
    clear_all()
  elseif last_formula_is_operator() then
    table.insert(formula, "0")
  else
    formula[#formula] = "0"
  end

  update_formula()
end

local function num(n)
  if before_key == "=" then
    clear_all()
  end

  if last_formula_is_num() then
    if formula[#formula] == "0" then
      formula[#formula] = n
    else
      formula[#formula] = formula[#formula] .. n
    end
  else
    table.insert(formula, n)
  end

  update_formula()
end

local function dot()
  if before_key == "=" then
    formula = { "0." }
    update_formula()
    update_result()
  elseif last_formula_is_num() and (not formula[#formula]:match("%.")) then
    formula[#formula] = formula[#formula] .. "."
    update_formula()
  end
end

local function equal()
  if before_key == "=" then
    -- {"5", "+", "10"}            -> {"5", "+", "10", "+", "10" }
    -- {"5", "+", "20", "-", "10"} -> {"5", "+", "20", "-", "10", "-", "10"}
    if #formula > 2 and formula[#formula - 1]:match("^[+-/*]$") then
      table.insert(formula, formula[#formula - 1])
      table.insert(formula, formula[#formula - 1])
    end
  else
    -- {"5", "+"}            -> {"5", "+", "(5)"}
    -- {"5", "+", "20", "-"} -> {"5", "+", "20", "-", "(5 + 20)"}
    if #formula > 1 and last_formula_is_operator() then
      table.insert(formula, "(" .. table.concat({ unpack(formula, 1, #formula - 1) }, " ") .. ")")
    end
  end

  update_formula()
  update_result()
end

local function del()
  if not last_formula_is_num() then
    return
  end

  if #formula[#formula] == 1 then
    formula[#formula] = "0"
  elseif formula[#formula]:match("^-%d$") then
    formula[#formula] = "0"
  else
    formula[#formula] = formula[#formula]:sub(1, -2)
  end

  update_formula()
end

local function operator(o)
  if last_formula_is_operator() then
    formula[#formula] = o
  else
    table.insert(formula, o)
  end

  update_formula()
end

local function sign()
  if before_key == "=" then
    local result = assert(loadstring("return " .. table.concat(formula, " ")))()
    for k, _ in pairs(formula) do
      formula[k] = nil
    end
    formula[1] = "-" .. tostring(result)
    update_result()
  elseif last_formula_is_num() and formula[#formula] ~= "0" then
    if formula[#formula]:match("^-") then
      formula[#formula] = formula[#formula]:sub(2, -1)
    else
      formula[#formula] = "-" .. formula[#formula]
    end
  end

  update_formula()
end

local keys = {
  ["CE"] = {
    func = function() clear_only_last() end,
    pos = { row = 1, col = 1 },
  },
  ["C"] = {
    func = function() clear_all() end,
    pos = { row = 1, col = 2 },
  },
  ["DEL"] = {
    func = function() del() end,
    pos = { row = 1, col = 3 },
  },
  ["/"] = {
    func = function() operator("/") end,
    pos = { row = 1, col = 4 },
  },

  ["7"] = {
    func = function() num("7") end,
    pos = { row = 2, col = 1 },
  },
  ["8"] = {
    func = function() num("8") end,
    pos = { row = 2, col = 2 },
  },
  ["9"] = {
    func = function() num("9") end,
    pos = { row = 2, col = 3 },
  },
  ["*"] = {
    func = function() operator("*") end,
    pos = { row = 2, col = 4 },
  },
  ["X"] = {
    func = function() operator("*") end,
    pos = { row = 2, col = 4 },
  },

  ["4"] = {
    func = function() num("4") end,
    pos = { row = 3, col = 1 },
  },
  ["5"] = {
    func = function() num("5") end,
    pos = { row = 3, col = 2 },
  },
  ["6"] = {
    func = function() num("6") end,
    pos = { row = 3, col = 3 },
  },
  ["-"] = {
    func = function() operator("-") end,
    pos = { row = 3, col = 4 },
  },

  ["1"] = {
    func = function() num("1") end,
    pos = { row = 4, col = 1 },
  },
  ["2"] = {
    func = function() num("2") end,
    pos = { row = 4, col = 2 },
  },
  ["3"] = {
    func = function() num("3") end,
    pos = { row = 4, col = 3 },
  },
  ["+"] = {
    func = function() operator("+") end,
    pos = { row = 4, col = 4 },
  },

  ["SIGN"] = {
    func = function() sign() end,
    pos = { row = 5, col = 1 },
  },
  ["0"] = {
    func = function() num("0") end,
    pos = { row = 5, col = 2 },
  },
  ["."] = {
    func = function() dot() end,
    pos = { row = 5, col = 3 },
  },
  ["="] = {
    func = function() equal() end,
    pos = { row = 5, col = 4 },
  },
}

local push_key = function(key)
  if keys[key] == nil then
    vim.api.nvim_echo({ { "dentaku.nvim: Invalid key", "ErrorMsg" } }, true, {})
  end

  flash_key(keys[key].pos.row, keys[key].pos.col)
  keys[key].func()
  before_key = key
end

local function push_focus_key()
  for k, v in pairs(keys) do
    if v.pos.row == pos.row and v.pos.col == pos.col then
      push_key(k)
      break
    end
  end
end

local function map(lhs, rhs) vim.keymap.set("n", lhs, rhs, { buffer = true }) end

local function set_keymap()
  map("<Up>", function() move_focus("up") end)
  map("<Down>", function() move_focus("down") end)
  map("<Left>", function() move_focus("left") end)
  map("<Right>", function() move_focus("right") end)

  map("k", function() move_focus("up") end)
  map("j", function() move_focus("down") end)
  map("h", function() move_focus("left") end)
  map("l", function() move_focus("right") end)

  map(".", function() push_key(".") end)
  map("=", function() push_key("=") end)
  map("1", function() push_key("1") end)
  map("2", function() push_key("2") end)
  map("3", function() push_key("3") end)
  map("4", function() push_key("4") end)
  map("5", function() push_key("5") end)
  map("6", function() push_key("6") end)
  map("7", function() push_key("7") end)
  map("8", function() push_key("8") end)
  map("9", function() push_key("9") end)
  map("0", function() push_key("0") end)
  map("+", function() push_key("+") end)
  map("-", function() push_key("-") end)
  map("*", function() push_key("*") end)
  map("/", function() push_key("/") end)

  -- same "*"
  map("X", function() push_key("*") end)

  map("c", function() push_key("CE") end)
  map("C", function() push_key("C") end)
  map("<BS>", function() push_key("DEL") end)
  map("s", function() push_key("SIGN") end)

  map("<CR>", function() push_focus_key() end)

  map("q", "<CMD>bw!<CR>")
end

local function set_option()
  vim.opt_local.filetype = "dentaku"
  vim.opt_local.buftype = "nofile"
  vim.opt_local.modifiable = false
  vim.opt_local.scrolloff = 999
end

local function run()
  if exist_window() then
    vim.fn.win_gotoid(winid)
    return
  end

  pos.row = 1
  pos.col = 1

  before_key = "0"

  match_focus_id = nil
  winid = nil

  guicursor_saved = vim.opt.guicursor:get()

  bufnr = vim.api.nvim_create_buf(false, true)

  local group_id = vim.api.nvim_create_augroup("dentaku_augroup", {})
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "TabLeave", "CmdwinLeave", "CmdlineLeave" }, {
    group = group_id,
    buffer = bufnr,
    callback = function() vim.opt.guicursor:append("a:hor1") end,
  })

  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "TabLeave", "CmdwinEnter", "CmdlineEnter", "VimLeave" }, {
    group = group_id,
    buffer = bufnr,
    callback = function() vim.opt.guicursor = guicursor_saved end,
  })

  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "TabLeave" }, {
    group = group_id,
    buffer = bufnr,
    callback = function() vim.cmd("bw!") end,
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group_id,
    buffer = bufnr,
    callback = function() setpos() end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = group_id,
    buffer = bufnr,
    callback = function()
      win_config.row = (math.ceil(vim.o.lines - DENTAKU_HEIGHT) / 2) - 1
      win_config.col = (math.ceil(vim.o.columns - DENTAKU_WIDTH) / 2) - 1
      vim.api.nvim_win_set_config(winid, win_config)
    end,
  })

  win_config.row = (math.ceil(vim.o.lines - DENTAKU_HEIGHT) / 2) - 1
  win_config.col = (math.ceil(vim.o.columns - DENTAKU_WIDTH) / 2) - 1

  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, ROWS)
  winid = vim.api.nvim_open_win(bufnr, true, win_config)

  vim.cmd("clearjumps")

  set_keymap()
  set_option()

  clear_all()

  update_result()
  update_formula()

  setpos()
  focus_key(pos.row, pos.col)
end
local function setup(override_config) config = vim.tbl_extend("force", config, override_config) end

local M = {
  run = run,

  move_focus = move_focus,
  push_focus_key = push_focus_key,
  push_key = push_key,
  setup = setup,
}

return M
