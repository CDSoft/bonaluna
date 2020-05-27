--[[ BonaLuna lbc addendum

Copyright (C) 2010-2020 Christophe Delord
http://cdelord.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.3
Copyright (C) 1994-2017 Lua.org, PUC-Rio

Freely available under the terms of the MIT license.

--]]

-- bc : arbitrary precision library for Lua based on GNU bc
-- m : artibtrary precision integers and Lua floatting point numbers mixed in a single package

do

    bc.digits(20)

    local bc_number = bc.number
    local bc_tostring = bc.tostring
    local bc_zero = bc_number(0)
    local bc_one = bc_number(1)
    local bc_two = bc_number(2)
    local bc_two_pow_32 = bc_two ^ 32

    local hexdigits = {}
    for i = 0, 0xF do hexdigits[i] = ("0123456789ABCDEF"):sub(i+1, i+1) end

    local function groupby(s, n)
        s = s:reverse()
        s = s..(("0"):rep((n-1) - (s:len()-1)%n)) -- padding
        s = s:gsub("("..("."):rep(n)..")", "%1 ") -- group by n digits
        s = s:reverse()
        s = s:gsub("^ ", "")
        return s
    end

    local function num2str(n, base, bits)
        local sign
        n = bc.trunc(n)
        if base == nil then base = 10 end
        if bits ~= nil then
            n = bc.mod(n, bc_two ^ bits)
        end
        if bc.isneg(n) then sign = "- "; n = -n else sign = "" end
        local s = ""
        local d
        if bits == nil then
            if bc.iszero(n) then
                s = "0"
            else
                while not bc.iszero(n) do
                    n, d = bc.divmod(n, base)
                    s = hexdigits[bc.tonumber(d)] .. s
                end
            end
        else
            local bits_per_digit = math.log(base) / math.log(2)
            n = bc.mod(n, bc_two ^ bits)
            for i = 1, math.ceil(bits/bits_per_digit) do
                n, d = bc.divmod(n, base)
                s = hexdigits[bc.tonumber(d)] .. s
            end
        end
        local prefix
        if base == 16 then
            prefix = "0x "
            if not bits or bits > 8 then s = groupby(s, 4) end
        elseif base == 10 then
            prefix = " "
            s = groupby(s, 3)
            s = s:gsub("^(0+)(.)", "%2") -- remove leadding zeros
        elseif base == 8 and s ~= "0" then
            prefix = "0o "
        elseif base == 2 then
            prefix = "0b "
            s = groupby(s, 4)
        end
        return ((sign..prefix..s):gsub("  +", " "):gsub("^ +", ""))
    end

    local SIGN = {[""]=1, ["+"]=1, ["-"]=-1}

    function bc.number(x)
        if type(x) == "string" then
            s = x:gsub("[ _]", "")
            sign, digits = s:match("^([+-]?)0x([0-9A-Fa-f]+)$")
            if sign ~= nil then
                local n = bc_zero
                for i = 1, digits:len() do n = 16*n + tonumber(digits:sub(i, i), 16) end
                return SIGN[sign]*n
            end
            sign, digits = s:match("^([+-]?)0o?([0-7]+)$")
            if sign ~= nil then
                local n = bc_zero
                for i = 1, digits:len() do n = 8*n + tonumber(digits:sub(i, i), 8) end
                return SIGN[sign]*n
            end
            sign, digits = s:match("^([+-]?)0b([0-1]+)$")
            if sign ~= nil then
                local n = bc_zero
                for i = 1, digits:len() do n = 2*n + tonumber(digits:sub(i, i), 2) end
                return SIGN[sign]*n
            end
        end
        return bc_number(x)
    end

    function bc.hex(x, bits) return num2str(x, 16, bits) end
    function bc.dec(x, bits) return num2str(x, 10, bits) end
    function bc.oct(x, bits) return num2str(x, 8, bits) end
    function bc.bin(x, bits) return num2str(x, 2, bits) end

    function bc.tostring(x)
        local s = bc_tostring(x)
        s = s:gsub("(%.[0-9]-)0+$", "%1"):gsub("%.$", "")
        return s
    end

    -- bit wise operations

    function bc.bnot(x, bits)
        --if x:isneg() then error("bc.bnot can not use negative numbers") end
        if bits == nil then
            return -x-1
        else
            local b = bc_two ^ bits
            x = x % b
            return (b-1-x) % b
        end
    end

    function bc.band(x, y, bits)
        --if x:isneg() or y:isneg() then error("bc.band can not use negative numbers") end
        local z = bc_zero
        local i = 0
        local b = bc_two_pow_32
        local nb_32bit = (bits ~= nil) and bits/32 or 1e308
        x = bc.trunc(x)
        y = bc.trunc(y)
        while not x:iszero() and not bc.iszero(y) and (i <= nb_32bit) do
            local xd, yd
            x, xd = bc.divmod(x, b)
            y, yd = bc.divmod(y, b)
            z = z + (bc.tonumber(xd) & bc.tonumber(yd))*(b^i)
            i = i + 1
        end
        if bits ~= nil then
            z = bc.mod(z, bc_two ^ bits)
        end
        return z
    end

    function bc.bor(x, y, bits)
        --if x:isneg() or y:isneg() then error("bc.bor can not use negative numbers") end
        local z = bc_zero
        local i = 0
        local b = bc_two_pow_32
        local nb_32bit = (bits ~= nil) and bits/32 or 1e308
        x = bc.trunc(x)
        y = bc.trunc(y)
        while not x:iszero() or not bc.iszero(y) and (i <= nb_32bit) do
            local xd, yd
            x, xd = bc.divmod(x, b)
            y, yd = bc.divmod(y, b)
            z = z + (bc.tonumber(xd) | bc.tonumber(yd))*(b^i)
            i = i + 1
        end
        if bits ~= nil then
            z = bc.mod(z, bc_two ^ bits)
        end
        return z
    end

    function bc.bxor(x, y, bits)
        --if x:isneg() or y:isneg() then error("bc.bxor can not use negative numbers") end
        local z = bc_zero
        local i = 0
        local b = bc_two_pow_32
        local nb_32bit = (bits ~= nil) and bits/32 or 1e308
        x = bc.trunc(x)
        y = bc.trunc(y)
        while not x:iszero() or not bc.iszero(y) and (i <= nb_32bit) do
            local xd, yd
            x, xd = bc.divmod(x, b)
            y, yd = bc.divmod(y, b)
            z = z + (bc.tonumber(xd) ~ bc.tonumber(yd))*(b^i)
            i = i + 1
        end
        if bits ~= nil then
            z = bc.mod(z, bc_two ^ bits)
        end
        return z
    end

    function bc.btest(x, y, bits)
        --if x:isneg() or y:isneg() then error("bc.btest can not use negative numbers") end
        return not bc.band(x, y, bits):iszero()
    end

    function bc.extract(x, field, width)
        --if x:isneg() then error("bc.extract can not use negative numbers") end
        x = bc.trunc(x)
        if width == nil then width = 1 end
        local shift = bc_two ^ field
        local mask = bc_two ^ width
        return (x / shift) % mask
    end

    function bc.replace(x, v, field, width)
        --if x:isneg() then error("bc.replace can not use negative numbers") end
        x = bc.trunc(x)
        if width == nil then width = 1 end
        local shift = bc_two ^ field
        local mask = bc_two ^ width
        return x + (v - ((x / shift) % mask)) * shift;
    end

    function bc.lshift(x, disp)
        --if x:isneg() then error("bc.lshift can not use negative numbers") end
        if disp < 0 then return bc.rshift(x, -disp) end
        x = bc.trunc(x)
        return x * bc_two^disp
    end

    function bc.rshift(x, disp)
        --if x:isneg() then error("bc.rshift can not use negative numbers") end
        if disp < 0 then return bc.lshift(x, -disp) end
        x = bc.trunc(x)
        return bc.trunc(x / bc_two^disp)
    end

    -- math

    local function _f1(f)
        return function(x)
            if x == nil then return bc.number(f()) end
            return bc.number(f(bc.tonumber(x)))
        end
    end

    local function _f2(f)
        return function(x, y)
            if x == nil then return bc.number(f()) end
            if y == nil then return bc.number(f(bc.tonumber(x))) end
            return bc.number(f(bc.tonumber(x), bc.tonumber(y)))
        end
    end

    function bc.abs(x)
        if x:isneg() then
            return -x
        else
            return x
        end
    end

    bc.acos = _f1(math.acos)
    bc.asin = _f1(math.asin)
    bc.atan = _f1(math.atan)
    bc.atan2 = _f2(math.atan2)
    bc.ceil = _f1(math.ceil)
    bc.cos = _f1(math.cos)
    bc.cosh = _f1(math.cosh)
    bc.deg = _f1(math.deg)
    bc.exp = _f1(math.exp)
    bc.floor = _f1(math.floor)
    bc.fmod = _f2(math.fmod)
    bc.frexp = _f1(math.frexp)
    bc.ldexp = _f1(math.ldexp)
    bc.log = _f2(math.log)

    function bc.max(x, ...)
        for i, y in ipairs({...}) do
            if y > x then
                x = y
            end
        end
        return x
    end

    function bc.min(x, ...)
        for i, y in ipairs({...}) do
            if y < x then
                x = y
            end
        end
        return x
    end

    function bc.modf(x)
        local i = bc.trunc(x)
        local f = x - i
        return i, f
    end

    bc.pi = bc.number(math.pi)

    local bc_pow = bc.pow
    function bc.pow(x, y)
        local ok, z = pcall(bc_pow(x, y))
        if ok then return z end
        return math.pow(bc.tonumber(x), bc.tonumber(y))
    end

    bc.rad = _f1(math.rad)
    bc.random = _f2(math.random)
    bc.randomseed = _f1(math.randomseed)
    bc.sin = _f1(math.sin)
    bc.sinh = _f1(math.sinh)
    bc.tan = _f1(math.tan)
    bc.tanh = _f1(math.tanh)

    -- fix the modulo bug for negative numbers

    local bc_div = bc.div
    local bc_mod = bc.mod
    local bc_divmod = bc.divmod

    function bc.div(x, y)
        x = bc.number(x)
        y = bc.number(y)
        local q = bc_div(x, y)
        if x:isneg() ~= y:isneg() then q = q - 1 end
        return q
    end

    function bc.mod(x, y)
        x = bc.number(x)
        y = bc.number(y)
        local r = bc_mod(x, y)
        if x:isneg() ~= y:isneg() then r = r + y end
        return r
    end

    function bc.divmod(x, y)
        x = bc.number(x)
        y = bc.number(y)
        local q, r = bc_divmod(x, y)
        if x:isneg() ~= y:isneg() then r = r + y; q = q - 1 end
        return q, r
    end

    bc.__div = bc.div
    bc.__mod = bc.mod

