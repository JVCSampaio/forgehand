-- Built-in engine sounds are used as placeholders so the game has feedback
-- out of the box. Swap for Creator Store audio ids ("rbxassetid://...")
-- before launch; nothing else needs to change.

return {
	Pickup = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35 },
	Bank = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, Pitch = 0.6 },
	Upgrade = { Id = "rbxasset://sounds/switch.wav", Volume = 0.6 },
	Error = { Id = "rbxasset://sounds/button.wav", Volume = 0.5, Pitch = 0.6 },
	Collapse = { Id = "rbxasset://sounds/collide.wav", Volume = 0.9 },
	Dash = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.6 },
	Bump = { Id = "rbxasset://sounds/hit.wav", Volume = 0.7 },
	Glue = { Id = "rbxasset://sounds/splat.wav", Volume = 0.7 },
	Rare = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.9, Pitch = 1.6 },
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5 },
	-- Wind loop; HUD drives its volume from the wobble meter.
	Wobble = { Id = "rbxasset://sounds/action_falling.mp3", Volume = 0, Looped = true },
}
