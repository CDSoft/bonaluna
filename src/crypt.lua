--[[ BonaLuna cryptography library

Copyright (C) 2010-2014 Christophe Delord
http://cdsoft.fr/bl/bonaluna.html

BonaLuna is based on Lua 5.2
Copyright (C) 1994-2013 Lua.org, PUC-Rio

Freely available under the terms of the Lua license.

--]]

local strlen  = string.len
local strchar = string.char
local strbyte = string.byte
local strsub  = string.sub
local floor   = math.floor
local bnot    = bit32.bnot
local band    = bit32.band
local bor     = bit32.bor
local bxor    = bit32.bxor
local lshift  = bit32.lshift
local rshift  = bit32.rshift
local rrotate = bit32.rrotate

-----------------------------------------------------------------------
-- crypt.hex
-----------------------------------------------------------------------

crypt.hex = {}
do
    function crypt.hex.encode(s)
        return (s:gsub(".", function(c)
            return string.format("%02x", c:byte())
        end))
    end
    function crypt.hex.decode(s)
        return (s:gsub("..", function(h)
            return string.char("0x"..h)
        end))
    end
end

-----------------------------------------------------------------------
-- crypt.base64
-----------------------------------------------------------------------

crypt.base64 = {}

do  -- http://lua-users.org/wiki/BaseSixtyFour

    -- character table string
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

    -- encoding
    function crypt.base64.encode(data)
        return ((data:gsub('.', function(x) 
            local r,b='',x:byte()
            for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
            return r;
        end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
            if (#x < 6) then return '' end
            local c=0
            for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
            return b:sub(c+1,c+1)
        end)..({ '', '==', '=' })[#data%3+1])
    end

    -- decoding
    function crypt.base64.decode(data)
        data = string.gsub(data, '[^'..b..'=]', '')
        return (data:gsub('.', function(x)
            if (x == '=') then return '' end
            local r,f='',(b:find(x)-1)
            for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
            return r;
        end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
            if (#x ~= 8) then return '' end
            local c=0
            for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return strchar(c)
        end))
    end

end

-----------------------------------------------------------------------
-- crypt.crc32
-----------------------------------------------------------------------

do
    local consts = { 0x00000000, 0x77073096, 0xEE0E612C, 0x990951BA, 0x076DC419, 0x706AF48F, 0xE963A535, 0x9E6495A3,
                     0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988, 0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91,
                     0x1DB71064, 0x6AB020F2, 0xF3B97148, 0x84BE41DE, 0x1ADAD47D, 0x6DDDE4EB, 0xF4D4B551, 0x83D385C7,
                     0x136C9856, 0x646BA8C0, 0xFD62F97A, 0x8A65C9EC, 0x14015C4F, 0x63066CD9, 0xFA0F3D63, 0x8D080DF5,
                     0x3B6E20C8, 0x4C69105E, 0xD56041E4, 0xA2677172, 0x3C03E4D1, 0x4B04D447, 0xD20D85FD, 0xA50AB56B,
                     0x35B5A8FA, 0x42B2986C, 0xDBBBC9D6, 0xACBCF940, 0x32D86CE3, 0x45DF5C75, 0xDCD60DCF, 0xABD13D59,
                     0x26D930AC, 0x51DE003A, 0xC8D75180, 0xBFD06116, 0x21B4F4B5, 0x56B3C423, 0xCFBA9599, 0xB8BDA50F,
                     0x2802B89E, 0x5F058808, 0xC60CD9B2, 0xB10BE924, 0x2F6F7C87, 0x58684C11, 0xC1611DAB, 0xB6662D3D,
                     0x76DC4190, 0x01DB7106, 0x98D220BC, 0xEFD5102A, 0x71B18589, 0x06B6B51F, 0x9FBFE4A5, 0xE8B8D433,
                     0x7807C9A2, 0x0F00F934, 0x9609A88E, 0xE10E9818, 0x7F6A0DBB, 0x086D3D2D, 0x91646C97, 0xE6635C01,
                     0x6B6B51F4, 0x1C6C6162, 0x856530D8, 0xF262004E, 0x6C0695ED, 0x1B01A57B, 0x8208F4C1, 0xF50FC457,
                     0x65B0D9C6, 0x12B7E950, 0x8BBEB8EA, 0xFCB9887C, 0x62DD1DDF, 0x15DA2D49, 0x8CD37CF3, 0xFBD44C65,
                     0x4DB26158, 0x3AB551CE, 0xA3BC0074, 0xD4BB30E2, 0x4ADFA541, 0x3DD895D7, 0xA4D1C46D, 0xD3D6F4FB,
                     0x4369E96A, 0x346ED9FC, 0xAD678846, 0xDA60B8D0, 0x44042D73, 0x33031DE5, 0xAA0A4C5F, 0xDD0D7CC9,
                     0x5005713C, 0x270241AA, 0xBE0B1010, 0xC90C2086, 0x5768B525, 0x206F85B3, 0xB966D409, 0xCE61E49F,
                     0x5EDEF90E, 0x29D9C998, 0xB0D09822, 0xC7D7A8B4, 0x59B33D17, 0x2EB40D81, 0xB7BD5C3B, 0xC0BA6CAD,
                     0xEDB88320, 0x9ABFB3B6, 0x03B6E20C, 0x74B1D29A, 0xEAD54739, 0x9DD277AF, 0x04DB2615, 0x73DC1683,
                     0xE3630B12, 0x94643B84, 0x0D6D6A3E, 0x7A6A5AA8, 0xE40ECF0B, 0x9309FF9D, 0x0A00AE27, 0x7D079EB1,
                     0xF00F9344, 0x8708A3D2, 0x1E01F268, 0x6906C2FE, 0xF762575D, 0x806567CB, 0x196C3671, 0x6E6B06E7,
                     0xFED41B76, 0x89D32BE0, 0x10DA7A5A, 0x67DD4ACC, 0xF9B9DF6F, 0x8EBEEFF9, 0x17B7BE43, 0x60B08ED5,
                     0xD6D6A3E8, 0xA1D1937E, 0x38D8C2C4, 0x4FDFF252, 0xD1BB67F1, 0xA6BC5767, 0x3FB506DD, 0x48B2364B,
                     0xD80D2BDA, 0xAF0A1B4C, 0x36034AF6, 0x41047A60, 0xDF60EFC3, 0xA867DF55, 0x316E8EEF, 0x4669BE79,
                     0xCB61B38C, 0xBC66831A, 0x256FD2A0, 0x5268E236, 0xCC0C7795, 0xBB0B4703, 0x220216B9, 0x5505262F,
                     0xC5BA3BBE, 0xB2BD0B28, 0x2BB45A92, 0x5CB36A04, 0xC2D7FFA7, 0xB5D0CF31, 0x2CD99E8B, 0x5BDEAE1D,
                     0x9B64C2B0, 0xEC63F226, 0x756AA39C, 0x026D930A, 0x9C0906A9, 0xEB0E363F, 0x72076785, 0x05005713,
                     0x95BF4A82, 0xE2B87A14, 0x7BB12BAE, 0x0CB61B38, 0x92D28E9B, 0xE5D5BE0D, 0x7CDCEFB7, 0x0BDBDF21,
                     0x86D3D2D4, 0xF1D4E242, 0x68DDB3F8, 0x1FDA836E, 0x81BE16CD, 0xF6B9265B, 0x6FB077E1, 0x18B74777,
                     0x88085AE6, 0xFF0F6A70, 0x66063BCA, 0x11010B5C, 0x8F659EFF, 0xF862AE69, 0x616BFFD3, 0x166CCF45,
                     0xA00AE278, 0xD70DD2EE, 0x4E048354, 0x3903B3C2, 0xA7672661, 0xD06016F7, 0x4969474D, 0x3E6E77DB,
                     0xAED16A4A, 0xD9D65ADC, 0x40DF0B66, 0x37D83BF0, 0xA9BCAE53, 0xDEBB9EC5, 0x47B2CF7F, 0x30B5FFE9,
                     0xBDBDF21C, 0xCABAC28A, 0x53B39330, 0x24B4A3A6, 0xBAD03605, 0xCDD70693, 0x54DE5729, 0x23D967BF,
                     0xB3667A2E, 0xC4614AB8, 0x5D681B02, 0x2A6F2B94, 0xB40BBE37, 0xC30C8EA1, 0x5A05DF1B, 0x2D02EF8D }
 
    function crypt.crc32(s)
        local crc, l, i = 0xFFFFFFFF, strlen(s)
        for i = 1, l, 1 do
            crc = bxor(rshift(crc, 8), consts[band(bxor(crc, strbyte(s, i)), 0xFF) + 1])
        end
        return bxor(crc, -1)
    end
end

-----------------------------------------------------------------------
-- crypt.sha2
-----------------------------------------------------------------------

do -- http://lua-users.org/wiki/SecureHashAlgorithm

    -- Initialize table of round constants
    -- (first 32 bits of the fractional parts of the cube roots of the first
    -- 64 primes 2..311):
    local k = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    }

    -- transform a string of bytes in a string of hexadecimal digits
    local function str2hexa (s)
        local h = string.gsub(s, ".", function(c)
            return string.format("%02x", string.byte(c))
        end)
        return h
    end

    -- transform number 'l' in a big-endian sequence of 'n' bytes
    -- (coded as a string)
    local function num2s (l, n)
        local s = ""
        for i = 1, n do
            local rem = l % 256
            s = strchar(rem) .. s
            l = (l - rem) / 256
        end
        return s
    end

    -- transform the big-endian sequence of four bytes starting at
    -- index 'i' in 's' into a number
    local function s232num (s, i)
        local n = 0
        for i = i, i + 3 do
            n = n*256 + strbyte(s, i)
        end
        return n
    end

    -- append the bit '1' to the message
    -- append k bits '0', where k is the minimum number >= 0 such that the
    -- resulting message length (in bits) is congruent to 448 (mod 512)
    -- append length of message (before pre-processing), in bits, as 64-bit
    -- big-endian integer
    local function preproc (msg, len)
        local extra = 64 - ((len + 1 + 8) % 64)
        len = num2s(8 * len, 8)    -- original len in bits, coded
        msg = msg .. "\128" .. string.rep("\0", extra) .. len
        assert(#msg % 64 == 0)
        return msg
    end

    local function initH224 (H)
        -- (second 32 bits of the fractional parts of the square roots of the
        -- 9th through 16th primes 23..53)
        H[1] = 0xc1059ed8
        H[2] = 0x367cd507
        H[3] = 0x3070dd17
        H[4] = 0xf70e5939
        H[5] = 0xffc00b31
        H[6] = 0x68581511
        H[7] = 0x64f98fa7
        H[8] = 0xbefa4fa4
        return H
    end

    local function initH256 (H)
        -- (first 32 bits of the fractional parts of the square roots of the
        -- first 8 primes 2..19):
        H[1] = 0x6a09e667
        H[2] = 0xbb67ae85
        H[3] = 0x3c6ef372
        H[4] = 0xa54ff53a
        H[5] = 0x510e527f
        H[6] = 0x9b05688c
        H[7] = 0x1f83d9ab
        H[8] = 0x5be0cd19
        return H
    end

    local function digestblock (msg, i, H)

        -- break chunk into sixteen 32-bit big-endian words w[1..16]
        local w = {}
        for j = 1, 16 do
            w[j] = s232num(msg, i + (j - 1)*4)
        end

        -- Extend the sixteen 32-bit words into sixty-four 32-bit words:
        for j = 17, 64 do
            local v = w[j - 15]
            local s0 = bxor(rrotate(v, 7), rrotate(v, 18), rshift(v, 3))
            v = w[j - 2]
            local s1 = bxor(rrotate(v, 17), rrotate(v, 19), rshift(v, 10))
            w[j] = w[j - 16] + s0 + w[j - 7] + s1
        end

        -- Initialize hash value for this chunk:
        local a, b, c, d, e, f, g, h =
            H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]

        -- Main loop:
        for i = 1, 64 do
            local s0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
            local maj = bxor(band(a, b), band(a, c), band(b, c))
            local t2 = s0 + maj
            local s1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
            local ch = bxor (band(e, f), band(bnot(e), g))
            local t1 = h + s1 + ch + k[i] + w[i]

            h = g
            g = f
            f = e
            e = d + t1
            d = c
            c = b
            b = a
            a = t1 + t2
        end

        -- Add (mod 2^32) this chunk's hash to result so far:
        H[1] = band(H[1] + a)
        H[2] = band(H[2] + b)
        H[3] = band(H[3] + c)
        H[4] = band(H[4] + d)
        H[5] = band(H[5] + e)
        H[6] = band(H[6] + f)
        H[7] = band(H[7] + g)
        H[8] = band(H[8] + h)

    end

    local function finalresult224 (H)
        -- Produce the final hash value (big-endian):
        return str2hexa(num2s(H[1], 4)..num2s(H[2], 4)..
                        num2s(H[3], 4)..num2s(H[4], 4)..
                        num2s(H[5], 4)..num2s(H[6], 4)..
                        num2s(H[7], 4))
    end

    local function finalresult256 (H)
        -- Produce the final hash value (big-endian):
        return str2hexa(num2s(H[1], 4)..num2s(H[2], 4)..
                        num2s(H[3], 4)..num2s(H[4], 4)..
                        num2s(H[5], 4)..num2s(H[6], 4)..
                        num2s(H[7], 4)..num2s(H[8], 4))
    end

    ----------------------------------------------------------------------
    local HH = {}    -- to reuse

    function crypt.sha224 (msg)
        msg = preproc(msg, #msg)
        local H = initH224(HH)

        -- Process the message in successive 512-bit (64 bytes) chunks:
        for i = 1, #msg, 64 do
            digestblock(msg, i, H)
        end

        return finalresult224(H)
    end


    function crypt.sha256 (msg)
        msg = preproc(msg, #msg)
        local H = initH256(HH)

        -- Process the message in successive 512-bit (64 bytes) chunks:
        for i = 1, #msg, 64 do
            digestblock(msg, i, H)
        end

        return finalresult256(H)
    end
    ----------------------------------------------------------------------

end

-----------------------------------------------------------------------
-- crypt.sha1
-----------------------------------------------------------------------

do
    -------------------------------------------------
    ---      *** SHA-1 algorithm for Lua ***      ---
    -------------------------------------------------
    --- Author:  Martin Huesser                   ---
    --- Date:    2008-06-16                       ---
    --- License: You may use this code in your    ---
    ---          projects as long as this header  ---
    ---          stays intact.                    ---
    -------------------------------------------------

    local h0, h1, h2, h3, h4

    -------------------------------------------------

    local function LeftRotate(val, nr)
        return lshift(val, nr) + rshift(val, 32 - nr)
    end

    -------------------------------------------------

    local function ToHex(num)
        local i, d
        local str = ""
        for i = 1, 8 do
            d = band(num, 15)
            if d < 10 then
                str = strchar(d + 48) .. str
            else
                str = strchar(d + 87) .. str
            end
            num = floor(num / 16)
        end
        return str
    end

    -------------------------------------------------

    local function PreProcess(str)
        local bitlen, i
        local str2 = ""
        bitlen = strlen(str) * 8
        str = str .. strchar(128)
        i = 56 - band(strlen(str), 63)
        if i < 0 then
            i = i + 64
        end
        for i = 1, i do
            str = str .. strchar(0)
        end
        for i = 1, 8 do
            str2 = strchar(band(bitlen, 255)) .. str2
            bitlen = floor(bitlen / 256)
        end
        return str .. str2
    end

    -------------------------------------------------

    local function MainLoop(str)
        local a, b, c, d, e, f, k, t
        local i, j
        local w = {}
        while (str ~= "") do
            for i = 0, 15 do
                w[i] = 0
                for j = 1, 4 do
                    w[i] = w[i] * 256 + strbyte(str, i * 4 + j)
                end
            end
            for i = 16, 79 do
                w[i] = LeftRotate(bxor(bxor(w[i - 3], w[i - 8]), bxor(w[i - 14], w[i - 16])), 1)
            end
            a = h0
            b = h1
            c = h2
            d = h3
            e = h4
            for i = 0, 79 do
                if i < 20 then
                    f = bor(band(b, c), band(bnot(b), d))
                    k = 1518500249
                elseif i < 40 then
                    f = bxor(bxor(b, c), d)
                    k = 1859775393
                elseif i < 60 then
                    f = bor(bor(band(b, c), band(b, d)), band(c, d))
                    k = 2400959708
                else
                    f = bxor(bxor(b, c), d)
                    k = 3395469782
                end
                t = LeftRotate(a, 5) + f + e + k + w[i]
                e = d
                d = c
                c = LeftRotate(b, 30)
                b = a
                a = t
            end
            h0 = band(h0 + a, 4294967295)
            h1 = band(h1 + b, 4294967295)
            h2 = band(h2 + c, 4294967295)
            h3 = band(h3 + d, 4294967295)
            h4 = band(h4 + e, 4294967295)
            str = strsub(str, 65)
        end
    end

    -------------------------------------------------

    function crypt.sha1(str)
        str = PreProcess(str)
        h0  = 1732584193
        h1  = 4023233417
        h2  = 2562383102
        h3  = 0271733878
        h4  = 3285377520
        MainLoop(str)
        return  ToHex(h0) ..
            ToHex(h1) ..
            ToHex(h2) ..
            ToHex(h3) ..
            ToHex(h4)
    end

    -------------------------------------------------
end

-----------------------------------------------------------------------
-- crypt.AES
-----------------------------------------------------------------------

--[[ based on aeslua (https://github.com/bighil/aeslua/tree/master/src)
aeslua: Lua AES implementation
Copyright (c) 2006,2007 Matthias Hilbig

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser Public License as published by the
Free Software Foundation; either version 2.1 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser Public License for more details.

A copy of the terms and conditions of the license can be found in
License.txt or online at

    http://www.gnu.org/copyleft/lesser.html

To obtain a copy, write to the Free Software Foundation, Inc.,
59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

Author
-------
Matthias Hilbig
http://homepages.upb.de/hilbig/aeslua/
hilbig@upb.de
--]]

do

    local IV = nil

    local function Buffer()
        local buffer = {}
        local stack = {}
        function buffer.addString(s)
            table.insert(stack, s)
            for i = #stack-1, 1, -1 do
                if #stack[i] > #stack[i+1] then
                    break
                end
                stack[i] = stack[i]..table.remove(stack)
            end
        end
        function buffer.toString()
            for i = #stack-1, 1, -1 do
                stack[i] = stack[i]..table.remove(stack)
            end
            return stack[1]
        end
        return buffer
    end

    local function byteParity(byte)
        byte = bxor(byte, rshift(byte, 4))
        byte = bxor(byte, rshift(byte, 2))
        byte = bxor(byte, rshift(byte, 1))
        return band(byte, 1)
    end

    local function getByte(number, index)
        if index == 0 then
            return band(number, 0xFF)
        else
            return band(rshift(number, index*8), 0xFF)
        end
    end

    local function putByte(number, index)
        if index == 0 then
            return band(number, 0xFF)
        else
            return lshift(band(number, 0xFF), index*8)
        end
    end

    local function bytesToInts(bytes, start, n)
        local ints = {}
        for i = 0, n-1 do
            ints[i] = putByte(bytes[start+(i*4)  ], 3)
                    + putByte(bytes[start+(i*4)+1], 2)
                    + putByte(bytes[start+(i*4)+2], 1)
                    + putByte(bytes[start+(i*4)+3], 0)
        end
        return ints
    end

    local function intsToBytes(ints, output, outputoffset, n)
        n = n or #ints
        for i = 0, n do
            for j = 0, 3 do
                output[outputoffset+i*4+(3-j)] = getByte(ints[i], j)
            end
        end
        return output
    end

    local function bytesToHex(bytes)
        local hex = ""
        for i, byte in ipairs(bytes) do
            hex = hex..string.format("%02x ", byte)
        end
        return hex
    end

    local function toHexString(data)
        local type = type(data)
        if type=="number" then return string.format("%08x", data) end
        if type=="table" then return bytesToHex(data) end
        if type=="string" then return bytesToHex{string.byte(data, 1, #data)} end
        return data
    end

    local function padByteString(data)
        local dataLen = #data
        local random1 = math.random(0, 255)
        local random2 = math.random(0, 255)
        local prefix = string.char(random1, random2,
                                   random1, random2,
                                   getByte(dataLen, 3),
                                   getByte(dataLen, 2),
                                   getByte(dataLen, 1),
                                   getByte(dataLen, 0))
        data = prefix..data
        local paddingLen = math.ceil(#data/16)*16 - #data
        local padding = ""
        for i = 1, paddingLen do
            padding = padding..string.char(math.random(0, 255))
        end
        return data..padding
    end

    local function properlyDecrypted(data)
        local random = {string.byte(data, 1, 4)}
        return random[1]==random[3] and random[2]==random[4]
    end

    local function unpadByteString(data)
        if properlyDecrypted(data) then
            local dataLen = putByte(string.byte(data, 5), 3)
                          + putByte(string.byte(data, 6), 2)
                          + putByte(string.byte(data, 7), 1)
                          + putByte(string.byte(data, 8), 0)
            return string.sub(data, 9, 8+dataLen)
        end
    end

    local function xorIV(data, IV)
        for i = 1, 16 do
            data[i] = bxor(data[i], IV[i])
        end
    end

    -- finite field with base 2 and modulo irreducible polynom x^8+x^4+x^3+x+1 = 0x11d
    local n = 0x100
    local ord = 0xff
    local irrPolynom = 0x11b
    local exp = {}
    local log = {}

    -- add two polynoms (its simply xor)
    local add = bxor

    -- subtract two polynoms (same as addition)
    local sub = bxor

    -- inverts element
    -- a^(-1) = g^(order - log(a))
    local function invert(operand)
        if operand == 1 then return 1 end
        return exp[ord - log[operand]]
    end

    -- multiply two elements using a logarithm table
    -- a*b = g^(log(a)+log(b))
    local function mul(operand1, operand2)
        if operand1==0 or operand2==0 then return 0 end
        local exponent = log[operand1] + log[operand2]
        if exponent >= ord then
            exponent = exponent - ord
        end
        return exp[exponent]
    end

    -- divide two elements
    -- a/b = g^(log(a)-log(b))
    local function div(operand1, operand2)
        if operand1 == 0 then return 0 end
        local exponent = log[operand1] - log[operand2]
        if exponent < 0 then
            exponent = exponent + ord
        end
        return exp[exponent]
    end

    -- calculate logarithmic and exponentiation table
    local function initMulTable()
        local a = 1
        for i = 0, ord-1 do
            exp[i] = a
            log[a] = i
            a = bxor(lshift(a, 1), a)
            if a > ord then
                a = sub(a, irrPolynom)
            end
        end
    end

    initMulTable()

    -- Implementation of AES with pure lua
    --
    -- AES with lua is slow, really slow :-)

    -- some constants
    local ROUNDS = "rounds"
    local KEY_TYPE = "type"
    local ENCRYPTION_KEY = 1
    local DECRYPTION_KEY = 2

    -- aes SBOX
    local SBox = {}
    local iSBox = {}

    -- aes tables
    local table0 = {}
    local table1 = {}
    local table2 = {}
    local table3 = {}

    local tableInv0 = {}
    local tableInv1 = {}
    local tableInv2 = {}
    local tableInv3 = {}

    -- round constants
    local rCon = {0x01000000, 0x02000000, 0x04000000, 0x08000000,
                  0x10000000, 0x20000000, 0x40000000, 0x80000000,
                  0x1b000000, 0x36000000, 0x6c000000, 0xd8000000,
                  0xab000000, 0x4d000000, 0x9a000000, 0x2f000000}

    -- affine transformation for calculating the S-Box of AES
    local function affinMap(byte)
        local mask = 0xf8
        local result = 0
        for i = 1, 8 do
            result = lshift(result, 1)

            result = result + byteParity(band(byte, mask))

            -- simulate roll
            mask = band(rshift(mask, 1), 0xff)
            if band(mask, 1) ~= 0 then
                mask = bor(mask, 0x80)
            else
                mask = band(mask, 0x7f)
            end
        end

        return bxor(result, 0x63)
    end

    -- calculate S-Box and inverse S-Box of AES
    -- apply affine transformation to inverse in finite field 2^8
    local function calcSBox()
        for i = 0, 255 do
            local inverse = (i~=0) and invert(i) or i
            local mapped = affinMap(inverse)
            SBox[i] = mapped
            iSBox[mapped] = i
        end
    end

    -- Calculate round tables
    -- round tables are used to calculate shiftRow, MixColumn and SubBytes
    -- with 4 table lookups and 4 xor operations.
    local function calcRoundTables()
        for x = 0, 255 do
            local byte = SBox[x]
            table0[x] = putByte(mul(0x03, byte), 0)
                      + putByte(          byte , 1)
                      + putByte(          byte , 2)
                      + putByte(mul(0x02, byte), 3)
            table1[x] = putByte(          byte , 0)
                      + putByte(          byte , 1)
                      + putByte(mul(0x02, byte), 2)
                      + putByte(mul(0x03, byte), 3)
            table2[x] = putByte(          byte , 0)
                      + putByte(mul(0x02, byte), 1)
                      + putByte(mul(0x03, byte), 2)
                      + putByte(          byte , 3)
            table3[x] = putByte(mul(0x02, byte), 0)
                      + putByte(mul(0x03, byte), 1)
                      + putByte(          byte , 2)
                      + putByte(          byte , 3)
        end
    end

    -- Calculate inverse round tables
    -- does the inverse of the normal roundtables for the equivalent
    -- decryption algorithm.
    local function calcInvRoundTables()
        for x = 0, 255 do
            local byte = iSBox[x]
            tableInv0[x] = putByte(mul(0x0b, byte), 0)
                         + putByte(mul(0x0d, byte), 1)
                         + putByte(mul(0x09, byte), 2)
                         + putByte(mul(0x0e, byte), 3)
            tableInv1[x] = putByte(mul(0x0d, byte), 0)
                         + putByte(mul(0x09, byte), 1)
                         + putByte(mul(0x0e, byte), 2)
                         + putByte(mul(0x0b, byte), 3)
            tableInv2[x] = putByte(mul(0x09, byte), 0)
                         + putByte(mul(0x0e, byte), 1)
                         + putByte(mul(0x0b, byte), 2)
                         + putByte(mul(0x0d, byte), 3)
            tableInv3[x] = putByte(mul(0x0e, byte), 0)
                         + putByte(mul(0x0b, byte), 1)
                         + putByte(mul(0x0d, byte), 2)
                         + putByte(mul(0x09, byte), 3)
        end
    end

    -- rotate word: 0xaabbccdd gets 0xbbccddaa
    -- used for key schedule
    local function rotWord(word)
        local tmp = band(word, 0xff000000)
        return lshift(word, 8) + rshift(tmp, 24)
    end

    -- replace all bytes in a word with the SBox.
    -- used for key schedule
    local function subWord(word)
        return putByte(SBox[getByte(word, 0)], 0)
             + putByte(SBox[getByte(word, 1)], 1)
             + putByte(SBox[getByte(word, 2)], 2)
             + putByte(SBox[getByte(word, 3)], 3)
    end

    -- generate key schedule for aes encryption
    --
    -- returns table with all round keys and
    -- the necessary number of rounds saved in ROUNDS
    local function expandEncryptionKey(key)
        local keySchedule = {}
        local keyWords = math.floor(#key / 4)

        if (keyWords ~= 4 and keyWords ~= 6 and keyWords ~= 8)
        or (keyWords * 4 ~= #key) then
            print("Invalid key size: ", keyWords)
            return nil
        end

        keySchedule[ROUNDS] = keyWords + 6
        keySchedule[KEY_TYPE] = ENCRYPTION_KEY

        for i = 0, keyWords-1 do
            keySchedule[i] = putByte(key[i*4+1], 3)
                           + putByte(key[i*4+2], 2)
                           + putByte(key[i*4+3], 1)
                           + putByte(key[i*4+4], 0)
        end

        for i = keyWords, (keySchedule[ROUNDS]+1)*4 - 1 do
            local tmp = keySchedule[i-1]
            if i % keyWords == 0 then
                tmp = rotWord(tmp)
                tmp = subWord(tmp)
                local index = math.floor(i/keyWords)
                tmp = bxor(tmp, rCon[index])
            elseif keyWords > 6 and i % keyWords == 4 then
                tmp = subWord(tmp)
            end
            keySchedule[i] = bxor(keySchedule[(i-keyWords)], tmp)
        end

        return keySchedule
    end

    -- Inverse mix column
    -- used for key schedule of decryption key
    local function invMixColumnOld(word)
        local b0 = getByte(word, 3)
        local b1 = getByte(word, 2)
        local b2 = getByte(word, 1)
        local b3 = getByte(word, 0)

        return putByte(add(add(add(mul(0x0b, b1),
                                   mul(0x0d, b2)),
                                   mul(0x09, b3)),
                                   mul(0x0e, b0)), 3)
             + putByte(add(add(add(mul(0x0b, b2),
                                   mul(0x0d, b3)),
                                   mul(0x09, b0)),
                                   mul(0x0e, b1)), 2)
             + putByte(add(add(add(mul(0x0b, b3),
                                   mul(0x0d, b0)),
                                   mul(0x09, b1)),
                                   mul(0x0e, b2)), 1)
             + putByte(add(add(add(mul(0x0b, b0),
                                   mul(0x0d, b1)),
                                   mul(0x09, b2)),
                                   mul(0x0e, b3)), 0)
    end

    -- Optimized inverse mix column
    -- look at http://fp.gladman.plus.com/cryptography_technology/rijndael/aes.spec.311.pdf
    -- TODO: make it work
    local function invMixColumn(word)
        local b0 = getByte(word, 3)
        local b1 = getByte(word, 2)
        local b2 = getByte(word, 1)
        local b3 = getByte(word, 0)

        local t = bxor(b3, b2)
        local u = bxor(b1, b0)
        local v = bxor(t, u)
        v = bxor(v, mul(0x08, v))
        w = bxor(v, mul(0x04, bxor(b2, b0)))
        v = bxor(v, mul(0x04, bxor(b3, b1)))

        return putByte(bxor(bxor(b3, v), mul(0x02, bxor(b0, b3))), 0)
             + putByte(bxor(bxor(b2, w), mul(0x02, t           )), 1)
             + putByte(bxor(bxor(b1, v), mul(0x02, bxor(b0, b3))), 2)
             + putByte(bxor(bxor(b0, w), mul(0x02, u           )), 3)
    end

    -- generate key schedule for aes decryption
    --
    -- uses key schedule for aes encryption and transforms each
    -- key by inverse mix column.
    local function expandDecryptionKey(key)
        local keySchedule = expandEncryptionKey(key)
        if keySchedule == nil then
            return nil
        end

        keySchedule[KEY_TYPE] = DECRYPTION_KEY

        for i = 4, (keySchedule[ROUNDS] + 1)*4 - 5 do
            keySchedule[i] = invMixColumnOld(keySchedule[i])
        end

        return keySchedule
    end

    -- xor round key to state
    local function addRoundKey(state, key, round)
        for i = 0, 3 do
            state[i] = bxor(state[i], key[round*4+i])
        end
    end

    -- do encryption round (ShiftRow, SubBytes, MixColumn together)
    local function doRound(origState, dstState)
        dstState[0] =  bxor(bxor(bxor(
                    table0[getByte(origState[0], 3)],
                    table1[getByte(origState[1], 2)]),
                    table2[getByte(origState[2], 1)]),
                    table3[getByte(origState[3], 0)])

        dstState[1] =  bxor(bxor(bxor(
                    table0[getByte(origState[1], 3)],
                    table1[getByte(origState[2], 2)]),
                    table2[getByte(origState[3], 1)]),
                    table3[getByte(origState[0], 0)])

        dstState[2] =  bxor(bxor(bxor(
                    table0[getByte(origState[2], 3)],
                    table1[getByte(origState[3], 2)]),
                    table2[getByte(origState[0], 1)]),
                    table3[getByte(origState[1], 0)])

        dstState[3] =  bxor(bxor(bxor(
                    table0[getByte(origState[3], 3)],
                    table1[getByte(origState[0], 2)]),
                    table2[getByte(origState[1], 1)]),
                    table3[getByte(origState[2], 0)])
    end

    -- do last encryption round (ShiftRow and SubBytes)
    local function doLastRound(origState, dstState)
        dstState[0] = putByte(SBox[getByte(origState[0], 3)], 3)
                    + putByte(SBox[getByte(origState[1], 2)], 2)
                    + putByte(SBox[getByte(origState[2], 1)], 1)
                    + putByte(SBox[getByte(origState[3], 0)], 0)

        dstState[1] = putByte(SBox[getByte(origState[1], 3)], 3)
                    + putByte(SBox[getByte(origState[2], 2)], 2)
                    + putByte(SBox[getByte(origState[3], 1)], 1)
                    + putByte(SBox[getByte(origState[0], 0)], 0)

        dstState[2] = putByte(SBox[getByte(origState[2], 3)], 3)
                    + putByte(SBox[getByte(origState[3], 2)], 2)
                    + putByte(SBox[getByte(origState[0], 1)], 1)
                    + putByte(SBox[getByte(origState[1], 0)], 0)

        dstState[3] = putByte(SBox[getByte(origState[3], 3)], 3)
                    + putByte(SBox[getByte(origState[0], 2)], 2)
                    + putByte(SBox[getByte(origState[1], 1)], 1)
                    + putByte(SBox[getByte(origState[2], 0)], 0)
    end

    -- do decryption round
    local function doInvRound(origState, dstState)
        dstState[0] =  bxor(bxor(bxor(
                    tableInv0[getByte(origState[0], 3)],
                    tableInv1[getByte(origState[3], 2)]),
                    tableInv2[getByte(origState[2], 1)]),
                    tableInv3[getByte(origState[1], 0)])

        dstState[1] =  bxor(bxor(bxor(
                    tableInv0[getByte(origState[1], 3)],
                    tableInv1[getByte(origState[0], 2)]),
                    tableInv2[getByte(origState[3], 1)]),
                    tableInv3[getByte(origState[2], 0)])

        dstState[2] =  bxor(bxor(bxor(
                    tableInv0[getByte(origState[2], 3)],
                    tableInv1[getByte(origState[1], 2)]),
                    tableInv2[getByte(origState[0], 1)]),
                    tableInv3[getByte(origState[3], 0)])

        dstState[3] =  bxor(bxor(bxor(
                    tableInv0[getByte(origState[3], 3)],
                    tableInv1[getByte(origState[2], 2)]),
                    tableInv2[getByte(origState[1], 1)]),
                    tableInv3[getByte(origState[0], 0)])
    end

    -- do last decryption round
    local function doInvLastRound(origState, dstState)
        dstState[0] = putByte(iSBox[getByte(origState[0], 3)], 3)
                    + putByte(iSBox[getByte(origState[3], 2)], 2)
                    + putByte(iSBox[getByte(origState[2], 1)], 1)
                    + putByte(iSBox[getByte(origState[1], 0)], 0)

        dstState[1] = putByte(iSBox[getByte(origState[1], 3)], 3)
                    + putByte(iSBox[getByte(origState[0], 2)], 2)
                    + putByte(iSBox[getByte(origState[3], 1)], 1)
                    + putByte(iSBox[getByte(origState[2], 0)], 0)

        dstState[2] = putByte(iSBox[getByte(origState[2], 3)], 3)
                    + putByte(iSBox[getByte(origState[1], 2)], 2)
                    + putByte(iSBox[getByte(origState[0], 1)], 1)
                    + putByte(iSBox[getByte(origState[3], 0)], 0)

        dstState[3] = putByte(iSBox[getByte(origState[3], 3)], 3)
                    + putByte(iSBox[getByte(origState[2], 2)], 2)
                    + putByte(iSBox[getByte(origState[1], 1)], 1)
                    + putByte(iSBox[getByte(origState[0], 0)], 0)
    end

    -- encrypts 16 Bytes
    -- key           encryption key schedule
    -- input         array with input data
    -- inputOffset   start index for input
    -- output        array for encrypted data
    -- outputOffset  start index for output
    local function encrypt(key, input, inputOffset, output, outputOffset)
        --default parameters
        inputOffset = inputOffset or 1
        output = output or {}
        outputOffset = outputOffset or 1

        local state = {}
        local tmpState = {}

        if key[KEY_TYPE] ~= ENCRYPTION_KEY then
            print("No encryption key: ", key[KEY_TYPE])
            return
        end

        state = bytesToInts(input, inputOffset, 4)
        addRoundKey(state, key, 0)

        local round = 1
        while (round < key[ROUNDS] - 1) do
            -- do a double round to save temporary assignments
            doRound(state, tmpState)
            addRoundKey(tmpState, key, round)
            round = round + 1

            doRound(tmpState, state)
            addRoundKey(state, key, round)
            round = round + 1
        end

        doRound(state, tmpState)
        addRoundKey(tmpState, key, round)
        round = round +1

        doLastRound(tmpState, state)
        addRoundKey(state, key, round)

        return intsToBytes(state, output, outputOffset)
    end

    -- decrypt 16 bytes
    -- key           decryption key schedule
    -- input         array with input data
    -- inputOffset   start index for input
    -- output        array for decrypted data
    -- outputOffset  start index for output
    local function decrypt(key, input, inputOffset, output, outputOffset)
        -- default arguments
        inputOffset = inputOffset or 1
        output = output or {}
        outputOffset = outputOffset or 1

        local state = {}
        local tmpState = {}

        if key[KEY_TYPE] ~= DECRYPTION_KEY then
            print("No decryption key: ", key[KEY_TYPE])
            return
        end

        state = bytesToInts(input, inputOffset, 4)
        addRoundKey(state, key, key[ROUNDS])

        local round = key[ROUNDS] - 1
        while (round > 2) do
            -- do a double round to save temporary assignments
            doInvRound(state, tmpState)
            addRoundKey(tmpState, key, round)
            round = round - 1

            doInvRound(tmpState, state)
            addRoundKey(state, key, round)
            round = round - 1
        end

        doInvRound(state, tmpState)
        addRoundKey(tmpState, key, round)
        round = round - 1

        doInvLastRound(tmpState, state)
        addRoundKey(state, key, round)

        return intsToBytes(state, output, outputOffset)
    end

    -- calculate all tables when loading this file
    calcSBox()
    calcRoundTables()
    calcInvRoundTables()

    -- Encrypt strings
    -- key - byte array with key
    -- string - string to encrypt
    -- modeFunction - function for cipher mode to use
    local function encryptString(key, data, modeFunction)
        local IV = IV or {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
        local keySched = expandEncryptionKey(key)
        local encryptedData = Buffer()
        for i = 1, #data/16 do
            local offset = (i-1)*16 + 1
            local byteData = {string.byte(data, offset, offset+15)}
            modeFunction(keySched, byteData, IV)
            encryptedData.addString(string.char(table.unpack(byteData)))
        end
        return encryptedData.toString()
    end

    -- Electronic code book mode encrypt function
    local function encryptECB(keySched, byteData, IV)
        encrypt(keySched, byteData, 1, byteData, 1)
    end

    -- Cipher block chaining mode encrypt function
    local function encryptCBC(keySched, byteData, IV)
        xorIV(byteData, IV)
        encrypt(keySched, byteData, 1, byteData, 1)
        for j = 1, 16 do
            IV[j] = byteData[j]
        end
    end

    -- Decrypt strings
    -- key - byte array with key
    -- string - string to decrypt
    -- modeFunction - function for cipher mode to use
    local function decryptString(key, data, modeFunction)
        local IV = IV or {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
        local keySched = expandDecryptionKey(key)
        local decryptedData = Buffer()
        for i = 1, #data/16 do
            local offset = (i-1)*16 + 1
            local byteData = {string.byte(data, offset, offset +15)}
            IV = modeFunction(keySched, byteData, IV)
            decryptedData.addString(string.char(table.unpack(byteData)))
        end
        return decryptedData.toString()
    end

    -- Electronic code book mode decrypt function
    local function decryptECB(keySched, byteData, IV)
        decrypt(keySched, byteData, 1, byteData, 1)
        return IV
    end

    -- Cipher block chaining mode decrypt function
    local function decryptCBC(keySched, byteData, IV)
        local nextIV = {}
        for j = 1, 16 do
            nextIV[j] = byteData[j]
        end
        decrypt(keySched, byteData, 1, byteData, 1)
        xorIV(byteData, IV)
        return nextIV
    end

    local function pwToKey(password, keyLen)
        keyLen = keyLen / 8
        local padlen = keyLen
        if keyLen == 192/8 then padlen = 32 end
        if padlen > #password then
            password = password .. string.char(0):rep(padlen-#password)
        else
            password = password:sub(1, padlen)
        end
        local pwBytes = {string.byte(password, 1, keyLen)}
        password = encryptString(pwBytes, password, encryptCBC)
        password = string.sub(password, 1, keyLen)
        return {string.byte(password, 1, #password)}
    end

    local encryptModeFunctions = {
        ecb = encryptECB,
        cbc = encryptCBC,
    }

    local decryptModeFunctions = {
        ecb = decryptECB,
        cbc = decryptCBC,
    }

    function crypt.AES(password, keyLen, mode)
        assert(password and #password > 0, "Empty password")
        keyLen = keyLen or 128
        mode = mode or "cbc"
        local encryptModeFunction = encryptModeFunctions[mode]
        local decryptModeFunction = decryptModeFunctions[mode]
        assert(keyLen==128 or keyLen==192 or keyLen==256, "Invalid key length")
        assert(encryptModeFunction and decryptModeFunction, "Invalid mode")
        local key = pwToKey(password, keyLen)
        local aes = {}
        function aes.encrypt(data)
            return encryptString(key, padByteString(data), encryptModeFunction)
        end
        function aes.decrypt(data)
            return unpadByteString(decryptString(key, data, decryptModeFunction))
        end
        return aes
    end

end

-----------------------------------------------------------------------
-- crypt.btea
-----------------------------------------------------------------------

-- [[ based on BTEA (http://en.wikipedia.org/wiki/XXTEA)
-- ]]

do
    function crypt.BTEA(key)

        local key16 = string.sub(key, 1, 16)
        for i = 17, #key, 16 do
            key16 = crypt.btea_encrypt(string.sub(key, i, i+15), key16)
        end

        local btea = {}

        function btea.encrypt(data)
            return crypt.btea_encrypt(key16, data)
        end

        function btea.decrypt(data)
            return crypt.btea_decrypt(key16, data)
        end
        return btea
    end
end

-----------------------------------------------------------------------
-- crypt.random
-----------------------------------------------------------------------

do
    function crypt.random(bits)
        local bytes = math.max(math.floor((bits+7)/8), 1)
        return crypt.BTEA(crypt.rnd(16))
            .encrypt(crypt.rnd(bytes))
            :sub(1, bytes)
    end
end
