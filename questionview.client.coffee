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
SoftNav = require 'softNav'
Icon = require 'icon'

# red, yellow x 4, light green, dark green
scoreColors = ['#ff6666', '#ff9e66', '#ffcf66', '#ffe866', '#fff566', '#80ff80', '#4dff7c']

timeOut = (if Util.debug() then 600 else 20) # you have 20 seconds to answer the question
questionID = 0
roundId = 0
order = []
question = []
questionOptions = []
solution = []
items = []
stateO = Obs.create('entering')
cooldownO = Obs.create(null)

renderAnswer = (i, isResult = false, empty = false) !->
	Dom.div !->
		if !isResult
			givenAnswer = Db.local.get('answer') || []
			selected = givenAnswer.indexOf i
		else
			i = solution[i]
			selected = i
		Dom.style
			backgroundColor: "hsl(#{360/5*i},100%,#{if selected>=0 and !isResult then 71 else 87}%)"
			position: 'relative'
			borderRadius: '2px'
			margin: "8px 0px 0px"# unless isResult
		Dom.div !->
			Dom.style
				Box: 'left'
				margin: '0px'
			Dom.div !->
				Dom.style
					_boxSizing: 'border-box'
					width: '28px'
					Box: 'middle center'
					fontWeight: 'bold'
					backgroundColor: "rgba(0,0,0,0.1)"
				# Dom.text if selected < 0 then "" else (selected+1)
				Dom.text ["A", "B", "C", "D"][i]
			Dom.div !->
				Dom.style
					Flex: true
					Box: 'middle'
					padding: "4px 8px"
					_boxSizing: 'border-box'
					minHeight: '30px'
				Dom.userText questionOptions[i] unless empty
			unless isResult or empty
				Dom.onTap !->
					if selected>=0 # we are already selected, remove ourself
						givenAnswer.splice selected, 1
					givenAnswer.push i
					Db.local.set 'answer', givenAnswer
					log "set order", i, givenAnswer
					# To the server
					Server.sync 'answer', roundId, givenAnswer, !->
						Db.shared.merge 'rounds', roundId, 'answers', Plugin.userId(), givenAnswer
			Dom.div !->
				if selected>=0 and !isResult
					Dom.style
						_boxSizing: 'border-box'
						width: '28px'
						Box: 'middle center'
						fontWeight: 'bold'
						backgroundColor: "rgba(255,255,255,0.4)"
					Dom.text (selected+1)

