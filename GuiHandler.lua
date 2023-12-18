local Console = {}
Console.__index = Console

local RunService = game:GetService('RunService')
local MarketplaceService = game:GetService("MarketplaceService")
local StudioService = game:GetService('StudioService')
local Players = game:GetService('Players')

local PLAYERID = StudioService:GetUserId()
local PREFIX = Players:GetNameFromUserIdAsync(PLAYERID) .. '@' .. MarketplaceService:GetProductInfo(game.PlaceId).Name

function Console.new(Widget)
    local self = setmetatable({
        Gui = script.Parent.MainGui:Clone(),
        Int = 1,
        Logs = {},
        Commands = {},
        Selected = {},
        OpenedTerminals = setmetatable({},{__index = function(t,k)
            for i,v in t do
                if v[1] == k then
                    return v
                end
            end
        end}),
        SelectedTerminal = nil,
        Colors = {
            Log = Color3.fromRGB(255, 255, 255),
            Command = Color3.fromRGB(255, 255, 255),
            Warn = Color3.fromRGB(255, 255, 0),
            Error = Color3.fromRGB(255, 0, 0),
            Success = Color3.fromRGB(0, 255, 0),
        },
        Connections = {
            Ancestry = nil,
        },
        Functions = nil,
        Directory = game,
        Prefix = PREFIX,
        GameName = MarketplaceService:GetProductInfo(game.PlaceId).Name
    }, Console)

    self.Functions = require(script.Parent.Functions)(self)
    self.Commands = require(script.Parent.Commands)(self)
    self.Gui.Parent = Widget

    --------------- Functions ------------

    local function CaptureFocus()
        RunService.RenderStepped:Wait()
        self.Gui.ScrollingFrame.TextBox:CaptureFocus()
    end

    --------------- Variables ------------

    local Tabs = self.Gui.Tabs
    local LastDirectory = self.Directory
    local LastFullName = self.Directory:GetFullName()
    
    CaptureFocus()
    
    --------------- Events ---------------
    
    RunService.RenderStepped:Connect(function(deltaTime)
        if self.Directory ~= LastDirectory then
            for i,v in self.Connections do
                if v then
                    v:Disconnect()
                end
            end

            if self.Directory == nil then
                self.Directory = game
                self.Gui[self.SelectedTerminal].TextBox.Text = self.Functions.GetPath(self.Prefix)
                self.OpenedTerminals[self.SelectedTerminal][2] = self.Directory
            else
                self.Connections['Ancestry'] = self.Directory.AncestryChanged:Connect(function()
                    if self.Directory:GetFullName():split('.')[1] ~= 'game' then
                        local index = LastFullName:find(self.Directory:GetFullName())
                        local newParentFullName = ''

                        pcall(function()
                            newParentFullName = LastFullName:sub(1, index - 2)
                        end)
                        
                        self.Directory = self.Functions.GetRawInstance(newParentFullName)
                        self.OpenedTerminals[self.SelectedTerminal][2] = self.Directory
                    end
                    self.Gui[self.SelectedTerminal].TextBox.Text = self.Functions.GetPath(self.Prefix)
                end)
            end
        end
        if self.Directory:GetFullName() ~= LastFullName then
            self.Gui[self.SelectedTerminal].TextBox.Text = self.Functions.GetPath(self.Prefix)
        end

        LastDirectory = self.Directory
        LastFullName = self.Directory:GetFullName()
    end)

    Tabs.Add.MouseButton1Click:Connect(function()
        self:newTerminal()
    end)

    --------------------------------------

    self.Gui.Tabs.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            CaptureFocus()
        end
    end)

    return self
end

