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
	["What African country is the Central Kalahari Game Reserve located in?", "Botswana", "Nigeria", "South Africa", "Kenya", 1]
	["What is the function served by the Paris building known as the Sorbonne?", "hospital", "school", "museum", "theater", 2]
	["Which one of the following countries is not known as one of the Baltic states?", "Albania ", "Estonia", "Latvia", "Lithuania", 1]
	["Which one of the following countries was not one of Germany\'s allies?", "Italy", "Bulgaria", "Turkey", "Austria-Hungary", 4]
	["The Gunpowder Plot conspirators tried to kill what ruler along with members of Parliament in 1605?", "Charles I", "Elizabeth I", "Henry VIII", "James I", 4]
	["Who enters the annual Van Cliburn International  Competition?", "chefs", "chess players", "pianists ", "squash players", 3]
	["The surrender of Germany in 1945 ended the Third Reich, when did the Second Reich end?", "1453", "1871", "1918", "1933", 3]
	["By the time Nelson Mandela was freed in 1990, how long had he been in prison?", "7 years", "17 years", "27 years", 3]
	["Violeta Barrios de Chamorro defeated whom in a 1989 presidential election?", "Alfredo Cristiani", "Daniel Ortega", "Jose Sarney", 2]
	["Which of the following countries does not border Israel?", "Egypt", "Jordan", "Saudi Arabia ", "Syria", 3]
	["What European capital city is located at the mouth of the Liffey River?", "Amsterdam", "Copenhagen", "Dublin", 3]
	["Ulan Bator is the capital of what country?", "Madagascar", "Mali", "Mongolia", 3]
	["Austria and which other country are connected by the Brenner Pass?", "Hungary", "Italy ", "Switzerland", 3]
	["Mount Erebus is what?", "an active volcano in the Antarctica", "an underwater peak off Greece that is a hazard to Mediterranean shipping", "a nearly 17,000-foot peak on the Iran-Turkey border, where Noah\'s Ark  may have landed.", 3]
	["Who wrote some of the Flash Gordon comic strips that appeared in Europe during World War II?", "Buster Crabbe", "Charles DeGaulle", "Federico Fellini ", "Hermann Hesse", 3]
	["When added together, which two countries have over 90 percent of the world\'s platinum reserves?", "Australia and south Africa", "Canada and the United States", "South Africa and the Soviet Union", 3]
	["What two countries border the Dead Sea?", "Israel and Egypt", "Israel and Jordan", "Jordan and Saudi Arabia", 2]
	["What industry supplies Botswana with more than 75% of its total revenue?", "cattle", "coffee", "diamonds ", "tourism", 3]
	["Jack the Ripper terrorized what city in the 19th century?", "Belfast", "London ", "New York", "San Francisco", 2]
	["The United Nations had 51 members when i was founded in 1945. How many members does it have now?", "59", "109", "159", 3]
	# WARNING: always add new questions to the end of this array
]