renderDraggableAnswer = (index, containerE) ->
	offsetO = Obs.create 0
	Dom.div !->
		Dom.style
			backgroundColor: "hsl(#{360/5*index},100%,87%)"
			position: 'relative'
			borderRadius: '2px'
			margin: "8px 0px 0px"# unless isResult
			_transform: "translateY(#{offsetO.get()}px)"
		Dom.div !->
			Dom.style
				Box: 'left'
				margin: '0px'
			Dom.div !->
				Dom.style
					_boxSizing: 'border-box'
					width: '28px'
					Box: 'middle center'
					fontWeight: 'bold'
					backgroundColor: "rgba(0,0,0,0.1)"
				Dom.text ["A", "B", "C", "D"][index]
			Dom.div !->
				Dom.style
					Flex: true
					Box: 'middle'
					padding: "4px 8px"
					_boxSizing: 'border-box'
					minHeight: '30px'
				Dom.userText questionOptions[index]
			Dom.div !->
				Dom.style
					Box: 'middle center'
				Icon.render
					data: 'reorder'
					color: '#bbb'
					size: 20
					style:
						margin: "2px 4px"

		setOffset = (offset) !->
			offsetO.set offset
		getOffset = ->
			offsetO.peek()


		# Draggable
		element = Dom.get()
		upperLimit = 0
		lowerLimit = 0
		oldY = 0
		curOrder = 0
		oldDraggedY = 0
		Dom.trackTouch (touch) ->
			return unless touch?
			draggedY = touch.y
			# limit draggedY to containing div
			draggedY = Math.max(lowerLimit, Math.min(upperLimit, draggedY))
			yPos = element.getOffsetXY().y - containerE.getOffsetXY().y

			# Touch start
			if touch.op&1
				# dragPosition = item.order # Start position
				upperLimit = containerE.height() - yPos - element.height()/2
				lowerLimit = -yPos
				oldY = yPos + element.height()/2
				curOrder = index
				oldDraggedY = draggedY
				log "limit:", upperLimit, "(", containerE.height(), element.getOffsetXY().y,")"
				element.style
					backgroundColor: "hsl(#{360/5*index},100%,67%)"
					zIndex: "99"

			# Touch move
			element.style _transform: "translateY(#{draggedY}px)"
			direction = draggedElementY > oldY

			# higher sample rate
			draggedElementY = 0
			draggedDelta = draggedY-oldDraggedY
			while Math.abs(draggedDelta) > 5
				draggedDelta += if draggedDelta > 0 then -5 else 5
				draggedElementY = yPos + draggedY + (element.height()/2) - draggedDelta
				onDrag(draggedElementY)

			draggedElementY = yPos + draggedY + (element.height()/2)
			onDrag(draggedElementY)

			oldDraggedY = draggedY

			# Touch end
			if touch.op&4 # touch is stopped
				element.style backgroundColor: "hsl(#{360/5*index},100%,87%)"
				element.style
					_transform: "translateY(0)"
					zIndex: ''
				# set order, ready for redraw

			oldY = draggedElementY

		onDrag = (draggedElementY) !->
			for item, i in items
				if i is index
					continue
					# above myself. no order change?
				trans = item.getOffset()
				if draggedElementY > item.yTop+trans and draggedElementY < item.yBot+trans

					# if over top or bottom half?
					if draggedElementY < item.yHalf+trans # top half
						item.e.style border: '1px solid blue'
						log curOrder, item.order
						if curOrder > item.order
							t = if trans < 0 then 0 else element.height()+8
							item.setOffset t
							curOrder = item.order
							item.order++
					else # bottom half
						item.e.style border: '1px solid red'
						if curOrder < item.order
							curOrder = item.order
							item.order--
							t = if trans > 0 then 0 else -(element.height()+8)
							item.setOffset t
				else
					item.e.style border: ''

		# return stuff we want in the items array
		setTimeout !-> # after draw call
			r =
				height: element.height()
				halfHeight: element.height()/2
				yTop: (element.getOffsetXY().y - containerE.getOffsetXY().y)
				yHalf: (element.getOffsetXY().y - containerE.getOffsetXY().y) + element.height()/2
				yBot: (element.getOffsetXY().y - containerE.getOffsetXY().y) + element.height()
				order: index
				e: element
				setOffset: setOffset
				getOffset: getOffset
			items.push r
		, 0


renderShortAnswer = (i) !->
	Dom.div !->
		Dom.style
			_boxSizing: 'border-box'
			Flex: true
			Box: 'middle center'
			height: '30px'
			margin: '0px 4px'
			fontWeight: 'bold'
			backgroundColor: "hsl(#{360/5*i},100%,87%)"
			borderRadius: '2px'
		Dom.text ["A", "B", "C", "D"][i]

startTimer = !->
	Db.local.set 'start', Math.floor(0|(Date.now()*.001))
	# already set the answer on the server to "user gave no answer"
	Server.sync 'answer', roundId, -1, !->
		Db.shared.merge 'rounds', roundId, 'answers', Plugin.userId(), -1

endTimer = !->
	Db.local.remove 'start'

# vote = (v) !->
# 	Server.sync 'vote', roundId, v, !->
# 		Db.shared.merge 'rounds', roundId, 'votes', Plugin.userId(), v
# 	# endh Timer()