function Console:newTerminal(name)
    local ScrollingFrame = self.Gui.ScrollingFrame:Clone()
    ScrollingFrame.Parent = self.Gui

    local TextBox = ScrollingFrame.TextBox
    local TextCache = TextBox.Text

    local ButtonFrame = self.Gui.Tabs.ScrollingFrame.ButtonFrame:Clone()
    ButtonFrame.Visible = true
    ButtonFrame.LayoutOrder = #self.OpenedTerminals
    ButtonFrame.Parent = self.Gui.Tabs.ScrollingFrame

    ButtonFrame.ButtonName.Text = ''

    TextBox.Text = self.Functions.GetPath(self.Prefix)

    TextCache = TextBox.Text

    local function updateVisuals()
        for i,v in self.Gui:GetChildren() do
            if v:IsA('ScrollingFrame') and v ~= ScrollingFrame then
                v.Visible = false
            else
                v.Visible = true
            end
        end

        for i,v in self.Gui.Tabs.ScrollingFrame:GetChildren() do
            if v:IsA('Frame') then
                for i,v in v:GetChildren() do
                    if v.Parent.Name == self.SelectedTerminal then
                        v.BackgroundColor3 = Color3.fromRGB(30,30,30)
                        v.BorderColor3 = Color3.fromRGB(40,40,40)
                    else
                        v.BackgroundColor3 = Color3.fromRGB(20,20,20)
                        v.BorderColor3 = Color3.fromRGB(30,30,30)
                    end
                end
            end
        end
    end

    local function captureFocus()
        RunService.RenderStepped:Wait()
        TextBox:CaptureFocus()
    end

    local function checkIfExists(name)
        local success = self.OpenedTerminals[ButtonFrame.ButtonName.Text]
        if not success and name ~= '' and not name:match("^%s*$") then
            ButtonFrame.ButtonName.Visible = false
            ButtonFrame.ButtonName.Text = name
            ButtonFrame.ButtonTitle.Text = name
            ButtonFrame.Name = name
            ButtonFrame.ButtonTitle.Visible = true

            ScrollingFrame.Visible = true

            self.SelectedTerminal = ButtonFrame.ButtonName.Text
            
            ScrollingFrame.Name = name

            updateVisuals()
            captureFocus()

            ---------------------------

            ScrollingFrame.InputEnded:Connect(function(input)
                if self.SelectedTerminal ~= name then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    captureFocus()
                end
            end)

            TextBox:GetPropertyChangedSignal('Text'):Connect(function()
                if TextBox.Text:sub(1,#(self.Functions.GetPath(PREFIX))) ~= self.Functions.GetPath(PREFIX) then
                    TextBox.Text = TextCache
                    TextBox.CursorPosition = #(self.Functions.GetPath(PREFIX)) + 1
                else
                    TextCache = TextBox.Text
                end
            end)

            TextBox:GetPropertyChangedSignal('CursorPosition'):Connect(function()
                if TextBox.CursorPosition < #(self.Functions.GetPath(PREFIX)) + 1 then
                    TextBox.CursorPosition = #(self.Functions.GetPath(PREFIX)) + 1
                end
            end)

            TextBox.FocusLost:Connect(function(enter)
                if enter then
                    self:enterCommand(TextBox.Text)
                end
            end)

            table.insert(self.OpenedTerminals, {ButtonFrame.ButtonName.Text, game})
        else
            ButtonFrame:Destroy()
            ScrollingFrame:Destroy()
            return
        end
    end

    ButtonFrame.ButtonTitle.MouseButton1Click:Connect(function()
        self.SelectedTerminal = ButtonFrame.Name
        self.Directory = self.OpenedTerminals[self.SelectedTerminal][2]
        updateVisuals()
    end)

    ButtonFrame.ButtonClose.MouseButton1Click:Connect(function()
        self:closeTerminal(ButtonFrame, ScrollingFrame)
    end)

    if name then
        checkIfExists(name)
        return
    end

    ButtonFrame.ButtonName.TextEditable = true
    ButtonFrame.ButtonName.ShowNativeInput = true
    ButtonFrame.ButtonName:CaptureFocus()

    ButtonFrame.ButtonName.FocusLost:Connect(function(enter)
        if enter then
            checkIfExists(ButtonFrame.ButtonName.Text)
            self.Directory = self.OpenedTerminals[self.SelectedTerminal][2]
        else
            if self.OpenedTerminals[ButtonFrame.ButtonName.Text] then return end
            ButtonFrame:Destroy()
        end
    end)
    
    return true
end

function Console:closeTerminal(ButtonFrame,ScrollingFrame)
    if #self.OpenedTerminals == 1 then return end
    for i,v in self.OpenedTerminals do
        if v[1] == ButtonFrame.ButtonName.Text then
            table.remove(self.OpenedTerminals, i)
        end
    end

    self.SelectedTerminal = self.OpenedTerminals[#self.OpenedTerminals][1]
    for i,v in self.Gui:GetChildren() do
        if v:IsA('ScrollingFrame') and v.Name ~= self.SelectedTerminal then
            v.Visible = false
        else
            v.Visible = true
        end
    end

    for i,v in self.Gui.Tabs.ScrollingFrame:GetChildren() do
        if v:IsA('Frame') then
            for i,v in v:GetChildren() do
                if v.Parent.Name == self.SelectedTerminal then
                    v.BackgroundColor3 = Color3.fromRGB(30,30,30)
                    v.BorderColor3 = Color3.fromRGB(40,40,40)
                else
                    v.BackgroundColor3 = Color3.fromRGB(20,20,20)
                    v.BorderColor3 = Color3.fromRGB(30,30,30)
                end
            end
        end
    end

    ButtonFrame:Destroy()
    ScrollingFrame:Destroy()
end

function Console:enterCommand(cmd)
    local Command = cmd:sub(#(self.Functions.GetPath(PREFIX)) + 1, -1)
    local Args = Command:split(' ')
    local CommandName = Args[1]
    table.remove(Args, 1)

    self:log(cmd, {Type = 'Log'})

    if self.Commands[CommandName] then
        self.Commands[CommandName].Function(Args)
    else
        self:log('Command not found', {Type = 'Error'})
    end

    self.Gui[self.SelectedTerminal].TextBox.Text = self.Functions.GetPath(PREFIX)

    RunService.RenderStepped:Wait()
    self.Gui[self.SelectedTerminal].TextBox:CaptureFocus()
end

function Console:log(msg, args)
    RunService.RenderStepped:Wait()
    args = args or {}

    local args = setmetatable(args,{
        __index = function(self, i)
            rawset(self, i, nil)
        end
    })

    args.Type = (args.Type == nil and 'Log') or args.Type
    args.Color = (args.Color == nil and (self.Colors[args.Type] or self.Colors.Log)) or args.Color

    table.insert(self.Logs, args)

    local LogMessage = self.Gui[self.SelectedTerminal].LogMessage:Clone()
    LogMessage.Name = self.Int
    LogMessage.Visible = true
    LogMessage.LayoutOrder = self.Int

    if args.Color == self.Colors.Log then
        LogMessage.Text = msg
        LogMessage.RichText = false
    else
        LogMessage.Text = self.Functions.Color(msg, args.Color)
    end

    LogMessage.TextColor3 = self.Colors.Log
    LogMessage.Parent = self.Gui[self.SelectedTerminal]

    local FontTags = self.Functions.CheckFontColorTags(LogMessage.Text)

    if FontTags then
        LogMessage.RichText = false
        LogMessage.TextColor3 = Color3.fromRGB(table.unpack(FontTags[1]))
        LogMessage.Text = FontTags[2]
    else
        LogMessage.RichText = true
    end

    local children = self.Gui[self.SelectedTerminal]:GetChildren()
    self.Gui[self.SelectedTerminal].TextBox.LayoutOrder = self.Int + 1

    self.Int += 1
    self.Gui[self.SelectedTerminal].CanvasSize = UDim2.new(0, self.Gui[self.SelectedTerminal].UIListLayout.AbsoluteContentSize.X, 0, self.Gui[self.SelectedTerminal].UIListLayout.AbsoluteContentSize.Y)
    self.Gui[self.SelectedTerminal].CanvasPosition = Vector2.new(0, self.Gui[self.SelectedTerminal].CanvasSize.Y.Offset)

    for i=#children,1,-1 do
        local v = children[i]

        if v.Name ~= 'TextBox' and not v:IsA('UIListLayout') then
            if v.RichText == false and v.TextColor3 == self.Colors.Log then
                if children[i-1]:IsA('TextBox') then
                    if children[i-1].RichText == false and children[i-1].Name ~= 'TextBox' and children[i-1].TextColor3 == self.Colors.Log then
                        children[i-1].Text = children[i-1].Text..'\n'..v.Text
                        v:Destroy()
                    end
                end
            else
                continue
            end
        end
    end
end

return Console