--[[ BonaLuna standard libraries

Copyright (C) 2010-2011 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2
Copyright (C) 2010 Lua.org, PUC-Rio.

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
    i = #items + 1
    return function()
        if i > 0 then
            i = i-1
            return items[i]
        end
    end
end

function sort(sequence, cmp)
    local items = list(sequence)
    table.sort(items, cmp)
    i = 1
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
        function(...) return table.unpack({...}) end,
        table.unpack({...})
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
    local i = 1
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