end

do
    -- m.Num is a numeric object holding either a bc integer for a Lua float
    -- m also redefines math fonctions

    m = {}

    local meta = {}

    function m.Float(n)
        if type(n) == "table" and n.float then return n end
        local self
        if type(n) == "table" and n.int then self = {float = bc.tonumber(n.int)}
        else self = {float = tonumber(n) or bc.tonumber(n)}
        end
        function self.toint() return m.Int(self.float) end
        function self.tofloat() return self end
        function self.tonumber() return self.float end
        assert(self.int or self.float)
        return setmetatable(self, meta)
    end

    function m.Int(n)
        if type(n) == "table" and n.int then return n end
        local self
        bc.digits(0)
        if type(n) == "table" and n.float then self = {int = bc.number(n.float)}
        else self = {int = bc.number(n)}
        end
        function self.toint() return self end
        function self.tofloat() return m.Float(self.int) end
        function self.tonumber() return bc.tonumber(self.int) end
        assert(self.int or self.float)
        return setmetatable(self, meta)
    end

    function m.Num(n)
        if type(n) == "table" and (n.int or n.float) then
            -- already a m.Num object
            return n
        end
        local self
        if type(n) == "number" then
            if math.floor(n) == math.ceil(n) and math.abs(n) < 2^53 then
                -- a float representing an integer
                self = m.Int(n)
            else
                self = m.Float(n)
            end
        else
            bc.digits(0)
            local int = bc.number(n)
            local float = tonumber(n)
            if float == nil or int == float then
                -- can be an integer
                self = m.Int(int)
            else
                -- not an integer
                self = m.Float(float)
            end
        end

        return self
    end

    function meta.__tostring(n)
        return n.int and bc.tostring(n.int) or tostring(n.float)
    end

    function m.tonumber(n)
        if type(n) == "number" then return n end
        return n.tonumber()
    end

    local function _op1(op)
        return function(a)
            a = m.Num(a)
            if a.int then
                return m.Int(op(a.int))
            else
                return m.Float(op(a.float))
            end
        end
    end

    local function _op2(op)
        return function(a, b)
            a = m.Num(a)
            b = m.Num(b)
            if a.int and b.int then
                return m.Int(op(a.int, b.int))
            else
                return m.Float(op(a.tofloat().float, b.tofloat().float))
            end
        end
    end

    local function _boolop2(op)
        return function(a, b)
            a = m.Num(a)
            b = m.Num(b)
            return op(a.int or a.float, b.int or b.float)
        end
    end

    meta.__add = _op2(function(a, b) return a+b end)
    meta.__sub = _op2(function(a, b) return a-b end)
    meta.__mul = _op2(function(a, b) return a*b end)
    function meta.__div(a, b)
        a = m.Num(a)
        b = m.Num(b)
        if a.int and b.int then
            local q, r = bc.divmod(a.int, b.int)
            if r==0 then
                return m.Int(q)
            else
                return m.Float(a.int/b.int)
            end
        else
            return m.Float(a.tonumber() / b.tonumber())
        end
    end
    function meta.__pow(a, b)
        a = m.Num(a)
        b = m.Num(b)
        if a.int and b.int and b.int >= 0 then
            return m.Int(a.int ^ b.int)
        else
            return m.Float(a.tonumber() ^ b.tonumber())
        end
    end
    meta.__unm = _op1(function(a) return -a end)

    meta.__eq = _boolop2(function(a, b) return a == b end)
    meta.__lt = _boolop2(function(a, b) return a < b end)
    meta.__le = _boolop2(function(a, b) return a <= b end)

    local function _f1(f)
        local bc_f = bc[f]
        local math_f = math[f]
        return function(x)
            x = m.Num(x)
            if x.int then
                return m.Int(bc_f(x.int))
            else
                return m.Float(math_f(x.float))
            end
        end
    end

    local function _f1_float_float(f)
        local math_f = math[f]
        return function(x)
            x = m.tonumber(x)
            return m.Float(math_f(x))
        end
    end

    local function _f2_float_float_float(f)
        local math_f = math[f]
        return function(x, y)
            x = m.tonumber(x)
            y = y and m.tonumber(y)
            return m.Float(math_f(x, y))
        end
    end

    m.abs = _f1("abs")
    m.acos = _f1_float_float("acos")
    m.asin = _f1_float_float("asin")
    m.atan = _f1_float_float("atan")
    m.atan2 = _f2_float_float_float("atan2")
    function m.ceil(x) x = m.Num(x); return x.int and x or m.Int(math.ceil(x.float)) end
    m.cos = _f1_float_float("cos")
    m.cosh = _f1_float_float("cosh")
    m.deg = _f1_float_float("deg")
    m.exp = _f1_float_float("exp")
    function m.floor(x) x = m.Num(x); return x.int and x or m.Int(math.floor(x.float)) end
    m.fmod = _f2_float_float_float("fmod")
    function m.frexp(x) x = m.Num(x); local mant, exp = math.frexp(x.tofloat().float); return m.Float(mant), m.Int(exp) end
    m.huge = m.Num(math.huge)
    m.ldexp = _f2_float_float_float("ldexp")
    m.log = _f2_float_float_float("log")
    function m.max(x, ...)
        for i, y in ipairs({...}) do
            if y > x then
                x = y
            end
        end
        return x
    end
    function m.min(x, ...)
        for i, y in ipairs({...}) do
            if y < x then
                x = y
            end
        end
        return x
    end
    function m.modf(x)
        x = m.Num(x)
        if x.int then
            return x, m.Num(0)
        else
            local i, f = math.modf(x.float)
            return m.Int(i), m.Float(f)
        end
    end
    m.pi = m.Num(math.pi)
    m.pow = meta.__pow
    m.rad = _f1_float_float("rad")
    function m.random(x, y)
        if not x then return m.Float(math.random()) end
        x = m.Int(x).tonumber()
        if not y then return m.Int(math.random(x)) end
        y = m.Int(y).tonumber()
        return m.Int(math.random(x, y))
    end
    function m.randomseed(x)
        x = m.tonumber(x)
        math.randomseed(x)
    end
    m.sin = _f1_float_float("sin")
    m.sinh = _f1_float_float("sinh")
    m.sqrt = _f1_float_float("sqrt")
    m.tan = _f1_float_float("tan")
    m.tanh = _f1_float_float("tanh")

    function m.hex(x, bits) x = m.Num(x); return bc.hex(x.int, bits) end
    function m.dec(x, bits) x = m.Num(x); return bc.dec(x.int, bits) end
    function m.oct(x, bits) x = m.Num(x); return bc.oct(x.int, bits) end
    function m.bin(x, bits) x = m.Num(x); return bc.bin(x.int, bits) end

    function m.bnot(x, bits) return m.Int(bc.bnot(m.Int(x).int, bits)) end
    function m.band(x, y, bits) return m.Int(bc.band(m.Int(x).int, m.Int(y).int, bits)) end
    function m.bor(x, y, bits) return m.Int(bc.bor(m.Int(x).int, m.Int(y).int, bits)) end
    function m.bxor(x, y, bits) return m.Int(bc.bxor(m.Int(x).int, m.Int(y).int, bits)) end
    function m.btest(x, y, bits) return bc.btest(m.Int(x).int, m.Int(y).int, bits) end
    function m.extract(x, field, width) return m.Int(bc.extract(m.Int(x).int, m.Int(field).int, m.Int(width).int)) end
    function m.replace(x, v, field, width) return m.Int(bc.replace(m.Int(x).int, m.Int(v).int, m.Int(field).int, m.Int(width).int)) end
    function m.lshift(x, disp) return m.Int(bc.lshift(m.Int(x).int, disp)) end
    function m.rshift(x, disp) return m.Int(bc.rshift(m.Int(x).int, disp)) end

    function m.div(x, y) return m.Int(bc.div(m.Int(x).int, m.Int(y).int)) end
    function m.mod(x, y) return m.Int(bc.div(m.Int(x).int, m.Int(y).int)) end
    function m.divmod(x, y)
        local q, r = bc.divmod(m.Int(x).int, m.Int(y).int)
        return m.Int(q), m.Int(r)
    end

end
