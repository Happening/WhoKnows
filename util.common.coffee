Db = require 'db'
Plugin = require 'plugin'
{tr} = require 'i18n'

# Determines duration of the round started at 'currentTime'
# This comes from the Ranking Game plugin
exports.getRoundDuration = (currentTime) ->
	return false if !currentTime

	duration = 6*3600 # six hours
	while 22 <= (hrs = (new Date((currentTime+duration)*1000)).getHours()) or hrs <= 9
		duration += 6*3600

	duration

exports.getQuestion = (roundId) ->
	id = Db.shared.peek 'rounds', roundId, 'qid'
	return questions()[id]

exports.getAnswer = (roundId) ->
	id = Db.shared.peek 'rounds', roundId, 'qid'
	q = questions()[id]
	return q[q.length-1]

exports.myAnswer = (roundId) ->
	a = Db.shared.peek 'rounds', roundId, 'answers', Plugin.userId()
	return a || 0

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

exports.questions = questions = -> [
	# WARNING: indices are used, so don't remove items from this array (and add new questions at the end)
	# [0]: question, [1-x]: up to five answers, [x]: index of correct answer (1 is first answer)
	["How high is the Eiffel Tower (Without antenna)", "200m", "250m", "300m", "350m", 3]
	["How high is the Statue of Liberty", "58m", "74m", "88m", "93m", 4]
	["How high is the Empire State Building (to the tip)", "443m", "456m", "466m", "495m", 1]
	["How annoying is Rap music to listen to while working?", "very", "Nah, it ain't that bad", "Jo jo jo!", 3]
	["Why are iPhones so expensive?", "Because Apple can", "BOM + R&D + design + software + 30% margin = 700€", "S6 Edge costs more", "People are idiots", 1]
	["Deal or no Deal?", "Deal", "No Deal", "No wait!", "You don\'t want to be stuck with just one dollar!", 3]
	["Who is the best Star Trek captain?", "Kirk", "Picard", "Janeway", "Archer", "Pike", "Spock", 2]
	["Does this question work?", "yes", "no", "average", "ding!", 1]
	# WARNING: always add new questions to the end of this array
]
