local HttpService = game:GetService('HttpService')

return function(self)
    local Commands = setmetatable({},{__index = function(t,k)
        for i,v in t do
            if v.Name == k then
                return v
            end
        end
    end})

    local Flags = setmetatable({},{__index = function(t,k)
        for i,v in t do
            if v.Name == k then
                return v
            end
        end
    end})

    local function AddCommand(Name, Usage, Description, Function, LineBreak)
        table.insert(Commands, {
            ['Name'] = Name, 
            ['Usage'] = Usage,
            ['Description'] = Description, 
            ['Function'] = Function,
            ['LineBreak'] = LineBreak,
        })
    end

    local function AddFlag(Name, ExclusiveTo, Description, Function, LineBreak)
        table.insert(Flags, {
            ['Name'] = Name,
            ['ExclusiveTo'] = ExclusiveTo,
            ['Description'] = Description, 
            ['Function'] = Function,
            ['LineBreak'] = LineBreak,
        })
    end

    local function changeDirectory(dir)
        self.Directory = dir
        self.Gui[self.SelectedTerminal].TextBox.Text = self.Functions.GetPath(self.Prefix)
        self.OpenedTerminals[self.SelectedTerminal][2] = self.Directory
    end

    do -- flags
        AddFlag('-l', {'ls'}, 'Lists in full format', function(v)
            return v:GetFullName():gsub('%.', '/')
        end)

        AddFlag('-t', {'ls'}, 'Displays the type of instance', function(inst, v)
            local className = inst.ClassName
            local name = v

            return self.Functions.AlignColumns({name, className}, 100)
        end)

        AddFlag('-f', {'ls'}, 'Displays a / after each path that is a directory and * after scripts', function(inst, v)
            local name = v

            if inst:IsA('Folder') then
                name = name .. '/'
            elseif inst:IsA('LocalScript') or inst:IsA('ModuleScript') then
                name = name .. '*'
            end

            return name
        end)
        
        AddFlag('-l', {'fetch'}, 'Creates a local script', function(v)
            v.Type = 'LocalScript'
            return v
        end)

        AddFlag('-m', {'fetch'}, 'Creates a module script', function(v)
            v.Type = 'ModuleScript'
            return v
        end)

        AddFlag('-s', {'gitclone'}, 'Builds only script types (ModuleScript, Local Script, Script)', function(v)
            v.IsScriptOnly = true
            return v
        end)

        AddFlag('-p', {'gitclone'}, 'Uses the path name', function(v)
            v.Name = v.Path
            return v
        end)

        AddFlag('-p', {'mkdir'}, 'Creates nested directories at once', function(v)
            local path = v:split('/')
            local dir = self.Directory

            for i,v in ipairs(path) do
                if v == '' or v == nil then
                    self:log('Invalid Directory', {Type = 'Error'})
                    return
                end

                local newdir = dir:FindFirstChild(v)
                if newdir == nil then
                    newdir = Instance.new('Folder')
                    newdir.Name = v
                    newdir.Parent = dir
                end

                dir = newdir
                changeDirectory(dir)
            end

            return dir
        end)

        AddFlag('-m', {'cp'}, 'Copies multiple instances to the current directory', function(args)
            table.remove(args, 1)

            for i,v in args do
                local inst = self.Functions.GetInstance(v)
                if inst == nil then
                    self:log('Invalid Instance', {Type = 'Error'})
                    return
                end

                local succ, err = pcall(function()
                    local newinst = inst:Clone()
                    newinst.Parent = self.Directory
                end)

                if not succ then
                    self:log(err, {Type = 'Error'})
                    return
                end
            end
        end)
    end

    do -- commands
        AddCommand('cd', 'cd <dir>', 'Changes the current working directory', function(args)
            local dir = self.Functions.GetInstance(args[1])
            if dir == nil then
                changeDirectory(game)
                return
            end

            changeDirectory(dir)
        end)
        
        
        AddCommand('clear', 'clear', 'Clears the terminal', function(args)
            for i,v in self.Gui[self.SelectedTerminal]:GetChildren() do
                if v:IsA('TextBox') and v.Name ~= 'TextBox' and v.Name ~= 'LogMessage' then
                    v:Destroy()
                end
            end
            for i,v in self.Logs do
                table.remove(self.Logs, i)
            end

            self.Gui[self.SelectedTerminal].CanvasSize = UDim2.new(0,0,0,0)

            self.Int = 1
        end)


        AddCommand('cp', 'cp <flags?> <inst> <dir>', 'Copies an instance to a directory', function(args)
            if Flags[args[1]] then
                if table.find(Flags[args[1]].ExclusiveTo, 'cp') then
                    Flags[args[1]].Function(args)
                else
                    self:log('Invalid Flag', {Type = 'Error'})
                    return
                end
            else
                local inst = self.Functions.GetInstance(args[1])
                local dir = self.Functions.GetInstance(args[2]) or self.Directory

                if inst == nil then
                    self:log('Invalid Instance', {Type = 'Error'})
                    return
                end

                local succ, err = pcall(function()
                    local newinst = inst:Clone()
                    newinst.Parent = dir
                end)

                if not succ then
                    self:log(err, {Type = 'Error'})
                    return
                end
            end
        end)


        AddCommand('echo', 'echo <...>', 'Prints a message(s) to the terminal', function(args)
            for i,v in ipairs(args) do
                self:log(v)
            end
        end)


        AddCommand('exit', 'exit', 'Exits the terminal', function(args)
            self:closeTerminal()
        end)


        AddCommand('fetch', 'fetch <flags?> <url>', 'Fetches code from a link', function(args)
            local flags = {}

            for i, arg in ipairs(args) do
                if arg:sub(1, 1) == "-" then
                    table.insert(flags, arg)
                end
            end

            local input = {Url = args[#args], Type = 'Script'}

            if input.Url == nil or input.Url:match("^%s*$") or input.Url == '' then
                self:log('Invalid URL', {Type = 'Error'})
                return
            end

            for _,f in ipairs(flags) do
                if Flags[f] then
                    if table.find(Flags[f].ExclusiveTo, 'fetch') then
                        local flagoutput = Flags[f].Function(input)
    
                        if typeof(flagoutput) == 'string' then
                            input = flagoutput
                        end
                    else
                        self:log('Invalid Flag', {Type = 'Error'})
                        return
                    end
                else
                    self:log('Invalid Flag', {Type = 'Error'})
                    return
                end
            end

            local response
            local succ, err = pcall(function()
                response = HttpService:GetAsync(input.Url)
            end)

            if not succ then
                self:log(err, {Type = 'Error'})
                return
            end

            self:log('Fetched from ' .. input.Url, {Type = 'Success'})

            local Script = Instance.new(input.Type)
            Script.Name = input.Type
            Script.Source = response
            Script.Parent = self.Directory
        end)


        AddCommand('help', 'help', 'List all available commands', function(args)
            local Commands = self.Commands
            
            for i,v in ipairs(Commands) do
                if v.LineBreak then
                    self:log('')
                    continue
                end

                self:log(self.Functions.AlignColumns({v.Name, v.Usage, v.Description}), {Color = v.Color})
            end
            self:log('')
        end)


        AddCommand('helpf', 'helpf', 'List all available flags', function(args)
            for i,v in ipairs(Flags) do
                if v.LineBreak then
                    self:log('')
                    continue
                end

                self:log(self.Functions.AlignColumns({v.Name, table.concat(v.ExclusiveTo,' '), v.Description}, 100), {Color = v.Color})
            end
            self:log('')
        end)


        AddCommand('ls', 'ls <flags?>', 'List all instances in the current directory', function(args)
            local flags = {}

            for i, arg in ipairs(args) do
                if arg:sub(1, 1) == "-" then
                    table.insert(flags, arg)
                end
            end

            for i,v in ipairs(self.Directory:GetChildren()) do
                local succ, result = pcall(function()
                    return v.Name
                end)

                if not succ then
                    continue
                end

                local name = result

                for _,f in ipairs(flags) do
                    if Flags[f] then
                        if table.find(Flags[f].ExclusiveTo, 'ls') then
                            local flagoutput = Flags[f].Function(v, name)
    
                            if typeof(flagoutput) == 'string' then
                                name = flagoutput
                            end
                        else
                            self:log('Invalid Flag', {Type = 'Error'})
                            return
                        end
                    else
                        self:log('Invalid Flag', {Type = 'Error'})
                        return
                    end
                end

                self:log(name)
            end

            self:log('')
        end)


        AddCommand('mk', 'mk <type> <...>', 'Creates a new instance(s) of specified type of specified name', function(args)
            local type = args[1]
            
            if not pcall(function() Instance.new(type):Destroy() end) then
                self:log('Invalid Type', {Type = 'Error'})
                return
            end

            if #args == 1 then
                self:log('Invalid Name', {Type = 'Error'})
                return
            end

            table.remove(args, 1)

            for i,v in ipairs(args) do
                if v == nil or v:match("^%s*$") or v == '' then
                    self:log('Invalid Name', {Type = 'Error'})
                    return
                end

                local newinst = Instance.new(type)
                newinst.Name = v
                newinst.Parent = self.Directory
            end
        end)


        AddCommand('mkdir', 'mkdir <flags?> <...>', 'Creates a new directory(s) of specified name', function(args)
            for i,name in ipairs(args) do
                if Flags[args[1]] then
                    if i == 1 then
                        continue
                    end

                    if table.find(Flags[args[1]].ExclusiveTo, 'mkdir') then
                        Flags[args[1]].Function(name)
                    else
                        self:log('Invalid Flag', {Type = 'Error'})
                        return
                    end
                else
                    if name == nil or name:match("^%s*$") or name == '' then
                        self:log('Invalid Directory Name', {Type = 'Error'})
                        return
                    end
    
                    local newdir = Instance.new('Folder')
                    newdir.Name = name
                    newdir.Parent = self.Directory
                end
            end
        end)


        AddCommand('mv', 'mv <inst> <newdir>', 'Moves an instance to a new directory', function(args)
            local inst = self.Functions.GetInstance(args[1])
            local newDir = self.Functions.GetInstance(args[2])

            if inst == nil then
                self:log('Invalid Instance', {Type = 'Error'})
                return
            end

            if newDir == nil then
                self:log('Invalid Directory', {Type = 'Error'})
                return
            end

            pcall(function()
                inst.Parent = newDir
            end, function(err)
                self:log(err, {Type = 'Warn'})
            end)
        end)


        AddCommand('pwd', 'pwd', 'Prints the working directory', function(args)
            self:log(self.Functions.ConvertInstanceToDirectory(self.Directory))
        end)


        AddCommand('rm', 'rm <...>', 'Removes an instance(s)', function(args)
            for i,v in args do
                local inst = self.Functions.GetInstance(v)

                if inst == nil then
                    self:log('Invalid Instance', {Type = 'Error'})
                    return
                end

                if inst:IsA('Folder') then
                    self:log('Cannot remove a directory', {Type = 'Error'})
                    return
                end

                pcall(function()
                    inst:Destroy()
                end, function(err)
                    self:log(err, {Type = 'Warn'})
                end)
            end
        end)


        AddCommand('rmdir', 'rmdir <dir>', 'Removes a directory', function(args)
            local dir = self.Functions.GetInstance(args[1])

            if dir == nil or not dir:IsA('Folder') then
                self:log('Invalid Directory', {Type = 'Error'})
                return
            end
            
            pcall(function()
                changeDirectory(self.Directory.Parent)
                dir:Destroy()
            end, function(err)
                self:log(err, {Type = 'Warn'})
            end)
        end)
    end


    AddCommand(nil, nil, nil, nil, true)

    ---------------------------------------------------------------

    AddCommand('gitlist', 'gitlist <flags?> <repo-link>', 'lists the git-tree of a repository', function(args)
        local flags = {}

        for i, arg in ipairs(args) do
            if arg:sub(1, 1) == "-" then
                table.insert(flags, arg)
            end
        end

        local repo = args[#args]

        if repo == nil or repo:match("^%s*$") or repo == '' then
            self:log('Invalid URL', {Type = 'Error'})
            return
        end

        local indent = 0
        local maxDepth = 5

        local function search(url, path)
            if maxDepth == 0 then
                self:log('Max depth reached', {Type = 'Warn'})
            end

            local success, jsonResp = self.Functions.getGitHubRepo(url, path)

            if not success then
                self:log(jsonResp, {Type = 'Error'})
                return
            end

            if jsonResp == nil then
                self:log('Error requesting response', {Type = 'Error'})
                return
            end

            local decodedResponse = HttpService:JSONDecode(jsonResp)

            if decodedResponse == nil then
                self:log('Error decoding response', {Type = 'Error'})
                return
            end

            for _, entry in ipairs(decodedResponse) do
                local name = entry.name
                local path = entry.path
                local type = entry.type

                for _,f in ipairs(flags) do
                    if Flags[f] then
                        if table.find(Flags[f].ExclusiveTo, 'gitlist') then
                            local flagoutput = Flags[f].Function(entry)
        
                            if typeof(flagoutput) == 'string' then
                                name = flagoutput
                            end
                        else
                            self:log('Invalid Flag', {Type = 'Error'})
                            return
                        end
                    else
                        self:log('Invalid Flag', {Type = 'Error'})
                        return
                    end
                end

                if type == "dir" then
                    if indent == 0 then
                        indent = #entry.path:split('/') * 4
                        
                        self:log(string.rep(' ', indent) .. name .. '/')
                    else
                        self:log(string.rep(' ', indent) .. name .. '/')

                        indent = #entry.path:split('/') * 4
                    end

                    search(repo, path)
                elseif type == "file" then
                    indent = #entry.path:split('/') == 1 and 0 or #entry.path:split('/') * 4

                    self:log(string.rep(' ', indent) .. name)
                end
            end

            maxDepth = maxDepth - 1

            return true
        end

        if search(repo) then
            self:log('')
        end
    end)

    AddCommand('gitclone', 'gitclone <flags?> <repo-link>', 'Clones a repository to the current directory', function(args)
            local flags = {}

            for i, arg in ipairs(args) do
                if arg:sub(1, 1) == "-" then
                    table.insert(flags, arg)
                end
            end

            local repo = args[#args]
            
            if repo == nil or repo:match("^%s*$") or repo == '' then
                self:log('Invalid URL', {Type = 'Error'})
                return
            end
            
            local owner, repoName = repo:match("github.com/([^/]+)/([^/]+)")

            if repoName == nil then
                self:log('Invalid URL', {Type = 'Error'})
                return
            end

            local root = Instance.new('Folder', self.Directory)
            root.Name = repoName

            local function search(url, path)
                local success, jsonResp = self.Functions.getGitHubRepo(url, path)

                if not success then
                    self:log(jsonResp, {Type = 'Error'})
                    root:Destroy()
                    return false
                end

                if jsonResp == nil then
                    self:log('Error requesting response', {Type = 'Error'})
                    root:Destroy()
                    return false
                end

                local decodedResponse = HttpService:JSONDecode(jsonResp)

                if decodedResponse == nil then
                    self:log('Error decoding response', {Type = 'Error'})
                    root:Destroy()
                    return false
                end

                for _, entry in ipairs(decodedResponse) do
                    local name = entry.name
                    local path = entry.path
                    local type = entry.type
                    
                    local input = {OriginalName = name, Name = name, Path = path, Type = type, IsScriptOnly = false}

                    for _,f in ipairs(flags) do
                        if Flags[f] then
                            if table.find(Flags[f].ExclusiveTo, 'gitclone') then
                                input = Flags[f].Function(input)
                            else
                                self:log('Invalid Flag', {Type = 'Error'})
                                root:Destroy()
                                return false
                            end
                        else
                            self:log('Invalid Flag', {Type = 'Error'})
                            root:Destroy()
                            return false
                        end
                    end

                    if type == "dir" then
                        if input.IsScriptOnly == false then
                            local dir = root
    
                            if #path:split('/') > 1 then
                                for i,v in ipairs(path:split('/')) do
                                    local newDir = Instance.new('Folder')
                                    newDir.Name = v
                                    newDir.Parent = dir
        
                                    dir = newDir
                                end
                            end
                        end

                        search(repo, path)
                    elseif type == "file" then
                        if input.Name:match('%.lua') then
                            input.Name = name:gsub('%.lua', '')

                            local class = 'ModuleScript'

                            if input.Name:match('%.client') then
                                input.Name = input.Name:gsub('%.client', '')
                                class = 'LocalScript'
                            elseif input.Name:match('%.server') then
                                input.Name = input.Name:gsub('%.server', '')
                                class = 'Script'
                            end

                            local file = Instance.new(class)
                            file.Name = input.Name
                            file.Source = self.Functions.getGitHubFileContent(owner, repoName, path)
                            
                            if input.IsScriptOnly then
                                file.Parent = root
                            else
                                if #path:split('/') == 1 then
                                    file.Parent = root
                                else
                                    local dir = root

                                    for i,v in ipairs(path:split('/')) do
                                        if i == #path:split('/') then
                                            file.Parent = dir
                                        else
                                            dir = dir:FindFirstChild(v)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                return true, root
            end

            local success, dir = search(repo)

            if success then
                self:log('Successfully cloned ' .. repo .. ' to ' .. self.Functions.ConvertInstanceToDirectory(dir), {Type = 'Success'})
            end
        end)

    return Commands
end