exports.render = ->
	roundId = Page.state.get(0)
	return whoknows() if Page.state.get(1) is "whoknows"

	Page.setTitle tr("Question")
	question = Util.getQuestion(roundId) # question array
	questionOptions = Util.getOptions(roundId) # options array, happening unique seed
	solution = Util.getSolution(roundId) # options array, user unique seed

	Dom.div !->
		Dom.text Db.local.get('answer')

	# determine state
	Obs.observe !->
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
					# reset stuff
					Db.local.set 'timePassed', false
					Db.local.remove 'answer'
					stateO.set 'entering'

		log "State:", stateO.peek()

	# Page
	Obs.observe !->
		switch stateO.get() 
			when 'entering'
				Dom.div !-> # question
					Dom.style
						textAlign: 'center'
					Dom.h4 tr("Are you ready to answer the question?")
			when 'voting'
				log "nothing"
			else
				renderQuestion()

	SoftNav.register 'entering', entering
	SoftNav.register 'answering', answering
	SoftNav.register 'answered', answered
	# SoftNav.register 'voting', voting
	SoftNav.register 'resolved', resolved
	SoftNav.render()

	# state machine (But not using function pointers)
	Obs.observe !->
		state = stateO.get()
		switch state
			when 'resolved'
				SoftNav.nav 'resolved'
			when 'answered'
				SoftNav.nav 'answered'
			when 'answering'
				Obs.observe count
				SoftNav.nav 'answering'
			when 'entering'
				SoftNav.nav 'entering'
			# when 'voting'
			# 	SoftNav.nav 'voting'

	if Util.debug()
		Ui.bigButton "Resolve", !->
			Server.send 'resolve', roundId

entering = !->
	renderTimer(true)
	Dom.div !->
		Ui.bigButton tr("Ready, go!"), !-> # start the thing
			Db.local.set 'start', (Date.now()*.001)
	Dom.section !->
		Dom.style padding: "0px 8px 8px"
		Dom.h4 !->
			Dom.text tr("Answers:")
		renderAnswers(true)

answering = !->
	renderTimer()
	Dom.section !->
		Dom.style padding: "0px 8px 8px"
		Dom.h4 !->
			Dom.text tr("Answers:")
		# renderAnswers()
		items = []
		Dom.div !->
			order = Db.shared.get('rounds', roundId, 'answers', Plugin.userId())||[0,1,2,3]
			Dom.text order
			renderDraggableAnswer(i, Dom.get()) for i in order
			# renderAnswer(1)
			# renderAnswer(2)
			# renderAnswer(3)

	Ui.bigButton tr("Done"), !->
		endTimer()

answered = !->
	Dom.section !->
		Dom.style padding: "0px 8px 8px"
		Dom.h4 !->
			Dom.text tr("The correct answer was:")
		renderAnswers(false, true)

	a = Db.shared.get('rounds', roundId, 'answers', Plugin.userId())||[]
	if !a.length
		Dom.div !-> # sorry
			Dom.style
				textAlign: 'center'
				padding: '20px'
			Dom.h4 !->
				Dom.text tr("Sorry, the time is up.")
	Dom.section !-> # given answer
		Dom.h4 tr("Your given answer was:")
		Dom.div !->
			Dom.style Box: 'center'
			renderShortAnswer(i) for i in a

	Ui.bigButton tr("Who knows?"), !->
		# stateO.set 'voting'
		Page.nav {0:roundId, 1:"whoknows"}

