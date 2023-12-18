local Toolbar = plugin:CreateToolbar("RayTerminal")
local Button = Toolbar:CreateButton("RayTerminal", 'All-in-one utility allows you to execute powerful commands without any interruptions', "rbxassetid://13002220487")
local Widget = plugin:CreateDockWidgetPluginGui(
    'RayTerminal',
    DockWidgetPluginGuiInfo.new(
        Enum.InitialDockState.Bottom,
        false,
        false,
        0,
        0,
        200,
        200
    )
)
local MainGui = require(script.Parent.GuiHandler).new(Widget)
MainGui:newTerminal('New Terminal')

Widget.Name = 'RayTerminal'
Widget.Title = "RayTerminal"
MainGui.Parent = Widget

Button.Click:Connect(function()
    Widget.Enabled = not Widget.Enabled
end)