--[[ BonaLuna lbc addendum

Copyright (C) 2010-2013 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2
Copyright (C) 2010 Lua.org, PUC-Rio.

Freely available under the terms of the Lua license.

--]]

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

    local function num2str(n, base)
        local sign
        n = bc.trunc(n)
        if base == nil then base = 10 end
        if bc.isneg(n) then sign = "- "; n = -n else sign = "" end
        local s = ""
        local d
        if bc.iszero(n) then
            s = "0"
        else
            while not bc.iszero(n) do
                n, d = bc.divmod(n, base)
                s = hexdigits[bc.tonumber(d)] .. s
            end
        end
        local prefix
        if base == 16 then
            prefix = "0x "
            s = groupby(s, 4)
        elseif base == 10 then
            prefix = " "
            s = groupby(s, 3)
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

    function bc.hex(x) return num2str(x, 16) end
    function bc.dec(x) return num2str(x, 10) end
    function bc.oct(x) return num2str(x, 8) end
    function bc.bin(x) return num2str(x, 2) end

    function bc.tostring(x)
        local s = bc_tostring(x)
        s = s:gsub("(%.[0-9]-)0+$", "%1"):gsub("%.$", "")
        return s
    end

    -- bit wise operations

    function bc.bnot(x, bits)
        if x:isneg() then error("bc.bnot can not use negative numbers") end
        local b = bc_two ^ bits
        x = x % b
        return (b-1-x) % b
    end

    function bc.band(x, y)
        if x:isneg() or y:isneg() then error("bc.band can not use negative numbers") end
        local z = bc_zero
        local i = 0
        local b = bc_two_pow_32
        x = bc.trunc(x)
        y = bc.trunc(y)
        while not x:iszero() and not bc.iszero(y) do
            local xd, yd
            x, xd = bc.divmod(x, b)
            y, yd = bc.divmod(y, b)
            z = z + bit32.band(bc.tonumber(xd), bc.tonumber(yd))*(b^i)
            i = i + 1
        end
        return z
    end

    function bc.bor(x, y)
        if x:isneg() or y:isneg() then error("bc.bor can not use negative numbers") end
        local z = bc_zero
        local i = 0
        local b = bc_two_pow_32
        x = bc.trunc(x)
        y = bc.trunc(y)
        while not x:iszero() or not bc.iszero(y) do
            local xd, yd
            x, xd = bc.divmod(x, b)
            y, yd = bc.divmod(y, b)
            z = z + bit32.bor(bc.tonumber(xd), bc.tonumber(yd))*(b^i)
            i = i + 1
        end
        return z
    end

    function bc.bxor(x, y)
        if x:isneg() or y:isneg() then error("bc.bxor can not use negative numbers") end
        local z = bc_zero
        local i = 0
        local b = bc_two_pow_32
        x = bc.trunc(x)
        y = bc.trunc(y)
        while not x:iszero() or not bc.iszero(y) do
            local xd, yd
            x, xd = bc.divmod(x, b)
            y, yd = bc.divmod(y, b)
            z = z + bit32.bxor(bc.tonumber(xd), bc.tonumber(yd))*(b^i)
            i = i + 1
        end
        return z
    end

    function bc.btest(x, y)
        if x:isneg() or y:isneg() then error("bc.btest can not use negative numbers") end
        return not bc.band(x, y):iszero()
    end

    function bc.extract(x, field, width)
        if x:isneg() then error("bc.extract can not use negative numbers") end
        x = bc.trunc(x)
        if width == nil then width = 1 end
        local shift = bc_two ^ field
        local mask = bc_two ^ width
        return (x / shift) % mask
    end

    function bc.replace(x, v, field, width)
        if x:isneg() then error("bc.replace can not use negative numbers") end
        x = bc.trunc(x)
        if width == nil then width = 1 end
        local shift = bc_two ^ field
        local mask = bc_two ^ width
        return x + (v - ((x / shift) % mask)) * shift;
    end

    function bc.lshift(x, disp)
        if x:isneg() then error("bc.lshift can not use negative numbers") end
        if disp < 0 then return bc.rshift(x, -disp) end
        x = bc.trunc(x)
        return x * bc_two^disp
    end

    function bc.rshift(x, disp)
        if x:isneg() then error("bc.rshift can not use negative numbers") end
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

