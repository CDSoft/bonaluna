--[[ BonaLuna standard libraries

Copyright (C) 2010-2015 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.3
Copyright (C) 1994-2015 Lua.org, PUC-Rio

Freely available under the terms of the Lua license.

--]]

-- This is an addendum to the C-coded libraries

-----------------------------------------------------------------------------
-- iterator functions
-----------------------------------------------------------------------------

-- iter(sequence) returns an iterator on sequence
function iter(sequence)
    if type(sequence) == "function" then return sequence end
    if type(sequence) == "table" then
        local i = 0
        return function()
            if i < #sequence then
                i = i+1
                return sequence[i]
            end
        end
    end
    print(sequence)
    error "Can not iterate"
end

-- list(iterator) returns a list of items produced by iterator
function list(iterator)
    if type(iterator) == "table" then return iterator end
    if type(iterator) == "function" then
        local sequence = {}
        for x in iterator do
            table.insert(sequence, x)
        end
        return sequence
    end
    error "Can not make a list"
end

function reverse(sequence)
    local items = list(sequence)
    local i = #items + 1
    return function()
        if i > 0 then
            i = i-1
            return items[i]
        end
    end
end

function sort(sequence, cmp)
    local items = list(iter(sequence))
    table.sort(items, cmp)
    local i = 1
    return function()
        if i <= #items then
            local item = items[i]
            i = i + 1
            return item
        end
    end
end

function map(f, ...)
    local its = {...}
    for i = 1, #its do its[i] = iter(its[i]) end
    return function()
        local x = {}
        local done = false
        for i = 1, #its do
            x[i] = its[i]()
            done = done or x[i]==nil
        end
        if not done then return f(table.unpack(x)) end
    end
end

function zip(...)
    return map(
        function(...) return ... end,
        ...
    )
end

function filter(p, iterator)
    iterator = iter(iterator)
    return function()
        while true do
            local xs = {iterator()}
            if #xs == 0 then return nil end
            if p(table.unpack(xs)) then return table.unpack(xs) end
        end
    end
end

function range(i, j, s)
    if not j then i, j = 1, i end
    s = s or (j < i and -1 or 1)
    if s > 0 then
        return function()
            if i <= j then
                local n = i
                i = i + s
                return n
            end
        end
    end
    if s < 0 then
        return function()
            if i >= j then
                local n = i
                i = i + s
                return n
            end
        end
    end
    error "null step"
end

function enum(iterator)
    iterator = iter(iterator)
    local i = 0
    return function()
        local xs = {iterator()}
        if #xs == 0 then return nil end
        i = i + 1
        return i, table.unpack(xs)
    end
end

function chain(...)
    local iterators = {...}
    local iterator = table.remove(iterators, 1)
    if iterator then iterator = iter(iterator) end
    return function()
        while iterator ~= nil do
            local item = iterator()
            if item ~= nil then return item end
            iterator = table.remove(iterators, 1)
            if iterator then iterator = iter(iterator) end
        end
    end
end

