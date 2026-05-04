local library = loadstring(game:HttpGet('https://raw.githubusercontent.com/euryz/euryz/refs/heads/main/archived/eleriumv2/main.lua', true))()

local window = library:AddWindow("SkyWars GUI thing", {
	main_color = Color3.fromRGB(41, 74, 122),
	min_size = Vector2.new(250, 346),
	can_resize = false,
})

local features = window:AddTab("Features")
features:Show()



features:AddButton("Remove Anticheat",function()
	game:GetService("Players").LocalPlayer.PlayerGui.Extra.AntiSploitClient2:Destroy()
	wait(1)
	game:GetService("Players").LocalPlayer.PlayerGui.Extra.AntiSploitClient:Destroy()
end)




features:AddSwitch("Infinite Jump",function(bool)
	local Player = game:GetService("Players").LocalPlayer
	local Mouse = Player:GetMouse()
	Mouse.KeyDown:connect(function(k)
		if _G.infinjump then
			if k:byte() == 32 then
				Humanoid = game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
				Humanoid:ChangeState("Jumping")
				wait(0.1)
				Humanoid:ChangeState("Seated")
			end
		end
	end)

	if bool == 	true then
		_G.infinjump = true
	end

	if bool == false then
		_G.infinjump = false
	end
end)

features:AddSwitch("Autofarm Wins",function(chickenchickench)
	coolbrothatsnice = chickenchickench
	
	while coolbrothatsnice == true do
		local oh1 = CFrame.new(0.644594908, 264, 67.4945374)
		local oh2 = game:GetService("Players")
		local oh3 = oh2.LocalPlayer.Character.HumanoidRootPart


		oh3.CFrame = oh1
		wait()
	end
end)


--waypoints
local waypoints = features:AddFolder("Waypoints")





waypoints:AddButton("VIP Room",function()
	local oh1 = CFrame.new(0.129652873, 264, -72.7414246)
	local oh2 = game:GetService("Players")
	local oh3 = oh2.LocalPlayer.Character.HumanoidRootPart


	oh3.CFrame = oh1
end)

waypoints:AddButton("Mega VIP Room",function()
	local oh1 = CFrame.new(0.644594908, 264, 67.4945374)
	local oh2 = game:GetService("Players")
	local oh3 = oh2.LocalPlayer.Character.HumanoidRootPart


	oh3.CFrame = oh1
end)


waypoints:AddButton("Center Island",function()
	local oh1 = CFrame.new(11.3622465, 165.000183, -0.872686088)
	local oh2 = game:GetService("Players")
	local oh3 = oh2.LocalPlayer.Character.HumanoidRootPart


	oh3.CFrame = oh1
end)
waypoints:AddButton("Spawn Lobby",function()
	local oh1 = CFrame.new(-0.418475986, 268, -0.111892045)
	local oh2 = game:GetService("Players")
	local oh3 = oh2.LocalPlayer.Character.HumanoidRootPart


	oh3.CFrame = oh1 
end)

local second = waypoints:AddFolder("Custom Teleports")

second:AddButton("Save down cords",function()
	here = game.Players.LocalPlayer.Character.HumanoidRootPart.Position
end)

second:AddButton("Go to saved cords",function()
	game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(here)
end)
