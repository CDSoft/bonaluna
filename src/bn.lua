--[[ BonaLuna bignumber library

Copyright (C) 2010-2014 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2
Copyright (C) 1994-2013 Lua.org, PUC-Rio

Freely available under the terms of the Lua license.

--]]

-- Inspired by BigNum (http://oss.digirati.com.br/luabignum/)

bn = {}

do

-- Low level integer routines {{{
    local int, int_copy, int_trim, int_tostring, int_tonumber
    local int_abscmp, int_cmp, int_iszero, int_isone
    local int_neg, int_abs
    local int_add, int_sub, int_mul, int_divmod
    local int_pow
    local int_zero, int_one, int_two
    local int_gcd

    local RADIX = 10^7
    local RADIX_LEN = math.floor(math.log(RADIX, 10))

    assert(RADIX^2 < 2^53, "RADIX^2 shall be storable on a lua number")

    int_trim = function(a)
        for i = #a, 1, -1 do
            if a[i] and a[i] ~= 0 then break end
            table.remove(a)
        end
        if #a == 0 then a.sign = 1 end
    end

    int = function(n)
        n = n or 0
        if type(n) == "table" then return n end
        if type(n) == "number" then n = string.format("%.0f", math.floor(n)) end
        assert(type(n) == "string")
        n = string.gsub(n, "[ _]", "")
        local sign = 1
        local d = 1 -- current digit index
        if string.sub(n, d, d) == '+' then d = d+1
        elseif string.sub(n, d, d) == '-' then sign = -1; d = d+1
        end
        local base = 10
        if string.lower(string.sub(n, d, d+1)) == "0x" then
            d = d+2
            base = 16
        elseif string.lower(string.sub(n, d, d+1)) == "0o" then
            d = d+2
            base = 8
        elseif string.lower(string.sub(n, d, d+1)) == "0b" then
            d = d+2
            base = 2
        end
        local self = {sign=1}
        if base == 10 then
            for i = #n, d, -RADIX_LEN do
                local digit = string.sub(n, math.max(d, i-RADIX_LEN+1), i)
                self[#self+1] = tonumber(digit)
            end
        else
            local bn_base = {sign=1; base}
            local bn_shift = {sign=1; 1}
            local bn_digit = {sign=1; 0}
            for i = #n, d, -1 do
                bn_digit[1] = tonumber(string.sub(n, i, i), base)
                self = int_add(self, int_mul(bn_digit, bn_shift))
                bn_shift = int_mul(bn_shift, bn_base)
            end
        end
        self.sign = sign
        int_trim(self)
        return self
    end

    int_zero = int(0)
    int_one = int(1)
    int_two = int(2)

    int_copy = function(n)
        local c = {sign=n.sign}
        for i = 1, #n do
            c[i] = n[i]
        end
        return c
    end

    local base_prefix = {[2]="0b", [8]="0o", [16]="0x"}
    local base_group = {[2]=4, [10]=3, [16]=4}

    local function groupby(s, n)
        if n then
            s = s:reverse()
            s = s..(("0"):rep((n-1) - (s:len()-1)%n)) -- padding
            s = s:gsub("("..("."):rep(n)..")", "%1_") -- group by n digits
            s = s:reverse()
            s = s:gsub("^_", "")
        end
        return s
    end

    int_tostring = function(n, base, bits)
        base = base or 10
        local s = ""
        local sign = n.sign
        if base == 10 and not bits then
            local fmt = string.format("%%0%dd", RADIX_LEN)
            for i = 1, #n do
                s = string.format(fmt, n[i]) .. s
            end
            s = groupby(s, base_group[base])
            s = string.gsub(s, "^[_0]+", "")
            if s == "" then s = "0" end
        else
            local prefix = base_prefix[base]
            local bitsperdigits = math.log(base, 2)
            local bn_base = int(base)
            if bits then
                _, n = int_divmod(n, int_pow(int_two, int(bits)))
                for i = 1, bits, bitsperdigits do
                    local d
                    n, d = int_divmod(n, bn_base)
                    d = int_tonumber(d)
                    s = string.sub("0123456789ABCDEF", d+1, d+1) .. s
                end
                s = groupby(s, base_group[base])
            else
                local absn = int_abs(n)
                while #absn > 0 do
                    local d
                    absn, d = int_divmod(absn, bn_base)
                    d = int_tonumber(d)
                    s = string.sub("0123456789ABCDEF", d+1, d+1) .. s
                end
                s = groupby(s, base_group[base])
                s = string.gsub(s, "^0+", "")
                if s == "" then s = "0" end
            end
            if prefix then s = prefix .. "_" .. s end
        end
        if sign < 0 and not bits then s = "-" .. s end
        return s
    end

    int_tonumber = function(n)
        local s = n.sign < 0 and "-0" or "0"
        local fmt = string.format("%%0%dd", RADIX_LEN)
        for i = #n, 1, -1 do
            s = s..string.format(fmt, n[i])
        end
        return tonumber(s)
    end

    int_iszero = function(a)
        return #a == 0
    end

    int_isone = function(a)
        return #a == 1 and a[1] == 1 and a.sign == 1
    end

    int_cmp = function(a, b)
        if #a == 0 and #b == 0 then return 0 end -- 0 == -0
        if a.sign > b.sign then return 1 end
        if a.sign < b.sign then return -1 end
        if #a > #b then return a.sign end
        if #a < #b then return -a.sign end
        for i = #a, 1, -1 do
            if a[i] > b[i] then return a.sign end
            if a[i] < b[i] then return -a.sign end
        end
        return 0
    end

    int_abscmp = function(a, b)
        if #a > #b then return 1 end
        if #a < #b then return -1 end
        for i = #a, 1, -1 do
            if a[i] > b[i] then return 1 end
            if a[i] < b[i] then return -1 end
        end
        return 0
    end

    int_neg = function(a)
        local b = int_copy(a)
        b.sign = -a.sign
        return b
    end

    int_add = function(a, b)
        if a.sign == b.sign then            -- a+b = a+b, (-a)+(-b) = -(a+b)
            local c = int()
            c.sign = a.sign
            local carry = 0
            for i = 1, math.max(#a, #b) + 1 do -- +1 for the last carry
                c[i] = carry + (a[i] or 0) + (b[i] or 0)
                if c[i] >= RADIX then
                    c[i] = c[i] - RADIX
                    carry = 1
                else
                    carry = 0
                end
            end
            int_trim(c)
            return c
        else
            return int_sub(a, int_neg(b))
        end
    end

    int_sub = function(a, b)
        if a.sign == b.sign then
            local A, B
            local cmp = int_abscmp(a, b)
            if cmp >= 0 then A = a; B = b; else A = b; B = a; end
            local c = int()
            local carry = 0
            for i = 1, #A do
                c[i] = A[i] - (B[i] or 0) - carry
                if c[i] < 0 then
                    c[i] = c[i] + RADIX
                    carry = 1
                else
                    carry = 0
                end
            end
            assert(carry == 0) -- should be true if |A| >= |B|
            c.sign = (cmp >= 0) and a.sign or -a.sign
            int_trim(c)
            return c
        else
            local c = int_add(a, int_neg(b))
            c.sign = a.sign
            return c
        end
    end

    int_mul = function(a, b)
        local c = int()
        for i = 1, #a do
            local carry = 0
            for j = 1, #b do
                carry = (c[i+j-1] or 0) + a[i]*b[j] + carry
                c[i+j-1] = carry % RADIX
                carry = math.floor(carry / RADIX)
            end
            if carry ~= 0 then
                c[i + #b] = carry
            end
        end
        for i = #c, 1, -1 do
            if c[i] and c[i] ~= 0 then break end
            table.remove(c, i)
        end            
        c.sign = a.sign * b.sign
        int_trim(c)
        return c
    end

    local function int_absdiv2(a)
        local c = int()
        local carry = 0
        for i = 1, #a do
            c[i] = 0
        end
        for i = #a, 1, -1 do
            c[i] = math.floor(carry + a[i] / 2)
            if a[i] % 2 ~= 0 then
                carry = RADIX / 2
            else
                carry = 0
            end
        end
        c.sign = a.sign
        int_trim(c)
        return c, (a[1] or 0) % 2
    end

    int_divmod = function(a, b)
        -- euclidian division using dichotomie
        -- searching q and r such that a = q*b + r and |r| < |b|
        assert(not int_iszero(b), "Division by zero")
        if int_iszero(a) then return int_zero, int_zero end
        if b.sign < 0 then a = int_neg(a); b = int_neg(b) end
        local qmin = int_neg(a)
        local qmax = a
        if int_cmp(qmax, qmin) < 0 then qmin, qmax = qmax, qmin end
        local rmin = int_sub(a, int_mul(qmin, b))
        if rmin.sign > 0 and int_cmp(rmin, b) < 0 then return qmin, rmin end
        local rmax = int_sub(a, int_mul(qmax, b))
        if rmax.sign > 0 and int_cmp(rmax, b) < 0 then return qmax, rmax end
        assert(rmin.sign ~= rmax.sign)
        local q = int_absdiv2(int_add(qmin, qmax))
        local r = int_sub(a, int_mul(q, b))
        while r.sign < 0 or int_cmp(r, b) >= 0 do
            if r.sign == rmin.sign then
                qmin, qmax = q, qmax
                rmin, rmax = r, rmax
            else
                qmin, qmax = qmin, q
                rmin, rmax = rmin, r
            end
            q = int_absdiv2(int_add(qmin, qmax))
            r = int_sub(a, int_mul(q, b))
        end
        return q, r
    end

    int_pow = function(a, b)
        assert(b.sign > 0)
        if #b == 0 then return int_one end
        if #b == 1 and b[1] == 1 then return a end
        if #b == 1 and b[1] == 2 then return int_mul(a, a) end
        local c
        local q, r = int_absdiv2(b)
        c = int_pow(a, q)
        c = int_mul(c, c)
        if r == 1 then c = int_mul(c, a) end
        return c
    end

    int_abs = function(a)
        local b = int_copy(a)
        b.sign = 1
        return b
    end

    int_gcd = function(a, b)
        a = int_abs(a)
        b = int_abs(b)
        while true do
            local q
            local order = int_cmp(a, b)
            if order == 0 then return a end
            if order > 0 then
                q, a = int_divmod(a, b)
                if int_iszero(a) then return b end
            else
                q, b = int_divmod(b, a)
                if int_iszero(b) then return a end
            end
        end
    end

-- }}}

-- bn {{{

    function bn.tostring(n, base, bits)
        if n.isInt then return int_tostring(n, base, bits) end
        if n.isRat then return string.format("%s / %s", n.num, n.den) end
        return tostring(n.n)
    end

    function bn.tonumber(n)
        if n.isInt then return int_tonumber(n) end
        if n.isRat then return int_tonumber(n.num) / int_tonumber(n.den) end
        return n.n
    end

    function bn.divmod(a, b)
        if a.isInt and b.isInt then
            local q, r = int_divmod(a, b)
            return bn.Int(q), bn.Int(r)
        elseif a.isInt and b.isRat then
            local q, r = int_divmod(a*b.den, b.num)
            return bn.Int(q), bn.Rat(r, b.den)
        elseif a.isRat and b.isInt then
            local q, r = int_divmod(a.num*b, b*a.den)
            return bn.Int(q), bn.Rat(r, a.den)
        elseif a.isRat and b.isRat then
            local q, r = int_divmod(a.num*b.den, b.num*a.den)
            return bn.Int(q), bn.Rat(r, a.den*b.den)
        else
            a = a:tonumber()
            b = b:tonumber()
            return bn.Int(math.floor(a/b)), bn.Float(math.fmod(a, b))
        end
    end

    function bn.powmod(a, b, m)
        assert(a.isInt and b.isInt and b.sign >= 0 and m.isInt)
        local result = bn.one
        local r
        a = a % m
        while not b:iszero() do
            b, r = bn.divmod(b, bn.two)
            if r:isone() then
                result = (result*a) % m
            end
            a = (a*a) % m
        end
        return result
    end

-- }}}

-- metatable {{{

    local mt = {}
    mt.__index = mt

    function mt.tostring(n, base, bits) return bn.tostring(n, base, bits) end
    function mt.__tostring(n, base, bits) return bn.tostring(n, base, bits) end

    function mt.tonumber(n) return bn.tonumber(n) end
    function mt.__tonumber(n) return bn.tonumber(n) end

    function mt.toInt(n)
        if n.isInt then return n end
        if n.isRat then local q, r = int_divmod(n.num, n.den) return bn.Int(q) end
        if n.isFloat then return bn.Int(n.n) end
    end

    function mt.toRat(n, eps)
        if n.isInt then return n end
        if n.isRat then return n end
        if n.isFloat then
            local num = 1
            local den = 1
            eps = eps or 1e-6
            local absn = math.abs(n.n)
            local r = num / den
            --while r ~= n do
            while math.abs(absn - r) > eps do
                if r < absn then
                    num = num + 1
                else
                    den = den + 1
                    num = math.floor(absn * den)
                end
                r = num / den
            end
            r = bn.Rat(num, den)
            if n.n < 0 then r = -r end
            return r
        end
    end

    function mt.toFloat(n)
        return bn.Float(n:tonumber())
    end

    function mt.iszero(n)
        return n:tonumber() == 0
    end

    function mt.isone(n)
        return n:tonumber() == 1
    end

    function mt.__unm(a)
        if a.isInt then return bn.Int(int_neg(a)) end
        if a.isRat then return bn.Rat(-a.num, a.den) end
        return bn.Float(-a:tonumber())
    end

    function mt.__add(a, b)
        if a.isInt then
            if b.isInt then return bn.Int(int_add(a, b)) end
            if b.isRat then return bn.Rat(a*b.den + b.num, b.den) end
        elseif a.isRat then
            if b.isInt then return bn.Rat(a.num + b*a.den, a.den) end
            if b.isRat then return bn.Rat(a.num*b.den + b.num*a.den, a.den*b.den) end
        end
        return bn.Float(a:tonumber() + b:tonumber())
    end

    function mt.__sub(a, b)
        if a.isInt then
            if b.isInt then return bn.Int(int_sub(a, b)) end
            if b.isRat then return bn.Rat(a*b.den - b.num, b.den) end
        elseif a.isRat then
            if b.isInt then return bn.Rat(a.num - b*a.den, a.den) end
            if b.isRat then return bn.Rat(a.num*b.den - b.num*a.den, a.den*b.den) end
        end
        return bn.Float(a:tonumber() - b:tonumber())
    end

    function mt.__mul(a, b)
        if a.isInt then
            if b.isInt then return bn.Int(int_mul(a, b)) end
            if b.isRat then return bn.Rat(a*b.num, b.den) end
        elseif a.isRat then
            if b.isInt then return bn.Rat(a.num*b, a.den) end
            if b.isRat then return bn.Rat(a.num*b.num, a.den*b.den) end
        end
        return bn.Float(a:tonumber() * b:tonumber())
    end

    function mt.__div(a, b)
        if a.isInt then
            if b.isInt then return bn.Rat(a, b) end
            if b.isRat then return bn.Rat(a*b.den, b.num) end
        elseif a.isRat then
            if b.isInt then return bn.Rat(a.num, a.den*b) end
            if b.isRat then return bn.Rat(a.num*b.den, a.den*b.num) end
        end
        return bn.Float(a:tonumber() / b:tonumber())
    end

    function mt.__mod(a, b)
        local q, r = bn.divmod(a, b)
        return r
    end

    function mt.__pow(a, b)
        if a.isInt then
            if b.isInt then
                if b.sign > 0 then
                    return bn.Int(int_pow(a, b))
                else
                    return bn.Rat(bn.one, bn.Int(int_pow(a, int_neg(b))))
                end
            end
        elseif a.isRat then
            if b.isInt then return (a.num^b) / (a.den^b) end
        end
        return bn.Float(math.pow(a:tonumber(), b:tonumber()))
    end

    function mt.__eq(a, b)
        if a.isInt then
            if b.isInt then return int_cmp(a, b) == 0 end
            if b.isRat then return int_cmp(a*b.den, b.num) == 0 end
        elseif a.isRat then
            if b.isInt then return int_cmp(a.num, b*a.den) == 0 end
            if b.isRat then return int_cmp(a.num*b.den, b.num*a.den) == 0 end
        end
        return a:tonumber() == b:tonumber()
    end

    function mt.__lt(a, b)
        if a.isInt then
            if b.isInt then return int_cmp(a, b) < 0 end
            if b.isRat then return int_cmp(a*b.den, b.num) * b.den.sign < 0 end
        elseif a.isRat then
            if b.isInt then return int_cmp(a.num, b*a.den) * a.den.sign < 0 end
            if b.isRat then return int_cmp(a.num*b.den, b.num*a.den) * a.den.sign*b.den.sign < 0 end
        end
        return a:tonumber() < b:tonumber()
    end

    function mt.__le(a, b)
        if a.isInt then
            if b.isInt then return int_cmp(a, b) <= 0 end
            if b.isRat then return int_cmp(a*b.den, b.num) * b.den.sign <= 0 end
        elseif a.isRat then
            if b.isInt then return int_cmp(a.num, b*a.den) * a.den.sign <= 0 end
            if b.isRat then return int_cmp(a.num*b.den, b.num*a.den) * a.den.sign*b.den.sign <= 0 end
        end
        return a:tonumber() <= b:tonumber()
    end

-- }}}

-- bn.Int {{{

    function bn.Int(n)
        if type(n) == "table" then
            if n.toInt then return n:toInt() end
            local self = int_copy(n)
            self.isInt = true
            return setmetatable(self, mt)
        else
            local self = int(n)
            self.isInt = true
            return setmetatable(self, mt)
        end
    end

    bn.zero = bn.Int(0)
    bn.one = bn.Int(1)
    bn.two = bn.Int(2)


-- }}}

-- bn.Rat {{{

    local rat_simpl

    function bn.Rat(num, den)
        if not den then
            if type(num) == "table" then
                if num.toRat then return num:toRat() end
                return bn.Int(num)
            else
                return bn.Float(num):toRat()
            end
        else
            local self = {num=bn.Int(num), den=bn.Int(den)}
            assert(not int_iszero(self.den), "Division by zero")
            if int_iszero(self.num) then return bn.zero end
            if self.den.sign < 0 then
                self.num = -self.num
                self.den = -self.den
            end
            if int_isone(self.den) then return self.num end
            rat_simpl(self)
            if int_isone(self.den) then return self.num end
            self.isRat = true
            return setmetatable(self, mt)
        end
    end

    rat_simpl = function(a)
        local num = a.num
        local den = a.den
        local gcd = bn.Int(int_gcd(num, den))
        a.num = bn.Int(int_divmod(a.num, gcd))
        a.den = bn.Int(int_divmod(a.den, gcd))
    end

-- }}}

-- bn.Float {{{

    function bn.Float(n)
        if type(n) == "table" then
            if n.toFloat then return n:toFloat() end
            error(string.format("Can not convert %s to Float", n))
        else
            if type(n) == "string" then
                n = string.gsub(n, "[ _]", "")
            end
            local self = {n=tonumber(n)}
            self.isFloat = true
            return setmetatable(self, mt)
        end
    end

-- }}}

-- math fonctions {{{

    function bn.abs(x)
        if x.isInt then return bn.Int(int_abs(x)) end
        if x.isRat then return bn.Rat(int_abs(x.num), int_abs(x.den)) end
        return bn.Float(math.abs(x:tonumber()))
    end

    function bn.acos(x) return bn.Float(math.acos(x:tonumber())) end
    function bn.asin(x) return bn.Float(math.asin(x:tonumber())) end
    function bn.atan(x) return bn.Float(math.atan(x:tonumber())) end
    function bn.atan2(y, x) return bn.Float(math.atan(y:tonumber(), x:tonumber())) end

    function bn.ceil(x)
        if x.isInt then return x end
        if x.isRat then
            local q, r = int_divmod(x.num, x.den)
            if not int_iszero(r) then q = int_add(q, bn.one) end
            return bn.Int(q)
        end
        return bn.Int(math.ceil(x:tonumber()))
    end

    function bn.cos(x) return bn.Float(math.cos(x:tonumber())) end
    function bn.cosh(x) return bn.Float(math.cosh(x:tonumber())) end
    function bn.deg(x) return bn.Float(math.deg(x:tonumber())) end
    function bn.exp(x) return bn.Float(math.exp(x:tonumber())) end

    function bn.floor(x)
        if x.isInt then return x end
        if x.isRat then
            local q, r = int_divmod(x.num, x.den)
            return bn.Int(q)
        end
        return bn.Int(math.floor(x:tonumber()))
    end

    function bn.fmod(x, y) return bn.Float(math.fmod(x:tonumber(), y:tonumber())) end
    function bn.frexp(y) local mant, exp = math.frexp(y:tonumber()) return bn.Float(mant), bn.Int(exp) end

    bn.huge = bn.Float(math.huge)

    function bn.ldexp(m, e) return bn.Float(math.ldexp(m:tonumber(), e:tonumber())) end
    function bn.log(x, base) return bn.Float(math.log(x:tonumber(), base)) end
    function bn.max(x, ...)
        for i, y in ipairs({...}) do
            if y > x then
                x = y
            end
        end
        return x
    end
    function bn.min(x, ...)
        for i, y in ipairs({...}) do
            if y < x then
                x = y
            end
        end
        return x
    end

    function bn.modf(x)
        if x.isInt then
            return x, bn.zero
        elseif x.isRat then
            local q, r = int_divmod(x.num, x.den)
            return bn.Int(q), bn.Rat(r, x.den)
        else
            local i, f = math.modf(x:tonumber())
            return bn.Int(i), bn.Float(f)
        end
    end

    bn.pi = bn.Float(math.pi)
    bn.e = bn.Float(math.exp(1))

    function bn.pow(x, y) return x ^ y end
    function bn.rad(x) return bn.Float(math.rad(x:tonumber())) end

    function bn.random(m, n)
        if not m then return bn.Float(math.random()) end
        if not n then return bn.Int(math.random(m:tonumber())) end
        return bn.Int(math.random(m:tonumber(), n:tonumber()))
    end
    function bn.randomseed(x) math.randomseed(x:tonumber()) end

    function bn.sin(x) return bn.Float(math.sin(x:tonumber())) end
    function bn.sinh(x) return bn.Float(math.sinh(x:tonumber())) end
    function bn.sqrt(x) return bn.Float(math.sqrt(x:tonumber())) end
    function bn.tan(x) return bn.Float(math.tan(x:tonumber())) end
    function bn.tanh(x) return bn.Float(math.tanh(x:tonumber())) end

    function bn.hex(x, bits) return int_tostring(x, 16, bits) end
    function bn.dec(x, bits) return int_tostring(x, 10, bits) end
    function bn.oct(x, bits) return int_tostring(x, 8, bits) end
    function bn.bin(x, bits) return int_tostring(x, 2, bits) end

-- }}}

-- bitwise operations {{{

    local bn_two_pow_32 = bn.Int(2^32)

    function bn.bnot(x, bits)
        assert(x.isInt)
        if bits == nil then
            return -x-bn.one
        else
            local b = bn.two ^ bn.Int(bits)
            x = x % b
            return (b-bn.one-x) % b
        end
    end

    function bn.band(x, y, bits)
        assert(x.isInt)
        assert(y.isInt)
        local z = bn.zero
        local i = 0
        local b = bn_two_pow_32
        local nb_32bit = (bits ~= nil) and bits/32 or 1e308
        while not x:iszero() and not y:iszero() and (i <= nb_32bit) do
            local xd, yd
            x, xd = bn.divmod(x, b)
            y, yd = bn.divmod(y, b)
            z = z + bn.Int(bit32.band(xd:tonumber(), yd:tonumber()))*(b^bn.Int(i))
            i = i + 1
        end
        if bits ~= nil then
            z = z % (bn.two ^ bn.Int(bits))
        end
        return z
    end

    function bn.bor(x, y, bits)
        assert(x.isInt)
        assert(y.isInt)
        local z = bn.zero
        local i = 0
        local b = bn_two_pow_32
        local nb_32bit = (bits ~= nil) and bits/32 or 1e308
        while not x:iszero() or not y:iszero() and (i <= nb_32bit) do
            local xd, yd
            x, xd = bn.divmod(x, b)
            y, yd = bn.divmod(y, b)
            z = z + bn.Int(bit32.bor(xd:tonumber(), yd:tonumber()))*(b^bn.Int(i))
            i = i + 1
        end
        if bits ~= nil then
            z = z % (bn.two ^ bn.Int(bits))
        end
        return z
    end

    function bn.bxor(x, y, bits)
        assert(x.isInt)
        assert(y.isInt)
        local z = bn.zero
        local i = 0
        local b = bn_two_pow_32
        local nb_32bit = (bits ~= nil) and bits/32 or 1e308
        while not x:iszero() or not y:iszero() and (i <= nb_32bit) do
            local xd, yd
            x, xd = bn.divmod(x, b)
            y, yd = bn.divmod(y, b)
            z = z + bn.Int(bit32.bxor(xd:tonumber(), yd:tonumber()))*(b^bn.Int(i))
            i = i + 1
        end
        if bits ~= nil then
            z = z % (bn.two ^ bn.Int(bits))
        end
        return z
    end

    function bn.btest(x, y, bits)
        return not bn.band(x, y, bits):iszero()
    end

    function bn.extract(x, field, width)
        assert(x.isInt)
        if width == nil then width = 1 end
        local shift = bn.two ^ bn.Int(field)
        local mask = bn.two ^ bn.Int(width)
        return bn.Int(x / shift) % mask
    end

    function bn.replace(x, v, field, width)
        assert(x.isInt)
        assert(v.isInt)
        if width == nil then width = 1 end
        local shift = bn.two ^ bn.Int(field)
        local mask = bn.two ^ bn.Int(width)
        return x + (v - (bn.Int(x / shift) % mask)) * shift;
    end

    function bn.lshift(x, disp)
        assert(x.isInt)
        if disp < 0 then return bn.rshift(x, -disp) end
        return x * bn.two^bn.Int(disp)
    end

    function bn.rshift(x, disp)
        assert(x.isInt)
        if disp < 0 then return bn.lshift(x, -disp) end
        return bn.Int(x / bn.two^bn.Int(disp))
    end


-- }}}

end
