game.Players.LocalPlayer.Idled:Connect(function()
  game:GetService('VirtualUser'):Button2Down(Vector2.new(), workspace.CurrentCamera.CFrame)
	game:GetService('VirtualUser'):Button2Up(Vector2.new(), workspace.CurrentCamera.CFrame)
end)
