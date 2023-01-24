local helper = require("vusted.helper")
local asserts = require("vusted.assert").asserts

local dentaku = helper.require("dentaku")
local root = helper.find_plugin_root("dentaku")

function helper.setup() end

function helper.before_each()
  vim.cmd("luafile " .. root .. "/plugin/*.lua")
  vim.cmd("Dentaku")
end

function helper.after_each()
  helper.cleanup()
  helper.cleanup_loaded_modules("dentaku")
end

local function trim_line(line_start, line_end)
  local str = vim.api.nvim_buf_get_lines(0, line_start, line_end, false)[1]
  local i = #str:match("^[ |]*")
  local n = #str:match(" | $")

  return str:sub(i + 1, #str - n)
end

asserts.create("formula"):register_same(function() return trim_line(1, 2) end)
asserts.create("result"):register_same(function() return trim_line(3, 4) end)

local function split(str, sep)
  local ret = {}
  for s in str:gmatch("([^" .. sep .. "]+)") do
    table.insert(ret, s)
  end
  return ret
end

describe("Dentaku", function()
  setup(helper.setup)
  before_each(helper.before_each)
  after_each(helper.after_each)

  describe("normal", function()
    local it_1 = "1 + 1 + 1 ="
    it(it_1, function()
      for _, v in ipairs(split(it_1, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("1 + 1 + 1")
      assert.result("3")
    end)

    local it_2 = "2 * 3 * 4 = 3"
    it(it_2, function()
      for _, v in ipairs(split(it_2, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("3")
      assert.result("0")
    end)

    local it_3 = "4 + 6 + 8 + ="
    it(it_3, function()
      for _, v in ipairs(split(it_3, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("4 + 6 + 8 + (4 + 6 + 8)")
      assert.result("36")
    end)

    local it_4 = "1 + 2 + 3 +"
    it(it_4, function()
      for _, v in ipairs(split(it_4, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("1 + 2 + 3 +")
      assert.result("0")
    end)

    local it_5 = "1 / 2 + 3 * 8 . 3 ="
    it(it_5, function()
      for _, v in ipairs(split(it_5, " ")) do
        dentaku.push_key(v)
      end
      -- ( 1 / 2 ) + (3 * 8.3) = 25.4
      assert.formula("1 / 2 + 3 * 8.3")
      assert.result("25.4")
    end)

    local it_6 = "1 + 2 + 3 + = = "
    it(it_6, function()
      for _, v in ipairs(split(it_6, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("1 + 2 + 3 + (1 + 2 + 3) + (1 + 2 + 3)")
      assert.result("18")
    end)

    local it_7 = "1 + 2 + 3 = = ="
    it(it_7, function()
      for _, v in ipairs(split(it_7, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("1 + 2 + 3 + 3 + 3")
      assert.result("12")
    end)

    local it_8 = "2 + + - / * 5 ="
    it(it_8, function()
      for _, v in ipairs(split(it_8, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("2 * 5")
      assert.result("10")
    end)
  end)

  describe("DOT", function()
    local it_1 = "1 . 1"
    it(it_1, function()
      for _, v in ipairs(split(it_1, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("1.1")
      assert.result("0")
    end)

    local it_2 = "1 + 2 + 3 = ."
    it(it_2, function()
      for _, v in ipairs(split(it_2, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("0.")
      assert.result("0")
    end)

    local it_3 = "1 . 1 . "
    it(it_3, function()
      for _, v in ipairs(split(it_3, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("1.1")
      assert.result("0")
    end)

    local it_4 = "1 + 3 . 2 ="
    it(it_4, function()
      for _, v in ipairs(split(it_4, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("1 + 3.2")
      assert.result("4.2")
    end)

    local it_5 = "3 + 5 + 7 + = ."
    it(it_5, function()
      for _, v in ipairs(split(it_5, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("0.")
      assert.result("0")
    end)
  end)

  describe("SIGN", function()
    local it_1 = "SIGN"
    it(it_1, function()
      for _, v in ipairs(split(it_1, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("0")
      assert.result("0")
    end)

    local it_2 = "8 SIGN - 6 SIGN ="
    it(it_2, function()
      for _, v in ipairs(split(it_2, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("-8 - -6")
      assert.result("-2")
    end)

    local it_3 = "1 + 2 + 3 = SIGN"
    it(it_3, function()
      for _, v in ipairs(split(it_3, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("-6")
      assert.result("-6")
    end)

    local it_4 = "1 + 2 + 3 = SIGN ="
    it(it_4, function()
      for _, v in ipairs(split(it_4, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("-6")
      assert.result("-6")
    end)

    local it_5 = "1 + 2 + 3 = SIGN + 8 ="
    it(it_5, function()
      for _, v in ipairs(split(it_5, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("-6 + 8")
      assert.result("2")
    end)

    local it_6 = "1 SIGN SIGN + 2 ="
    it(it_6, function()
      for _, v in ipairs(split(it_6, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("1 + 2")
      assert.result("3")
    end)

    -- TODO: window calculator is difficult result
    local it_7 = "0 SIGN ="
    it(it_7, function()
      for _, v in ipairs(split(it_7, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("0")
      assert.result("0")
    end)

    -- TODO: window calculator is difficult result
    local it_8 = "3 + 5 SIGN = = ="
    it(it_8, function()
      for _, v in ipairs(split(it_8, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("3 + -5 + -5 + -5")
      assert.result("-12")
    end)
  end)

  describe("DEL", function()
    local it_1 = "DEL"
    it(it_1, function()
      for _, v in ipairs(split(it_1, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("0")
      assert.result("0")
    end)

    local it_2 = "1 1 DEL"
    it(it_2, function()
      for _, v in ipairs(split(it_2, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("1")
      assert.result("0")
    end)

    local it_3 = "1 DEL"
    it(it_3, function()
      for _, v in ipairs(split(it_3, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("0")
      assert.result("0")
    end)

    local it_4 = "1 SIGN DEL"
    it(it_4, function()
      for _, v in ipairs(split(it_4, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("0")
      assert.result("0")
    end)

    local it_5 = "1 . 3 DEL"
    it(it_5, function()
      for _, v in ipairs(split(it_5, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("1.")
      assert.result("0")
    end)

    local it_6 = "1 . 3 SIGN DEL"
    it(it_6, function()
      for _, v in ipairs(split(it_6, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("-1.")
      assert.result("0")
    end)
  end)

  describe("CE", function()
    local it_1 = "3 + 5 + 7 CE"
    it(it_1, function()
      for _, v in ipairs(split(it_1, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("3 + 5 + 0")
      assert.result("0")
    end)

    local it_2 = "3 + 5 + 7 = CE"
    it(it_2, function()
      for _, v in ipairs(split(it_2, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("0")
      assert.result("0")
    end)
  end)

  describe("C", function()
    local it_1 = "3 + 5 + 7 C"
    it(it_1, function()
      for _, v in ipairs(split(it_1, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("0")
      assert.result("0")
    end)

    local it_2 = "3 + 5 + 7 = C"
    it(it_2, function()
      for _, v in ipairs(split(it_2, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("0")
      assert.result("0")
    end)

    local it_3 = "1 + 2 + 3 + . - + DEL 5 C"
    it(it_3, function()
      for _, v in ipairs(split(it_3, " ")) do
        dentaku.push_key(v)
      end
      assert.formula("0")
      assert.result("0")
    end)
  end)
end)
