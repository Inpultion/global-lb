-- Change the icon template below to your liking
return function(name: string, text: string, rank: number, displayName: string, thumbnail: string, showDisplayNameIfSameAsName: boolean)
	local nameLabelOffsetXPosition: number = 64
	
	local iconTemplateFrame: Frame = Instance.new("Frame")
	iconTemplateFrame.BorderSizePixel = 0
	iconTemplateFrame.BackgroundTransparency = 1
	iconTemplateFrame.Size = UDim2.new(1, 0, 0, 64)
	iconTemplateFrame.Name = name
	
	local rankLabel: TextLabel = Instance.new("TextLabel")
	rankLabel.Name = "Rank"
	rankLabel.Text = "#" .. tostring(rank)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Position = UDim2.new(0, 12, 0.5, 0)
	rankLabel.AnchorPoint = Vector2.new(0, 0.5)
	rankLabel.Size = UDim2.fromOffset(42, 42)
	rankLabel.TextColor3 = Color3.fromRGB(49, 49, 49)
	rankLabel.TextSize = 25
	rankLabel.Font = Enum.Font.GothamMedium
	rankLabel.Parent = iconTemplateFrame
	
	local uiCornerRankLabel: UICorner = Instance.new("UICorner")
	uiCornerRankLabel.CornerRadius = UDim.new(0.5, 0)
	uiCornerRankLabel.Parent = rankLabel
	
	local uiStrokeRankLabel: UIStroke = Instance.new("UIStroke")
	uiStrokeRankLabel.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStrokeRankLabel.Color = Color3.fromRGB(56, 56, 56)
	uiStrokeRankLabel.Parent = rankLabel
	
	if (thumbnail) then
		local thumbnailImage: ImageLabel = Instance.new("ImageLabel")
		thumbnailImage.Name = "Icon"
		thumbnailImage.BackgroundTransparency = 1
		thumbnailImage.Position = UDim2.new(0, 64, 0.5, 0)
		thumbnailImage.Size = UDim2.fromOffset(60, 60)
		thumbnailImage.AnchorPoint = Vector2.new(0, 0.5)
		thumbnailImage.Image = thumbnail
		thumbnailImage.Parent = iconTemplateFrame
		
		local uiCornerThumbnailImage: UICorner = Instance.new("UICorner")
		uiCornerThumbnailImage.CornerRadius = UDim.new(0.5, 0)
		uiCornerThumbnailImage.Parent = thumbnailImage

		local uiStrokeThumbnailImage: UIStroke = Instance.new("UIStroke")
		uiStrokeThumbnailImage.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		uiStrokeThumbnailImage.Color = Color3.fromRGB(56, 56, 56)
		uiStrokeThumbnailImage.Parent = thumbnailImage
		
		nameLabelOffsetXPosition = 128
	end
	
	local nameLabel: TextLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	
	if (displayName) then
		nameLabel.Text = displayName .. "<font color='rgb(125,125,125)'> (@" .. name .. ")</font>"
		
		if (not showDisplayNameIfSameAsName) then
			if (displayName == name) then
				nameLabel.Text = "@" .. name
			end
		end
	else
		nameLabel.Text = "@" .. name
	end
	
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, nameLabelOffsetXPosition, 0.5, 0)
	nameLabel.AnchorPoint = Vector2.new(0, 0.5)
	nameLabel.Size = UDim2.new(0.5, 0, 0, 32)
	nameLabel.RichText = true
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = iconTemplateFrame
	
	local valueLabel: TextLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	
	valueLabel.Text = tostring(text)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Position = UDim2.new(1, -8, 0.5, 0)
	valueLabel.AnchorPoint = Vector2.new(1, 0.5)
	valueLabel.Size = UDim2.new(0.24, 0, 0, 32)
	valueLabel.TextScaled = true
	valueLabel.Font = Enum.Font.GothamMedium
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Parent = iconTemplateFrame
	
	return iconTemplateFrame
end
