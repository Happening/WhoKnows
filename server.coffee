Db = require 'db'
Event = require 'event'
Plugin = require 'plugin'
Timer = require 'timer'
Util = require 'util'
{tr} = require 'i18n'

questions = Util.questions()

exports.onInstall = !->
	Db.shared.set 'maxRounds', 0

# exports.onUpgrade = !->
# 	if !Db.shared.get('rounds')
# 		newRound()

exports.client_answer = (id, a) !->
	log "", Plugin.userId(), "answered:", a
	Db.shared.merge 'rounds', id, 'answers', Plugin.userId(), a

	# Count number of people who answered. If it is everyone, we can resolve the question. (Handy for local party mode)
	# No, there is no count() function for databased in the backend.
	answers = 0
	Db.shared.iterate 'rounds', id, 'answers', (a) !->
		answers++
	if answers is Plugin.userIds().length
		log "All users answered the question"
		Timer.cancel()
		Timer.set 45*1000, 'resolve' # resolve after 15 sec

exports.client_timer = setTimers = !->
	log "setTimers called"
	time = 0|(Date.now()*.001)
	roundDuration = Util.getRoundDuration(time)

	Timer.cancel()
	# if roundDuration > 3600
	Timer.set roundDuration*1000, 'resolve'
	Timer.set (roundDuration-120*60)*1000, 'reminder'
	Db.shared.set 'next', time+roundDuration

exports.client_newRound = exports.newRound = newRound = !->
	log "New Round!"
	maxRounds = Db.shared.get 'maxRounds'
	# find questions already used, select new one:
	used = []
	for i in [1..maxRounds]
		qid = Db.shared.get 'rounds', i, 'qid'
		used.push +qid

	available = []
	for q, nr in questions
		if +nr not in used and q[0] isnt null
			available.push +nr

	log "available", available.length
	if available.length
		maxRounds = Db.shared.incr 'maxRounds', 1
		newQuestion = available[Math.floor(Math.random()*available.length)]
		time = time = 0|(Date.now()*.001)
		Db.shared.set 'rounds', maxRounds,
			'qid': newQuestion
			'new': true
			'time': time
		log "made new question:", newQuestion, "(available", available.length, ")"

		setTimers()

		Event.create
			text: tr("New question!")

		if available.length is 1 # this was the last question
			Db.shared.set 'ooq', true # Out Of Question
		else
			Db.shared.remove 'ooq'

	else
		log "ran out of questions"

toAnswer = (a) ->
	["", "A", "B", "C", "D", "E", "F"].indexOf(a)

exports.client_resolve = exports.resolve = resolve = (roundId) !->
	if !roundId?
		roundId = +Db.shared.get('maxRounds')
	log "resolveRound", roundId
	question = Db.shared.ref 'rounds', roundId
	if !question?
		log "Question not found"
		return
	if !question.get('new')?
		log "Question already resolved"
		return
	answers = question.get('answers')||[]
	theAnswer = Util.getAnswer(roundId)

	getVotes = (uId) !->
		votes = 0
		for k,v of answers
			if +v is +uId then ++votes
		return votes

	for user in Plugin.userIds()
		v = answers[user]||-1 # v for value
		score = 0
		if v isnt -1
			ans = toAnswer(v) # has user given an actual answer?
			if ans < 0
				# lookup recursively if my chosen user had the correct answer
				target = answers[v]
				targets = [v]
				while toAnswer(target) <= 0
					target = answers[target]
					if target in targets
						break
					targets.push target
				ans = toAnswer(target)
			log Plugin.userName(user), " ans: ", ans
			if ans is theAnswer
				score+=3
		score += getVotes(user)
		# safe scores
		if score then question.set 'scores', user, score # score for this round. Not needed when it's zero
		Db.shared.incr 'scores', user, score # global

		question.set 'new', null # flag question as resolved

	Event.create
		unit: 'round'
		text: tr("%1\nResults are in!", Util.getQuestion(question.key())[0])

exports.reminder = !->
	roundId = Db.shared.get('maxRounds')
	remind = []
	for userId in Plugin.userIds()
		remind.push userId unless Db.shared.get('rounds', roundId, 'answers', userId)?

	if remind.length
		qId = Db.shared.get 'rounds', roundId, 'qid'
		time = 0|(Date.now()*.001)
		minsLeft = (Db.shared.get('next') - time) / 60
		if minsLeft<60
			leftText = tr("30 minutes")
		else
			leftText = tr("2 hours")

		Event.create
			for: remind
			unit: 'remind'
			text: tr("A question is waiting for your answer!")