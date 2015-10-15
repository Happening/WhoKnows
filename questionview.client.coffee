Db = require 'db'
Dom = require 'dom'
Form = require 'form'
Modal = require 'modal'
Page = require 'page'
Plugin = require 'plugin'
Server = require 'server'
Obs = require 'obs'
Ui = require 'ui'
Util = require 'util'
{tr} = require 'i18n'

index = ["A", "B", "C", "D", "E", "F"]
# red, yellow, light green, dark green
scoreColors = ['#ff6666', '#fff480', '#80ff80', '#4dff7c']

questionID = 0
roundId = 0
question = []
stateO = Obs.create('entering')
cooldownO = Obs.create(null)
answersSectionE = null

toAnswer = (a) ->
	["", "A", "B", "C", "D", "E", "F"].indexOf(a)

renderAnswer = (i, isResult = false) !->
	Dom.div !->
		selected = false
		unless isResult
			selected = Db.local.get('answer') is index[i-1]
		Dom.style
			backgroundColor: "hsl(#{360/5*i},100%,#{if selected then 77 else 87}%)"
			position: 'relative'
			borderRadius: '2px'
			margin: "8px 0px 0px" unless isResult
		Dom.div !->
			Dom.style
				Box: 'left'
				margin: '0px'
			Dom.div !->
				Dom.style
					_boxSizing: 'border-box'
					width: '28px'
					textAlign: 'center'
					padding: '0px 6px'
					Box: 'middle'
					fontWeight: 'bold'
					backgroundColor: "rgba(0,0,0,0.1)"
				Dom.text "#{index[i-1]}:"
			Dom.div !->
				Dom.style
					Flex: true
					Box: 'middle'
					padding: "4px 8px"
					_boxSizing: 'border-box'
					minHeight: '30px'
				Dom.userText question[i]
			unless isResult
				Dom.onTap !->
					answer(index[i-1])
startTimer = !->
	Db.local.set 'start', Math.floor(0|(Date.now()*.001))
	# already set the answer on the server to "user gave no answer"
	Server.sync 'answer', roundId, -1, !->
		Db.shared.merge 'rounds', roundId, 'answers', -1

endTimer = !->
	Db.local.remove 'start'

answer = (a) !->
	# -1 didn't provide a answer in time earlier
	# 0 never answered the question yet
	# 1..inf answer was userId
	# A..E answer was one of the given options
	Db.local.set 'answer', a
	Server.sync 'answer', roundId, a, !->
		Db.shared.merge 'rounds', roundId, 'answers', Plugin.userId(), a

renderWarning = !->
	Modal.show tr("Question time")
		, tr("You are about to answer a question. You only have 10 seconds to choose an answer!")
		, (value) !->
			if value is 'back'
				Page.back()
			else # Engage answering mode
				Db.local.set 'timePassed', false
				Db.local.remove 'answer'
				startTimer()
			Modal.remove()
		, ['back', tr("Back"), 'ok', tr("OK!")]
	Obs.onClean !->
		Modal.remove()

exports.render = -> # a bit like a state machine
# (only without actual states but with various booleans... could have used an actual state machine. Observables are lovely for that)
	Page.setTitle tr("Question")
	roundId = Page.state.get(0)
	question = Util.getQuestion(roundId) # question array
	oldAnswer = Util.myAnswer(roundId) # my given answer

	# determine state
	Obs.observe !->
		if stateO.peek() isnt 'animateStop' # don't change state when in animation
			resolved = !Db.shared.get 'rounds', roundId, 'new'
			answered = Db.shared.peek 'rounds', roundId, 'answers', Plugin.userId()
			started = Db.local.get 'start'

			if resolved
				stateO.set 'resolved'
			else
				if answered and not started
					Db.local.set 'answer', answered
					stateO.set 'answered'
				else
					if started
						stateO.set 'answering'
					else
						stateO.set 'entering'

		log "State:", stateO.peek()

	# state machine (But not using function pointers)
	Obs.observe !->
		state = stateO.get()
		switch state
			when 'animateStop'
				renderQuestion()
				renderAnswers()
				answersSectionE.style # hide the answers
					height:'0px'
					padding: '0px 8px'
				setTimeout !->
					stateO.set 'answered'
				, 1000
			when 'resolved'
				renderQuestion()
				renderResolved()
			when 'answered'
				renderQuestion()
				renderResult()
			when 'answering'
				# count()
				Obs.observe count
				renderQuestion(true)
				renderAnswers()
			when 'entering'
				renderWarning()

