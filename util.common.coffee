Db = require 'db'
Plugin = require 'plugin'
{tr} = require 'i18n'
Rand = require 'rand'

exports.debug = ->
	true

# Determines duration of the round started at 'currentTime'
# This comes from the Ranking Game plugin
exports.getRoundDuration = (currentTime) ->
	return false if !currentTime
	duration = 6*3600 # six hours
	while 22 <= (hrs = (new Date((currentTime+duration)*1000)).getHours()) or hrs <= 9
		duration += 6*3600
	return duration

exports.getQuestion = (roundId) ->
	id = Db.shared.peek 'rounds', roundId, 'qid'
	return questions()[id]

# we show [1..3] applied on key
exports.getOptions = (roundId) ->
	q = questions()[Db.shared.peek 'rounds', roundId, 'qid']
	k = getKey(roundId)
	return [q[k[0]+1], q[k[1]+1], q[k[2]+1], q[k[3]+1]]

# the solution is key, applied on key
exports.getSolution = (roundId) ->
	k = getKey(roundId)
	return [k[k[0]], k[k[1]], k[k[2]], k[k[3]]]

# the key is a random order of [1..3]
exports.getKey = getKey = (roundId) ->
	o = Db.shared.peek 'rounds', roundId, 'options'
	s = rndOrder(roundId)
	return [o[s[0]]-1, o[s[1]]-1, o[s[2]]-1, o[s[3]]-1]

exports.getWinner = (roundId) ->
	#walk through scores
	answers = Db.shared.get 'rounds', roundId, 'scores'
	winner = -1
	winningScore = -1
	for k,v of answers
		if v>winningScore
			winningScore = v
			winner = k
	return winner

exports.rndOrder = rndOrder = (roundId) ->
	seed = Plugin.groupId() + roundId
	srng = new Rand.Rand(seed)
	a = [0,1,2,3]
	r = []
	for x in [1..4]
		r.push a.splice(srng.rand2(0,a.length),1)
	return r


exports.questions = questions = -> [
	# WARNING: indices are used, so don't remove items from this array (and add new questions at the end)
	# [0]: question, [1-x]: the answers in the correct order
	["Sort Star Wars movies by release date", "A New Hope", "The Empire Strikes Back", "Return of the Jedi", "The Phantom Menace", "Attack of the Clones", "Revenge of the Sith", "The Force Awakens"]
	["Sort Muse albums by release date", "Showbiz", "Origin of Symmetry", "Absolution", "Black Holes and Revelations", "The Resistance", "2nd Law", "Drones"]
	# WARNING: always add new questions to the end of this array
]

exports.inverseCheck = ->
	[5,0,-3,"butt",-4,"miter",-5,4,4,2,0.019589437957492035,0.019589437957492035,2,2,0,0.0018773653552219825,2,2,0,0,4,2,1.0666666513406717,1.0666666513406717,2,2,-398.48159,-658.25586,5,0,-2,1,-6,1,7,0,10,2,398.48159,658.25586,11,2,398.48159,705.93359,11,2,446.33901,705.93359,11,2,446.33901,658.25586,11,2,398.48159,658.25586,12,0,10,2,437.2101,668.33789,11,2,440.01088,671.13672,11,2,416.01088,695.13672,11,2,404.81166,683.9375,11,2,407.61049,681.13672,11,2,416.01088,689.53711,11,2,437.2101,668.33789,12,0,8,1,"nonzero",6,0,6,0]