resolved = !->
	Dom.h4 !->
		Dom.style
			textAlign: 'center'
			fontSize: '90%'
		Dom.text tr("Correct answer was:")
	# renderAnswer(i, true) for i in [0..3]
	renderAnswers(false, true)

	Dom.section !->
		userVotes = Db.shared.get 'rounds', roundId, 'votes'

		getVotes = (uId) !->
			votes = 0
			for k,v of userVotes
				for k2,v2 of v
					if +k2 is +uId then ++votes
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
				Dom.text tr("score")
			Dom.div !->
				Dom.style Flex: true
				Dom.text tr("voted on")
			Dom.div !->
				Dom.style width: '35px'
				Dom.text tr("total")

		# User results
		Plugin.users.observeEach (user) !->
			Dom.div !->
				Dom.style
					Box: 'left middle'
					margin: '4px 8px'
				Ui.avatar Plugin.userAvatar(user.key()),
					style:
						margin: '0 0 1px 0'

				Dom.div !-> # score
					s = Db.shared.peek('rounds', roundId, 'scores', user.key())||0
					Dom.style
						width: '30px'
						height: '30px'
						lineHeight: '30px'
						fontSize: '18px'
						margin: "5px 0px 5px 5px"
						textAlign: 'center'
						borderRadius: '2px'
						backgroundColor: scoreColors[s]
					Dom.text s

				Dom.div !-> # show votes
					Dom.style
						margin: "5px 8px"
						Flex: true
						Box: 'left'
						overflow: 'hidden'
					votes = Db.shared.get('rounds', roundId, 'votes', user.key())||[]
					for k,v of votes
						Dom.div !->
							Dom.style
								position: 'relative'
							Ui.avatar Plugin.userAvatar(k),
								size: 28
								style:
									margin: '0px 2px'
							Dom.div !->
								Dom.style
									borderRadius: '50%'
									position: 'absolute'
									top: '0px'
									left: '2px'
									height: '30px'
									width: '30px'
									backgroundColor:  if v > 0 then "rgba(105, 240, 136, 0.3)" else "rgba(255, 102, 102, 0.3)"

				Dom.div !-> # totals
					r = Db.shared.peek('rounds', roundId, 'results', user.key())||0
					s = Db.shared.peek('rounds', roundId, 'scores', user.key())||0
					Dom.style
						width: '30px'
						height: '30px'
						lineHeight: '30px'
						fontSize: '18px'
						margin: "5px 0px 5px 5px"
						textAlign: 'center'
						borderRadius: '2px'
						backgroundColor: scoreColors[Math.min(6,(r+s))]
					Dom.text (r+s)
		, (user) -> -Db.shared.peek('rounds', roundId, 'scores', user.key())||0

count = !-> # ♫ Final countdown! ♬
	c = Db.local.peek('start') + timeOut # ten seconds
	c = Math.floor(c - (0|(Date.now()*.001)))
	cooldownO.set c
	if c > 0
		Obs.delay 1000, count
	else
		log "DING"
		endTimer()

renderQuestion = !->
	Dom.div !-> # question
		Dom.style
			textAlign: 'center'
		Dom.h4 question[0]

renderTimer = !->
	Dom.div !-> # timer
		Obs.observe !->
			Dom.style
				position: 'relative'
				height: '30px'
				backgroundColor: "hsl(#{130/timeOut*+(cooldownO.get()||timeOut)},100%, #{87 - Math.pow(timeOut-(cooldownO.get()||timeOut),1.5)}%)"
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
					backgroundColor: "hsl(#{130/timeOut*+(cooldownO.get()||timeOut)},100%, 50%)"
					_transform: "scaleX(#{(cooldownO.get()||timeOut)*0.1})"
					_transition: "transform 2s, background-color 1s linear"
					WebkitTransition_: "transform 1s linear, background-color 1s linear"
		Dom.div !->
			Dom.style
				_transform: 'translate3D(0,0,0)'
			Dom.text cooldownO.get()||timeOut

renderAnswers = (hideAnswers = false, solution = false) !->
	renderAnswer(i, solution, hideAnswers) for i in [0..3]