count = !-> # ♫ Final countdown! ♬
	c = Db.local.peek('start') + 10 # ten seconds
	c = Math.floor(c - (0|(Date.now()*.001)))
	cooldownO.set c
	if c > 0
		log "count", c
		Obs.delay 1000, count
	else
		log "DING"
		stateO.set 'animateStop'
		endTimer()

renderQuestion = (withTimer) !->
	Dom.div !-> # question
		unless stateO.get() is 'entering'
			Dom.style
				textAlign: 'center'
				boxShadow: "0 2px 0 rgba(0,0,0,.1)"
			Dom.h4 question[0]
			if withTimer
				Dom.div !-> # timer
					Obs.observe !->
						Dom.style
							position: 'relative'
							height: '30px'
							backgroundColor: "hsl(#{360/30*+cooldownO.get()},100%, #{87 - Math.pow(10-cooldownO.get(),1.5)}%)"
							margin: "0px -8px"
							textAlign: 'center'
							color: 'black'
							boxSizing: 'border-box'
							padding: '2px'
							fontSize: '20px'
							_transition: "background-color 1s linear"
					Dom.div !->
						Obs.observe !->
							Dom.style
								position: 'absolute'
								top: '0px'
								left: '0px'
								width: '100%'
								height: '30px'
								backgroundColor: "hsl(#{360/30*+cooldownO.get()},100%, 50%)"
								_transform: "scaleX(#{cooldownO.get()*0.1})"
								_transition: "transform 2s, background-color 1s linear"
								WebkitTransition_: "transform 1s linear, background-color 1s linear"
					Dom.div !->
						Dom.style
							_transform: 'translate3D(0,0,0)'
						Dom.text cooldownO.get()||0

renderAnswers = !->
	Dom.div !->
		Dom.overflow()
		Dom.style
			margin: "0px -8px -8px"
			height: Page.height()-170 +'px'
			_transition: "height 1s ease, padding 1s ease"
		Dom.section !-> # answers
			Dom.style
				overflow: 'hidden'
				padding: '8px'
				boxSizing: 'border-box'
				maxHeight: '500px'
				_transition: "max-height 1s ease, padding 1s ease"
			Dom.div !-> # question
				Dom.style textAlign: 'center'
				Dom.h4 !->
					Dom.style margin: '0px'
					Dom.text tr("I know!")
			renderAnswer(i) for i in [1..question.length-2]
			answersSectionE = Dom.get()

		Dom.section !-> # other users
			Dom.style
				textAlign: 'center'

			Dom.div !->
				Dom.style textAlign: 'center'
				Dom.h4 tr("I don't know. But I think ... knows!")

			size = (Page.width()-16) / Math.floor((Page.width()-0)/100)-1
			Plugin.users.observeEach (user) !->
				return if +user.key() is Plugin.userId() # skip yourself
				Dom.div !->
					Dom.style
						display: 'inline-block'
						position: 'relative'
						padding: '8px'
						boxSizing: 'border-box'
						borderRadius: '2px'
						width: size+'px'
						backgroundColor: if Db.local.get('answer') is user.key() then "#ddd" else ""

					Ui.avatar Plugin.userAvatar(user.key()),
						size: size-16
						style:
							display: 'inline-block'
							margin: '0 0 1px 0'

					Dom.div !->
						Dom.style fontSize: '18px'
						Dom.text Form.smileyToEmoji user.get('name')
					Dom.onTap !->
						answer user.key()
			, (user) -> user.get('name')
		answersSectionE = Dom.get()

