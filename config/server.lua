return {
    -- Recyclable material rewards for dropoff
    dropoffRewards = {
        minAmount = 1,
        maxAmount = 5,
    },

    -- Location config (same as client)
    insideLocation = vec4(737.49, -1374.3, 11.63, 273.21),

    -- Loot table for trades (base items)
    itemTable = {
        [1] = 'metalscrap',
        [2] = 'plastic',
        [3] = 'copper',
        [4] = 'iron',
        [5] = 'aluminum',
        [6] = 'steel',
        [7] = 'glass',
    },

    -- Trading tiers: the more you trade, the better rewards
    -- chance items are awarded at certain thresholds
    tradeAmounts = {
        [1] = { -- Trade 1 recyclablematerial
            itemsRewardCount = { min = 1, max = 2 },
            chanceItems = {},
            luckyItems = {},
        },
        [5] = { -- Trade 5 recyclablematerial
            itemsRewardCount = { min = 2, max = 4 },
            chanceItems = {
                { item = 'cryptostick', chance = 10, qty = { min = 1, max = 1 } },
            },
            luckyItems = {},
        },
        [10] = { -- Trade 10 recyclablematerial
            itemsRewardCount = { min = 3, max = 5 },
            chanceItems = {
                { item = 'cryptostick', chance = 20, qty = { min = 1, max = 2 } },
            },
            luckyItems = {
                { item = 'rubber', chance = 15, qty = { min = 1, max = 3 } },
            },
        },
        [20] = { -- Trade 20+ recyclablematerial
            itemsRewardCount = { min = 4, max = 6 },
            chanceItems = {
                { item = 'cryptostick', chance = 35, qty = { min = 1, max = 3 } },
            },
            luckyItems = {
                { item = 'rubber', chance = 25, qty = { min = 2, max = 5 } },
            },
        },
    }
}