whoknows = !->
	# check if we arrived here validly
	if !Db.shared.get 'rounds', roundId, 'new'
		Ui.emptyText tr("Voting just closed, sorry!")
		return

	initialValue = Db.shared.peek('rounds', roundId, 'votes', Plugin.userId())||{}
	votesO = Obs.create initialValue
	initialValue = JSON.stringify initialValue
	log initialValue
	Dom.section !-> # other users
		Dom.style
			textAlign: 'center'

		hiddenForm = Form.hidden 'submitTrigger'

		Form.setPageSubmit (values) !->
			log "sync"
			Server.sync 'vote', roundId, votesO.peek(), !->
				Db.shared.merge 'rounds', roundId, 'votes', Plugin.userId(), votesO.peek()
			Page.back()

		Dom.div !->
			Dom.style textAlign: 'center'
			Dom.h4 tr("Select any number of people. You earn a point if they gave a correct answer. But you lose a point if they answered wrong.")

		size = (Page.width()-16) / Math.floor((Page.width()-0)/100)-1
		Plugin.users.observeEach (user) !->
			# return if +user.key() is Plugin.userId() # skip yourself
			Dom.div !->
				v = votesO.get()
				selected = v[user.key()]
				log selected
				Dom.style
					display: 'inline-block'
					position: 'relative'
					padding: '8px'
					boxSizing: 'border-box'
					borderRadius: '2px'

				Ui.avatar Plugin.userAvatar(user.key()),
					size: size-16
					style:
						display: 'inline-block'
						margin: '0 0 1px 0'
				if selected
					Icon.render
						data: Util.inverseCheck()
						color:  "rgba(105, 240, 136, 0.5)" #'#69f088'
						size: size-14
						style:
							borderRadius: '50%'
							position: 'absolute'
							top: '8px'
							left: '8px'
							background: "rgba(255, 255, 255, 0.5)"

				Dom.div !->
					Dom.style fontSize: '18px'
					Dom.text Form.smileyToEmoji user.get('name')
				Dom.onTap !->
					v = votesO.peek user.key()
					if v
						votesO.remove user.key()
					else
						votesO.set user.key(), true

					if JSON.stringify(votesO.peek()) is initialValue
						hiddenForm.value null
					else
						hiddenForm.value true

		, (user) -> user.get('name')

# old render result:

# legend
# Dom.div !->
# 	Dom.style
# 		Box: 'left'
# 		margin: '4px 8px'
# 		textAlign: 'center'
# 		fontWeight: 'lighter'
# 		color: '#888'
# 	Dom.div !->
# 		Dom.style width: '40px'
# 		Dom.text tr("user")
# 	Dom.div !->
# 		Dom.style width: '40px'
# 		Dom.text tr("votes")
# 	Dom.div !->
# 		Dom.style Flex: true
# 		Dom.text tr("answer")
# 	Dom.div !->
# 		Dom.style width: '35px'
# 		Dom.text tr("score")

# User results
# Plugin.users.observeEach (user) !->
# 	Dom.div !->
# 		Dom.style
# 			Box: 'left middle'
# 			margin: '4px 8px'
# 		Ui.avatar Plugin.userAvatar(user.key()),
# 			style:
# 				margin: '0 0 1px 0'

# 		Dom.div !-> # votes
# 			votes = getVotes user.key()
# 			Dom.style
# 				width: '30px'
# 				height: '30px'
# 				boxSizing: 'border-box'
# 				lineHeight: '30px'
# 				fontSize: '18px'
# 				margin: "5px"
# 				textAlign: 'center'
# 			Dom.text "+#{votes}"
# 		Dom.div !-> # given answer or vote
# 			Dom.style
# 				margin: "5px 1px"
# 				Flex: true
# 				Box: 'left'
# 			a = Db.shared.get('rounds', roundId, 'answers', user.key())||[]
# 			if !a.length
# 				Dom.style
# 					margin: "1px 5px"
# 					padding: "2px 8px"
# 					border: "1px solid #eee"
# 					color: '#aaa'
# 					borderRadius: '2px'
# 					Box: 'left middle'
# 					height: '24px'
# 				Dom.text tr("has given no answer")
# 			else
# 				renderShortAnswer(i) for i in a

# 		Dom.div !-> # score
# 			s = Db.shared.peek('rounds', roundId, 'scores', user.key())||0
# 			v = getVotes user.key()
# 			c = 0
# 			if (s-v) is 3 then c+=2
# 			if v then ++c
# 			Dom.style
# 				width: '30px'
# 				height: '30px'
# 				lineHeight: '30px'
# 				fontSize: '18px'
# 				margin: "5px 0px 5px 5px"
# 				textAlign: 'center'
# 				borderRadius: '2px'
# 				backgroundColor: scoreColors[c]
# 			Dom.text s
# , (user) -> -Db.shared.peek('rounds', roundId, 'scores', user.key())||0