renderResult = !->
	Dom.div !-> # sorry
		Dom.style
			textAlign: 'center'
			padding: '20px'
		Dom.h4 !->
			Dom.text tr("Sorry, the time is up.")

	Dom.section !-> # given answer
		a = Db.local.peek('answer')
		ans = toAnswer(a)
		log a, ans
		if a <= 0
			Dom.h4 tr("You have given no answer.")
		else if ans > 0
			Dom.h4 tr("Your given answer was:")
			renderAnswer ans, true
		else if a > 0
			Dom.h4 tr("You've hope the following person to know answer:")
			Dom.style textAlign: 'center'
			Ui.avatar Plugin.userAvatar(a),
				size: 100
				style:
					display: 'inline-block'
					margin: '0 auto 1px'

renderResolved = !->
	Dom.h4 !->
		Dom.style
			textAlign: 'center'
			fontSize: '90%'
		Dom.text tr("Correct answer was:")
	renderAnswer question[question.length-1], true

	Dom.section !->
		userAnswers = Db.shared.get 'rounds', roundId, 'answers'

		getVotes = (uId) !->
			votes = 0
			for k,v of userAnswers
				if +v is +uId then ++votes
			return votes

		Dom.style
			margin: "8px -8px 0px"
			padding: "4px 0px"

		# legend
		Dom.div !->
			Dom.style
				Box: 'left'
				margin: '4px 8px'
				textAlign: 'center'
				fontWeight: 'lighter'
				color: '#888'
			Dom.div !->
				Dom.style width: '40px'
				Dom.text tr("user")
			Dom.div !->
				Dom.style width: '40px'
				Dom.text tr("votes")
			Dom.div !->
				Dom.style Flex: true
				Dom.text tr("answer")
			Dom.div !->
				Dom.style width: '35px'
				Dom.text tr("score")

		# User results
		Plugin.users.observeEach (user) !->
			Dom.div !->
				Dom.style
					Box: 'left middle'
					margin: '4px 8px'
				Ui.avatar Plugin.userAvatar(user.key()),
					style:
						margin: '0 0 1px 0'

				Dom.div !-> # votes
					votes = getVotes user.key()
					Dom.style
						width: '30px'
						height: '30px'
						boxSizing: 'border-box'
						lineHeight: '30px'
						fontSize: '18px'
						margin: "5px"
						textAlign: 'center'
					Dom.text "+#{votes}"
				Dom.div !-> # given answer or vote
					Dom.style
						Flex: true
					a = Db.shared.get 'rounds', roundId, 'answers', user.key()
					ans = toAnswer(a)
					if a <= 0 or !a?
						Dom.style
							margin: "5px"
							padding: "2px 8px"
							border: "1px solid #eee"
							color: '#aaa'
							borderRadius: '2px'
							Box: 'left middle'
							height: '24px'
						Dom.text tr("has given no answer")
					else if ans > 0
						Dom.style
							margin: "5px"
						renderAnswer ans, true
					else if a > 0
						Dom.style
							margin: "5px"
							backgroundColor: '#eee'
							borderRadius: '2px'
							Box: 'left middle'
							height: '30px'
						Ui.avatar Plugin.userAvatar(a),
							size: 28
						Dom.div !->
							Dom.style
								Flex: true
								padding: "4px"
							Dom.text Plugin.userName(a)
				Dom.div !-> # score
					s = Db.shared.peek('rounds', roundId, 'scores', user.key())||0
					v = getVotes user.key()
					c = 0
					if (s-v) is 3 then c+=2
					if v then ++c
					Dom.style
						width: '30px'
						height: '30px'
						lineHeight: '30px'
						fontSize: '18px'
						margin: "5px 0px 5px 5px"
						textAlign: 'center'
						borderRadius: '2px'
						backgroundColor: scoreColors[c]
					Dom.text s
		, (user) -> -Db.shared.peek('rounds', roundId, 'scores', user.key())||0