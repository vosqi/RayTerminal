local HttpService = game:GetService("HttpService")

return function(self)
    local functions = {}
    local escapes = {
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ["\""] = "&quot;",
        ["'"] = "&apos;",
        ["&"] = "&amp;"
    }

    local traverseprefix = '/'

    functions.ConvertInstanceToDirectory = function(instance)
        if instance == nil then
            instance = game
        end

        if self.Directory == game then
            return traverseprefix
        end
        return traverseprefix..instance:GetFullName():gsub('%.', '/')
    end

    functions.GetPath = function(prefix)
        if prefix then
            return prefix..functions.ConvertInstanceToDirectory(self.Directory):sub(1,#functions.ConvertInstanceToDirectory(self.Directory))..' ~ % '
        end
        return functions.ConvertInstanceToDirectory(self.Directory):sub(1,#functions.ConvertInstanceToDirectory(self.Directory))..' ~ % '
    end

    functions.SelectOnly = function(idx, ...)
        return ({...})[idx]
    end

    functions.RichEscape = function(text)
        return functions.SelectOnly(1, tostring(text):gsub(".", escapes))
    end

    functions.Color = function(msg,color)
        local r,g,b = color.R*255,color.G*255,color.B*255

        return string.format('<font color="rgb(%d,%d,%d)">%s</font>',r,g,b,functions.RichEscape(msg))
    end

    functions.from_base64 = function(data)
        local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
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
            return string.char(c)
        end))
    end

    functions.CheckFontColorTags = function(str)
        local single_tag_pattern = "<font%s+color%s*=%s*\"rgb%s*%(%s*%d+%s*,%s*%d+%s*,%s*%d+%s*%)\"%s*>[^<]+</font%s*>"
        local other_text_pattern = "(.-)<font%s+color%s*=%s*\"rgb%s*%(%s*%d+%s*,%s*%d+%s*,%s*%d+%s*%)\"%s*>([^<]+)</font%s*>(.-)"
        
        local match_single_tag = string.match(str, single_tag_pattern)
        if not match_single_tag then
            return {{self.Colors.Log.R*255,self.Colors.Log.G*255,self.Colors.Log.B*255}, str}
        else
            local match_count = 0
            for _ in string.gmatch(str, single_tag_pattern) do
                match_count = match_count + 1
                if match_count > 1 then
                    return nil
                end
            end
            local before, tag, after = string.match(str, other_text_pattern)
            if before ~= "" or after ~= "" then
                return nil
            else
                return {{str:match('rgb%((%d+),(%d+),(%d+)%)')}, str:match('>(.-)<')}
            end
        end
    end

    functions.AlignColumns = function(strings, width)
        width = width or 100

        if #strings == 0 then return "" end

        local max_lengths = {}
        for i, word in ipairs(strings) do
            max_lengths[i] = math.max(max_lengths[i] or 0, #word)
        end

        local column_width = math.floor((width - #strings + 1) / #strings)
        local format_str = {}
        for i, len in ipairs(max_lengths) do
            format_str[i] = "%-" .. column_width .. "s"
        end
        format_str[#strings] = "%-" .. (width - column_width * (#strings - 1)) .. "s"
        format_str = table.concat(format_str, string.rep(' ', #strings - 1))

        local padded = {}
        for i, word in ipairs(strings) do
            local padding = string.rep(' ', max_lengths[i] - #word)
            padded[i] = word .. padding
        end

        return string.format(format_str, table.unpack(padded))
    end

    functions.GetInstance = function(String)
        if String == traverseprefix or String == '~' then
            return game
        else
            local path
            local concatpath

            if String == nil then
                return nil
            end

            if String:sub(1,1) == '"' and String:sub(-1,-1) == '"' then
                return functions.GetRawInstance(String:sub(2,#String-1))
            end

            if String:sub(1,1) == traverseprefix and String:sub(-1,-1) == traverseprefix then
                path = String:sub(2,#String-1):split(traverseprefix)
            elseif String:sub(1,1) == traverseprefix then
                path = String:sub(2,-1):split(traverseprefix)
            else
                path = String:split(traverseprefix)
            end

            for i=1,#path do
                local v = path[i]
                if i == 1 then
                    pcall(function()
                        if v:sub(#v-1,-1) == ".." then
                            if self.Directory == game then
                                return nil
                            else
                                concatpath = self.Directory.Parent
                            end
                        else
                            concatpath = self.Directory[v]
                        end
                    end, function(err)
                        return nil
                    end)
                else
                    pcall(function()
                        if v:sub(#v-1,-1) == ".." then
                            concatpath = concatpath.Parent
                        else
                            concatpath = concatpath[v]
                        end
                    end, function(err)
                        return nil
                    end)
                end
            end

            return concatpath
        end
    end

    functions.GetRawInstance = function(String)
        if String == traverseprefix or String == self.GameName or String == 'game' then
            return game
        else
            local path
            local concatpath

            if String == nil then
                return nil
            end

            if String:sub(1,1) == traverseprefix and String:sub(-1,-1) == traverseprefix then
                path = String:sub(2,#String-1):split(traverseprefix)
            elseif String:sub(1,1) == traverseprefix then
                path = String:sub(2,-1):split(traverseprefix)
            else
                path = String:split(traverseprefix)
            end

            for i=1,#path do
                local v = path[i]
                if i == 1 then
                    pcall(function()
                        concatpath = game[v]
                    end, function(err)
                        return nil
                    end)
                else
                    pcall(function()
                        concatpath = concatpath[v]
                    end, function(err)
                        return nil
                    end)
                end
            end

            return concatpath
        end
    end

    functions.getGitHubRepo = function(url, path)
        if not url then
            return nil
        end

        local owner, repo = url:match("github.com/([^/]+)/([^/]+)")

        if not owner or not repo then
            return nil
        end

        local apiUrl 
        
        if path then
            apiUrl = string.format("https://api.github.com/repos/%s/%s/contents/%s", owner, repo, path)
        else
            apiUrl = string.format("https://api.github.com/repos/%s/%s/contents", owner, repo)
        end

        local headers = {
            ["Accept"] = "application/vnd.github+json"
        }

        local success, response = pcall(function()
            return HttpService:GetAsync(apiUrl, false, headers)
        end)

        return success, response
    end

    functions.getGitHubFileContent = function(owner, repo, path)
        if not owner or not repo or not path then
            return nil
        end

        local apiUrl = string.format("https://api.github.com/repos/%s/%s/contents/%s/", owner, repo, path)
        local headers = {
            ["Accept"] = "application/vnd.github+json"
        }

        local success, response = pcall(function()
            return HttpService:GetAsync(apiUrl, false, headers)
        end)

        if not success then
            return nil
        end

        local decodedResponse = HttpService:JSONDecode(response)

        -- Check if the entry is a file and has content
        if decodedResponse.type == "file" and decodedResponse.content then
            local content = decodedResponse.content
            return functions.from_base64(content)
        else
            return nil
        end
    end

    return functions
end