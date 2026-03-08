local mod_storage = core.get_mod_storage()

local function get_player_scores_from_mod_storage ()
    local player_scores = core.deserialize(mod_storage:get_string("player_scores"))

    if not player_scores then
        player_scores = {}
    end

    return player_scores
end

local player_scores = get_player_scores_from_mod_storage()
local score_huds = {}
local ranking_huds = {}

core.register_on_joinplayer(function(player)
    local player_name = player:get_player_name()

    if not player_scores[player_name] then
        player_scores[player_name] = 0
    end

    scores.create_score_hud(player)
    scores.create_ranking_hud(player)
end)

core.register_on_leaveplayer(function(player)
    score_huds[player:get_player_name()] = nil
    ranking_huds[player:get_player_name()] = nil
end)

core.register_privilege("score_mod", {
    description = "Can change the scores of players",
    give_to_singleplayer = false
})

core.register_chatcommand("changescore", {
    params = "<name> <amount>",
    description = "Changes the score of the player with the given amount",
    privs = {
        score_mod = true,
    },
    func = function(player_name, param)
        local params = param:split(" ")
        local target_player_name = params[1]
        local amount = tonumber(params[2])

        if not target_player_name then
            return false, "invalid player name"
        end

        if not amount or amount == "" then
            return false, "invalid amount"
        end

        local score = scores.change_score(target_player_name, amount)
        return true, "Changed score to " .. score .. " for player " .. target_player_name
    end
})

core.register_chatcommand("setscore", {
    params = "<name> <value>",
    description = "Set the score of the player to the given value",
    privs = {
        score_mod = true,
    },
    func = function(player_name, param)
        local params = param:split(" ")
        local target_player_name = params[1]
        local value = tonumber(params[2])

        if not target_player_name then
            return false, "invalid player name"
        end

        if not value or value == "" then
            return false, "invalid value"
        end

        local score = scores.set_score(target_player_name, value)
        return true, "Set score to " .. score .. " for player " .. target_player_name
    end
})

core.register_chatcommand("resetscores", {
    params = "",
    description = "Reset the score for all players",
    privs = {
        score_mod = true,
    },
    func = function(player_name, param)
        scores.reset_scores()

        return true, "Scores reset"
    end
})

core.register_chatcommand("getranking", {
    params = "",
    description = "Get al list of all scores",
    func = function(player_name, param)
        return true, scores.get_ranking()
    end
})

scores = {}

scores.inital_score = 0
scores.score_label = "Score: "
scores.ranking_label = "Ranking:"

scores.change_score = function(player_name, amount)
    return scores.set_score(player_name, scores.get_score(player_name) + amount)
end

scores.set_score = function(player_name, value)
    if not player_scores[player_name] then
        player_scores[player_name] = scores.inital_score
    end

    player_scores[player_name] = value

    scores.update_score_hud(player_name)
    scores.update_ranking_huds()
    scores.persist_scores()

    return player_scores[player_name]
end

scores.get_score = function(player_name)
    if not player_scores[player_name] then
        scores.set_score(player_name, scores.inital_score)
    end

    return player_scores[player_name]
end

scores.reset_scores = function ()
    for index, score in pairs(player_scores) do
        scores.set_score(index, scores.inital_score)
    end
end

scores.create_score_hud = function(player)
    local player_name = player:get_player_name()
    local score = scores.get_score(player_name)
    score_huds[player_name] = player:hud_add({
        hud_elem_type = "text",
        position = {x = 1, y = 0},
        offset = {x = -50,   y = 50},
        text = scores.score_label .. score,
        alignment = {x = -1, y = 1},
        scale = {x = 100, y = 100},
        number = 0xFFFFFF,
        size = {x=2, y=2},
    })
end

scores.update_score_hud = function(player_name)
    local player = core.get_player_by_name(player_name)
    if player then
        local hud_id = score_huds[player_name]
        player:hud_change(hud_id, "text", scores.score_label .. player_scores[player_name])
    end
end

scores.create_ranking_hud = function(player)
    local player_name = player:get_player_name()
    ranking_huds[player_name] = player:hud_add({
        hud_elem_type = "text",
        position = {x = 1, y = 0},
        offset = {x = -50,   y = 100},
        text = scores.ranking_label .. scores.get_ranking(),
        alignment = {x = -1, y = 1},
        scale = {x = 100, y = 100},
        number = 0xFFFFFF,
        size = {x=1, y=1},
        style = 4
    })
end

scores.update_ranking_huds = function()
    local hud_text = scores.ranking_label .. scores.get_ranking()

    for player_name in pairs(ranking_huds) do
        local player = core.get_player_by_name(player_name)
        if player then            
            player:hud_change(ranking_huds[player_name], "text", hud_text)
        end
    end
end

scores.get_ranking = function()
    local position = 1
    local max_player_name_length = 19
    local sorted_player_scores = scores.get_sorted_score_list()
    local max_score_length = string.len(tostring(sorted_player_scores[1].score))

    local ranking = string.rep(" ", (max_player_name_length + max_score_length + 6) - string.len(scores.ranking_label)) .. "\n"

    for index, value in ipairs(sorted_player_scores) do
        local position_string = position .. ") "
        if position < 10 then
            position_string = " " .. position_string
        end

        local player_string = string.rep(" ", max_player_name_length - string.len(value.name)) .. value.name .. ": "
        local score_string = string.rep(" ", max_score_length - string.len(player_scores[value.name])) .. player_scores[value.name]

        ranking = ranking .. position_string  .. player_string .. score_string .. "\n"

        position = position + 1
        if position > 20 then
            break
        end
    end

    return ranking
end

scores.get_sorted_score_list = function()
    local list = {}
    for name, sc in pairs(player_scores) do
        table.insert(list, { name = name, score = sc })
    end

    table.sort(list, function(a,b) return a.score > b.score end)
    return list
end

scores.persist_scores = function ()
    mod_storage:set_string("player_scores", core.serialize(player_scores))
end