-- curry
-- Inspired by http://tinylittlelife.org/?p=249
-- Contributed by 梦想种子
function curry(func, ...)
    local prebinding = {...}
    local still_need = math.max(1, debug.getinfo(func, "u").nparams - #prebinding)
    local function helper(arg_chain, still_need)
        if still_need < 1 then
            return func(table.unpack(list(arg_chain())))
        else
            return function (...)
                local tail_args = {...}
                return helper(
                    function () return chain(arg_chain(), tail_args) end,
                    still_need - math.max(1, #tail_args)
                )
            end
        end
    end
    return helper(function () return prebinding end, still_need)
end

-- compose
-- Inspired by https://github.com/Gozala/functional-lua/blob/master/compose.lua
-- Contributed by 梦想种子
function compose(f, g, ...)
    local lambdas = {f, g, ...}
    return function(...)
        local state = {...}
        for lambda in reverse(lambdas) do
            state = {lambda(table.unpack(state))}
        end
        return table.unpack(state)
    end
end

-- identity
-- Taken from https://github.com/Gozala/functional-lua/blob/master/identity.lua
function identity(...)
    return ...
end

-- memoize
-- Inspired by https://github.com/kikito/memoize.lua
-- Contributed by 梦想种子
do
    local _nil = {}
    local _value = {}

    function memoize(f)
        local mem = {}
        return function (...)
            local cur = mem
            for i = 1, select("#", ...) do
                local k = select(i, ...) or _nil
                cur[k] = cur[k] or {}
                cur = cur[k]
            end
            cur[_value] = cur[_value] or table.pack(f(...))
            return table.unpack(cur[_value])
        end
    end
end

-----------------------------------------------------------------------------
-- string package addendum
-----------------------------------------------------------------------------

-- string.split
-- Contributed by 梦想种子
function string.split(s, sep, maxsplit, plain)
    assert(sep and sep ~= "")
    maxsplit = maxsplit or 1/0
    local items = {}
    if #s > 0 then
        local init = 1
        for i = 1, maxsplit do
            local m, n = s:find(sep, init, plain)
            if m and m <= n then
                table.insert(items, s:sub(init, m - 1))
                init = n + 1
            else
                break
            end
        end
        table.insert(items, s:sub(init))
    end
    return items
end

function string.gsplit(s, sep, maxsplit, plain)
    return iter(string.split(s, sep, maxsplit, plain))
end

function string.lines(s)
    return s:gsplit('\r?\n\r?')
end

function string.ltrim(s)
    return s:match("^%s*(.*)")
end

function string.rtrim(s)
    return s:match("(.-)%s*$")
end

function string.trim(s)
    return s:match("^%s*(.-)%s*$")
end

-----------------------------------------------------------------------------
-- fs package
-----------------------------------------------------------------------------

-- fs.dir(path) iterates over the file names in path
-- it uses the C function fs.listdir(path)
function fs.dir(path)
    return iter(fs.listdir(path))
end

-- fs.walk(path) iterates over the file names in path and its subdirectories
function fs.walk(path)
    local dirs = {path or "."}
    local files = {}
    return function()
        if #files > 0 then
            return table.remove(files, 1)
        elseif #dirs > 0 then
            local dir = table.remove(dirs)
            local names = fs.listdir(dir)
            if names then
                table.sort(names)
                for i = 1, #names do
                    local name = dir..fs.sep..names[i]
                    local stat = fs.stat(name)
                    if stat then
                        if stat.type == "directory" then
                            table.insert(dirs, name)
                        else
                            table.insert(files, name)
                        end
                    end
                end
                return dir
            end
        end
    end
end

-----------------------------------------------------------------------------
-- ser package
-----------------------------------------------------------------------------

-- based on https://github.com/gvx/Ser

do
    ser = {}

    local pairs, ipairs, tostring, type, concat, dump, floor = pairs, ipairs, tostring, type, table.concat, string.dump, math.floor

    local function getchr(c)
        return "\\" .. c:byte()
    end

    local function make_safe(text)
        return ("%q"):format(text):gsub('\n', 'n'):gsub("[\128-\255]", getchr)
    end

    local oddvals = {[tostring(1/0)] = '1/0', [tostring(-1/0)] = '-1/0', [tostring(0/0)] = '0/0'}

    local function write(t, memo, rev_memo)
        local ty = type(t)
        if ty == 'number' or ty == 'boolean' or ty == 'nil' then
            t = tostring(t)
            return oddvals[t] or t
        elseif ty == 'string' then
            return make_safe(t)
        elseif ty == 'table' or ty == 'function' then
            if not memo[t] then
                local index = #rev_memo + 1
                memo[t] = index
                rev_memo[index] = t
            end
            return '_' .. memo[t]
        else
            error("Trying to serialize unsupported type " .. ty)
        end
    end

    local kw = {['and'] = true, ['break'] = true, ['do'] = true, ['else'] = true,
        ['elseif'] = true, ['end'] = true, ['false'] = true, ['for'] = true,
        ['function'] = true, ['goto'] = true, ['if'] = true, ['in'] = true,
        ['local'] = true, ['nil'] = true, ['not'] = true, ['or'] = true,
        ['repeat'] = true, ['return'] = true, ['then'] = true, ['true'] = true,
        ['until'] = true, ['while'] = true}

    local function write_key_value_pair(k, v, memo, rev_memo, name)
        if type(k) == 'string' and k:match '^[_%a][_%w]*$' and not kw[k] then
            return (name and name .. '.' or '') .. k ..' = ' .. write(v, memo, rev_memo)
        else
            return (name or '') .. '[' .. write(k, memo, rev_memo) .. '] = ' .. write(v, memo, rev_memo)
        end
    end

    -- fun fact: this function is not perfect
    -- it has a few false positives sometimes
    -- but no false negatives, so that's good
    local function is_cyclic(memo, sub, super)
        local m = memo[sub]
        local p = memo[super]
        return m and p and m < p
    end

    local function write_table_ex(t, memo, rev_memo, srefs, name)
        if type(t) == 'function' then
            return 'local _' .. name .. ' = loadstring ' .. make_safe(dump(t))
        end
        local m = {'local _', name, ' = {'}
        local mi = 3
        for i = 1, #t do -- don't use ipairs here, we need the gaps
            local v = t[i]
            if v == t or is_cyclic(memo, v, t) then
                srefs[#srefs + 1] = {name, i, v}
                m[mi + 1] = 'nil, '
                mi = mi + 1
            else
                m[mi + 1] = write(v, memo, rev_memo)
                m[mi + 2] = ', '
                mi = mi + 2
            end
        end
        for k,v in pairs(t) do
            if type(k) ~= 'number' or floor(k) ~= k or k < 1 or k > #t then
                if v == t or k == t or is_cyclic(memo, v, t) or is_cyclic(memo, k, t) then
                    srefs[#srefs + 1] = {name, k, v}
                else
                    m[mi + 1] = write_key_value_pair(k, v, memo, rev_memo)
                    m[mi + 2] = ', '
                    mi = mi + 2
                end
            end
        end
        m[mi > 3 and mi or mi + 1] = '}'
        return concat(m)
    end

    function ser.serialize(t)
        local memo = {[t] = 0}
        local rev_memo = {[0] = t}
        local srefs = {}
        local result = {}

        -- phase 1: recursively descend the table structure
        local n = 0
        while rev_memo[n] do
            result[n + 1] = write_table_ex(rev_memo[n], memo, rev_memo, srefs, n)
            n = n + 1
        end

        -- phase 2: reverse order
        for i = 1, n*.5 do
            local j = n - i + 1
            result[i], result[j] = result[j], result[i]
        end

        -- phase 3: add all the tricky cyclic stuff
        for i, v in ipairs(srefs) do
            n = n + 1
            result[n] = write_key_value_pair(v[2], v[3], memo, rev_memo, '_' .. v[1])
        end

        -- phase 4: add something about returning the main table
        if result[n]:sub(1, 8) == 'local _0' then
            result[n] = 'return' .. result[n]:sub(11)
        else
            result[n + 1] = 'return _0'
        end

        -- phase 5: just concatenate everything
        return concat(result, '\n')
    end

    function ser.deserialize(src)
        local f = load(src)
        if not f then error("deserialization error") end
        return f()
    end

end
