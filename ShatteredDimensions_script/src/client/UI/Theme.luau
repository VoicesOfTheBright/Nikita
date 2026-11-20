local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(7, 9, 13),
	BackgroundSoft = Color3.fromRGB(11, 14, 19),
	Panel = Color3.fromRGB(15, 18, 24),
	PanelRaised = Color3.fromRGB(21, 25, 33),
	PanelHover = Color3.fromRGB(28, 33, 43),
	Line = Color3.fromRGB(47, 53, 65),
	LineSoft = Color3.fromRGB(30, 35, 44),
	Text = Color3.fromRGB(236, 241, 247),
	TextSoft = Color3.fromRGB(188, 196, 208),
	Muted = Color3.fromRGB(139, 148, 162),
	Dim = Color3.fromRGB(92, 101, 115),
	Savior = Color3.fromRGB(86, 220, 232),
	SaviorDark = Color3.fromRGB(27, 84, 91),
	LostSoul = Color3.fromRGB(235, 78, 88),
	LostSoulDark = Color3.fromRGB(88, 28, 34),
	Gold = Color3.fromRGB(238, 193, 101),
	Success = Color3.fromRGB(116, 218, 151),
	Warning = Color3.fromRGB(238, 193, 101),
	Danger = Color3.fromRGB(235, 78, 88),
	White = Color3.fromRGB(255, 255, 255),
	Black = Color3.fromRGB(0, 0, 0),
}

Theme.Fonts = {
	Display = Enum.Font.GothamBlack,
	Bold = Enum.Font.GothamBold,
	Medium = Enum.Font.GothamMedium,
	Body = Enum.Font.Gotham,
	Mono = Enum.Font.Code,
}

Theme.Corners = {
	Small = UDim.new(0, 6),
	Medium = UDim.new(0, 10),
	Large = UDim.new(0, 16),
	Pill = UDim.new(1, 0),
}

function Theme.roleColor(role)
	if role == "Savior" then
		return Theme.Colors.Savior
	elseif role == "LostSoul" then
		return Theme.Colors.LostSoul
	elseif role == "Spectator" then
		return Theme.Colors.Gold
	end
	return Theme.Colors.Muted
end

function Theme.toneColor(tone)
	if tone == "success" then
		return Theme.Colors.Success
	elseif tone == "warning" then
		return Theme.Colors.Warning
	elseif tone == "danger" then
		return Theme.Colors.Danger
	end
	return Theme.Colors.Savior
end

return Theme
