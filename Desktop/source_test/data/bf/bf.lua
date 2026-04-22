-- Judgement & Combo-Based Anims by SkyanUltra! :3c

-- CREDIT ME YOU FUCKING NIMROD!!! if you dont... i will KILL YOU!!! GRAAAAAAHHH!!!
-- GB Link: https://gamebanana.com/members/1729271
-- Bluesky Link: https://bsky.app/profile/skyanultra.bsky.social

-- vv Enable this for various debug info! vv
local debugTeehee = false

-- Animation Variables (Change these to whatever animations you want to play for certain ratings!)

local ampedSuffix = '-amped'

local midDance = false
local hasLipsync = true

local noteAnims = {
	{rating = 'normal', anims = {'singLEFT', 'singDOWN', 'singUP', 'singRIGHT'}},
	{rating = 'killer', anims = {'singLEFT-sick', 'singDOWN-sick', 'singUP-sick', 'singRIGHT-sick'}},
	{rating = 'sick', anims = {'singLEFT-sick', 'singDOWN-sick', 'singUP-sick', 'singRIGHT-sick'}},
	{rating = 'good', anims = {'singLEFT-good', 'singDOWN-good', 'singUP-good', 'singRIGHT-good'}},
	{rating = 'bad', anims = {'singLEFT-bad', 'singDOWN-bad', 'singUP-bad', 'singRIGHT-bad'}},
	{rating = 'shit', anims = {'singLEFT-bad', 'singDOWN-bad', 'singUP-bad', 'singRIGHT-bad'}},
}

local noteAura = 'BF'

-- Dynamic Variables (DO NOT TOUCH!!)

auraToggle = getModSetting('noteAuraToggle')
auraJudgement = getModSetting('noteAuraJudgement')
local lastRating = 'good'
local lipSyncSuffix = 'a'
hypeAmount = 0
amountNeededForHype = 0
local noteAmount = 0

function onCreate()
	setPropertyFromClass('substates.PauseSubState', 'songName', 'fromTheStop-bf');

	setPropertyFromClass('substates.GameOverSubstate', 'characterName', 'bf-dead');
	setPropertyFromClass('substates.GameOverSubstate', 'deathSoundName', 'gameOverDeath-bf');
	setPropertyFromClass('substates.GameOverSubstate', 'loopSoundName', 'gameOverLoop-bf');
	setPropertyFromClass('substates.GameOverSubstate', 'endSoundName', 'gameOverEnd-bf');
end

-- danceMid Code
function onCountdownTick(c)
	if midDance then
		countdownTimer = 30/bpm
		countdownC = c
		happenedBefore = false
		animPlaying = getProperty('boyfriend.atlas.anim.curSymbol.name')
	end
end

function onStepHit()
	if midDance then
	-- Checks if the current step is inbetween a beat
		if (curStep + 2) % 4 == 0 then
			-- Check the name of the current animation playing; if it's a danceLeft or danceRight, then play a danceMid animation!
			animPlaying = getProperty('boyfriend.atlas.anim.curSymbol.name') -- axor i freaking love you man
			if animPlaying == 'danceLeft-amped' or animPlaying == 'danceRight-amped' then
				playAnim('boyfriend', 'danceMid-amped', true)
			end
		end
	end
end

function onCreatePost()
	if auraToggle then
		makeAnimatedLuaSprite('noteAura', 'noteaura/noteaura_'..noteAura, defaultBoyfriendX-25, defaultBoyfriendY+200)
		addAnimationByPrefix('noteAura', 'aura', 'aura')
		setObjectOrder('noteAura', getObjectOrder('boyfriendGroup')+1)
		setProperty('noteAura.visible', false)
		addLuaSprite('noteAura', true)
	end

	-- This essentially calculates the total amount of notes in the chart on the player's side...
    for i = 0, getProperty('unspawnNotes.length')-1 do
        if getPropertyFromGroup('unspawnNotes', i, 'mustPress') and not getPropertyFromGroup('unspawnNotes', i, 'isSustainNote') then
            noteAmount = noteAmount + 1
        end
    end
	-- ... Then takes it all, divides it by 50, and rounds it down just to have it multiplied by 10 again.
	amountNeededForHype = math.floor((noteAmount / 50))*10
	-- Boom! Now its dynamic and adjusts to the chart's difficulty.
	if debugTeehee then debugPrint("Notes on Player Side: "..noteAmount.." | Amount Needed for Hype: "..amountNeededForHype) end
end

function goodNoteHit(id, dir, noteType, isSustainNote)
	-- This needs to be updated because Psych just kind of doesn't check the note type again after it changes?? Really weird shit.
	local noteType = getProperty('notes.members['..id..'].noteType')
	-- This increments a hidden value when non-sustain notes are hit that is for the combo and stores the last rating. (Done this way because its easier, LOL)
	if not isSustainNote then
		hypeAmount = hypeAmount + 1
		lastRating = getPropertyFromGroup('notes', id, 'rating')
	end
	-- Animations to play! Yes!
	if noteType == '0' or noteType == 'a' or noteType == 'e' or noteType == 'o' or noteType == 'beatbox' then
		if hasLipsync then
			if noteType ~= 'a' and noteType ~= 'e' and noteType ~= 'o' and noteType ~= 'beatbox' then
				if dir == 0 or dir == 2 then
					lipSyncSuffix = 'a'
				elseif dir == 1 then
					lipSyncSuffix = 'o'
				else
					lipSyncSuffix = 'e'
				end
			else
				lipSyncSuffix = noteType 
			end
		else
			lipSyncSuffix = ''
		end
		if noteType == 'beatbox' then
			playAnim('boyfriend', noteAnims[1].anims[dir+1]..'-beatbox', 'true')
		else
			for i = 1,#noteAnims do
				if lastRating == noteAnims[i].rating then
					playAnim('boyfriend', noteAnims[i].anims[dir+1]..lipSyncSuffix, 'true')
				end
			end
		end

		if auraToggle and not isSustainNote then
			if lastRating == 'killer' or (lastRating == 'sick' and auraJudgement == 'Sick') then
				playAnim('noteAura', 'aura', true)
				setProperty('noteAura.visible', true)
				setObjectOrder('noteAura', 69420) -- wow aren't i the funniest motherfucker in the whole wide world. where is my medal you BASTARDS.
				cancelTimer('noteAura')
				runTimer('noteAura', 0.33)
			end
		end
		-- ... And finally, the trigger for the amped up idle on combos.
		if hypeAmount >= amountNeededForHype then
			triggerEvent('Alt Idle Animation', 'bf', ampedSuffix)
			missAnimOverride(true)
		end
	end
	
	if debugTeehee and not isSustainNote then debugPrint("Rating: "..lastRating.." ("..noteType..") | Hype: "..hypeAmount.."/"..amountNeededForHype) end
end

function noteMiss(id, direction, noteType, isSustainNote)
	-- Special animation for when you break a combo while amped! (And obviously also resets combo counter and the idle)
	triggerEvent('Alt Idle Animation', 'bf', '')
	if hypeAmount >= amountNeededForHype then
		if debugTeehee then debugPrint("C-C-C-C-COMBO BREAKER!! | New Hype: "..hypeAmount.." -> "..hypeAmount / (misses + 1)) end
	elseif debugTeehee then debugPrint("you dumb fuck. | New Hype: "..hypeAmount.." -> "..hypeAmount / (misses + 1)) end
	hypeAmount = hypeAmount / (misses + 1)
    hypeAmount = math.floor(hypeAmount) 
end

function onTimerCompleted(t)
	if t == 'noteAura' then
		setProperty('noteAura.visible', false)
	end
end