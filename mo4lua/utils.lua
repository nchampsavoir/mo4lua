local M = {} -- public interface

function M.hex_dump(buf)
  for i=1,math.ceil(#buf/16) * 16 do
     if (i-1) % 16 == 0 then io.write(string.format('%08X  ', i-1)) end
     io.write( i > #buf and '   ' or string.format('%02X ', buf:byte(i)) )
     if i %  8 == 0 then io.write(' ') end
     if i % 16 == 0 then io.write( buf:sub(i-16+1, i):gsub('%c','.'), '\n' ) end
  end
end

-- Concat the contents of the parameter list,
-- separated by the string delimiter (just like in perl)
-- example: strjoin(", ", {"Anna", "Bob", "Charlie", "Dolores"})
function M.str_join(delimiter, list)
  local len = #list
  if len == 0 then 
    return "" 
  end
  local string = list[1]
  for i = 2, len do 
    string = string .. delimiter .. list[i] 
  end
  return string
end

function M.array_concat(a, b)
    local t={}
    local n=0

    for _, v in pairs(a) do
        n=n+1
        t[n]=v
    end

    for _, v in pairs(b) do
        n=n+1
        t[n]=v
    end

    return t
end

function M.values(l, attr)
    local t={}
    local n=0

    for _, v in pairs(l) do
        n=n+1
        if attr then
          t[n]=v[attr]
        else
          t[n]=v
        end
    end

    return t
end

function M.table_length(tbl)
  local count = 0
  for _ in pairs(tbl) do count = count + 1 end
  return count
end

local dictionnary_mt = {
    __index = function (t, key) 
        local dt = M.dictionnary()
        t[key] = dt
        return dt
    end
}

--- Creates a table which default value is another table
function M.dictionnary()
    local t = {}
    setmetatable(t, dictionnary_mt)
    return t
end

local counter_mt = {
    __index = function (t, key) 
        t[key] = 0
        return 0
    end
}

--- Creates a table which default value is 0
function M.counter()
    local t = {}
    setmetatable(t, counter_mt)
    return t
end

return M
