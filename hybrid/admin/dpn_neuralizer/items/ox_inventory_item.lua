-- Optional ox_inventory item example. Add to ox_inventory/data/items.lua if you use ox_inventory.
-- Then wire the item to trigger the client event or keep /neuralizer enabled.

['neuralizer'] = {
    label = 'DPN Neuralizer',
    weight = 1000,
    stack = false,
    close = true,
    description = 'Advanced DPN flash-memory RP device. Admins are immune.',
    client = {
        event = 'dpn_neuralizer:client:use',
        image = 'neuralizer.png'
    }
},
