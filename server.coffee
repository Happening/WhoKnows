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
		Timer.set 120*1000, 'resolve' # resolve after 2 min

exports.client_vote = (id, votes) !->
	Db.shared.merge 'rounds', id, 'votes', Plugin.userId(), votes

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
	if available.length or true
		maxRounds = Db.shared.incr 'maxRounds', 1
		newQuestion = available[Math.floor(Math.random()*available.length)]
		time = time = 0|(Date.now()*.001)
		Db.shared.set 'rounds', maxRounds,
			'qid': 1#newQuestion
			'new': true
			'time': time
			'options': [1,2,3,4] # provide this in the 'correct' order. The client will rearrange them at random.
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
		# return
	answers = question.get('answers')||[]

	getVotes = (uId) !->
		votes = 0
		for k,v of answers
			if +v is +uId then ++votes
		return votes

	for user in Plugin.userIds()
		input = answers[user]||[]
		continue unless input.length
		target = Util.getSolution(roundId)
		# calc score using the V⁴ Method (van Viegen, van Vliet)
		# there are a maximum of 'steps' needed to bring any answer to the correct order. So the point range from 0 to 6
		errors = 0
		while input.length>0
			errors += index = target.indexOf(input[0])
			input.splice(0,1)
			target.splice(index,1)
		score = 6-errors
		log "user answer:", input, "solution:", target, "errors:", errors, "score:", score

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

# Old Method of calculating scores
# hits = 0
# for i in [0..3]
# 	t = input.slice(0) # clone, not point
# 	t.splice(t.indexOf(i),1)
# 	tt = target.slice(0) # clone, not point
# 	tt.splice(tt.indexOf(i),1)
# 	log 'testing', t, tt
# 	for j in [0..2]
# 		if t[j] is tt[j] then hits++
# score = Math.round(hits*10/12)