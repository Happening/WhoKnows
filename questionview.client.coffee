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
# scoreColors = ['#ff6666', '#ff9e66', '#ffcf66', '#ffe866', '#fff566', '#80ff80', '#4dff7c']

questionTime = (if Util.debug() then 600 else 20) # you have 20 seconds to answer the question
enterDelay = 5
questionID = 0
roundId = 0
order = []
question = []
questionOptions = []
solution = []
items = []
stateO = Obs.create('entering')
cooldownO = Obs.create(null)
pingO = Obs.create true

renderAnswer = (i, isResult = false, empty = false, showOwn = false) !->
	answerIndex = (Db.local.get('answer') || [])[i]
	if isResult
		i = solution[i]
	Dom.div !->
		Dom.style
			position: 'relative'
			margin: "8px 0px 0px"# unless isResult
			Box: 'left'
		Dom.div !->
			Dom.style
				backgroundColor: "hsl(#{360/5*i},100%,87%)"
				Box: 'left'
				Flex: true
				borderRadius: '2px'
			Dom.div !->
				Dom.style
					_boxSizing: 'border-box'
					width: '28px'
					Box: 'middle center'
					fontWeight: 'bold'
					backgroundColor: "rgba(0,0,0,0.1)"
				Dom.text ["A", "B", "C", "D"][i]
			Dom.div !->
				Dom.style
					Flex: true
					Box: 'middle'
					padding: "4px 8px"
					_boxSizing: 'border-box'
					minHeight: '30px'
				if not empty
					Dom.userText questionOptions[i]
		if showOwn
			Dom.div !-> # your answer
				Dom.style
					_boxSizing: 'border-box'
					width: '28px'
					Box: 'middle center'
					fontWeight: 'bold'
					marginLeft: '8px'
					backgroundColor: "hsl(#{360/5*answerIndex},100%,87%)"
				Dom.text ["A", "B", "C", "D"][answerIndex]

renderDraggableAnswer = (index, containerE) ->
	offsetO = Obs.create 0
	Dom.div !->
		Obs.observe !->
			Dom.style
				backgroundColor: "hsl(#{360/5*index},100%,87%)"
				position: 'relative'
				borderRadius: '2px'
				margin: "8px 0px 0px"# unless isResult
				_transform: "translateY(#{offsetO.get()}px)"
				transition_: 'transform 0.4s ease-out'
				WebkitTransition_: 'transform 0.4s ease-out'
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

		element = Dom.get()

		# make item
		thisItem = {}
		remake = (idx, cE, o)->
			log "doing remake", idx, "height:", element.height()
			thisItem =
				height: element.height()
				halfHeight: element.height()/2
				yTop: (element.getOffsetXY().y - cE.getOffsetXY().y)
				yHalf: (element.getOffsetXY().y - cE.getOffsetXY().y) + element.height()/2
				yBot: (element.getOffsetXY().y - cE.getOffsetXY().y) + element.height()
				order: o
				value: idx
				e: element
				remake: remake
				setOffset: setOffset
				getOffset: getOffset
		log "main remake"
		thisItem = remake(index, containerE, items.length)
		items.push thisItem

		# Draggable
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
				lowerLimit = -yPos - element.height()/2
				oldY = yPos + element.height()/2
				curOrder = index
				oldDraggedY = draggedY
				element.addClass "dragging"

				# check if items hold actual values
				if not items[0].height
					log "----items list hold zeros----"
					newItems = []
					for oldItem, o in items
						newItems.push oldItem.remake(oldItem.value, containerE, o)
					items = newItems
					log items

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
				element.removeClass "dragging"
				element.style
					_transform: "translateY(0)"
				# set order, ready for redraw
				order = (i.order for i in items)
				value = (i.value for i in items)
				answer = []
				answer[order[i]] = value[i] for i in [0..3]
				Server.sync 'answer', roundId, answer, !->
					Db.shared.set('rounds', roundId, 'answers', Plugin.userId(), answer)

			oldY = draggedElementY

		onDrag = (draggedElementY) !->
			for item, i in items
				if item is thisItem
					continue
					# above myself. no order change?
				trans = item.getOffset()
				if draggedElementY > item.yTop+trans and draggedElementY < item.yBot+trans

					# if over top or bottom half?
					if draggedElementY < item.yHalf+trans # top half
						if Util.debug() then item.e.style border: '1px solid blue'
						if thisItem.order > item.order
							t = if trans < 0 then 0 else element.height()+8
							item.setOffset t
							temp = thisItem.order
							thisItem.order = item.order
							item.order = temp
					else # bottom half
						if Util.debug() then item.e.style border: '1px solid red'
						if thisItem.order < item.order
							t = if trans > 0 then 0 else -(element.height()+8)
							item.setOffset t
							temp = thisItem.order
							thisItem.order = item.order
							item.order = temp
				else
					item.e.style border: ''

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
		unless stateO.get() is 'entering'
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
				whoknows()
			when 'answering'
				Obs.observe count
				Form.setPageSubmit (values) !->
					log "done"
					endTimer()
				, 1
				SoftNav.nav 'answering'
			when 'entering'
				cooldownO.set enterDelay
				Obs.onTime enterDelay*1000, !->
					Db.local.set 'start', (Date.now()*.001)
				tick = !->
					timer = Obs.onTime 1000, !->
						tick()
						cooldownO.incr -1
				tick()
				SoftNav.nav 'entering'
			# when 'voting'
			# 	SoftNav.nav 'voting'

	if Util.debug()
		Ui.bigButton "Resolve", !->
			Server.send 'resolve', roundId

entering = !->
	# renderTimer(true)
	# Dom.div !->
	# 	Ui.bigButton tr("Ready, go!"), !-> # start the thing
	# 		Db.local.set 'start', (Date.now()*.001)
	# Dom.section !->
	# 	Dom.style padding: "0px 8px 8px"
	# 	Dom.h4 !->
	# 		Dom.text tr("Answers:")
	# 	renderAnswers(true)
	Dom.div !->
		Dom.style
			height: '100%'
			margin: '-8px'
			background: '#333'
			Box: 'vertical center middle'
			textAlign: 'center'
			color: 'aaa'
		Dom.div !->
			Dom.style
				position: 'relative'
				padding: '30px 20px'
				boxSizing: 'border-box'
				Box: 'center'
				width: '100%'
			renderTimer(enterDelay, "#{Page.width()*.8}px")
		Dom.text tr("Get ready to answer the question by dragging four intems to the correct order.")
		# Ui.bigButton tr("Ready, go!"), !-> # start the thing
			# Db.local.set 'start', (Date.now()*.001)

answering = !->
	renderTimer(20)
	Dom.section !->
		Dom.style
			padding: "0px 8px 8px"
			margin: '0px -8px'
		Dom.h4 !->
			Dom.text tr("Answers:")
		# renderAnswers()
		Dom.div !->
			log "--rendering items--"
			items = []
			order = Db.shared.get('rounds', roundId, 'answers', Plugin.userId())||[0,1,2,3]
			renderDraggableAnswer(i, Dom.get()) for i in order

	Dom.css
		".dragging":
			opacity: 0.6
			zIndex: 99
			_transition: 'initial !important'
			_backfaceVisibility: 'hidden'

	if Util.debug()
		Ui.bigButton tr("ReOrder"), !->
			for t,i in items
				t.order = i
			order = [items[0].order, items[1].order, items[2].order, items[3].order]
			log order
			Server.sync 'answer', roundId, order, !->
				Db.shared.set('rounds', roundId, 'answers', Plugin.userId(), order)

answered = !->
	Dom.section !->
		Dom.style padding: "8px"
		Dom.div !->
			Dom.style
				Box: 'left'
				margin: '0px'
				padding: '0px'
			Dom.h4 !->
				Dom.style Flex: true, margin: '0px'
				Dom.text tr("The correct answer was:")
			Dom.h4 !->
				Dom.style margin: '0px'
				Dom.text tr("Your:")
		renderAnswers(false, true, true)

	a = Db.shared.get('rounds', roundId, 'answers', Plugin.userId())||[]
	if !a.length
		Dom.div !-> # sorry
			Dom.style
				textAlign: 'center'
				padding: '20px'
			Dom.h4 !->
				Dom.text tr("Sorry, the time is up.")
	# Dom.section !-> # given answer
	# 	Dom.h4 tr("Your given answer was:")
	# 	Dom.div !->
	# 		Dom.style Box: 'center'
	# 		renderShortAnswer(i) for i in a


	# Ui.bigButton tr("Who knows?"), !->
	# 	Page.nav {0:roundId, 1:"whoknows"}

resolved = !->
	Dom.h4 !->
		Dom.style
			textAlign: 'center'
			fontSize: '90%'
		Dom.text tr("Correct answer was:")
	# renderAnswer(i, true) for i in [0..3]
	renderAnswers(false, true)

	Dom.section !->
		Dom.style margin: "8px -8px 0px"
		Plugin.users.observeEach (user) !->
			return unless Plugin.userName(user.key())? # skip empty (like 0)
			Ui.item !->
				Dom.div !->
				Ui.avatar Plugin.userAvatar(user.key()),
					style:
						position: 'inline-block'
					onTap: !-> Plugin.userInfo(user.key())
				Dom.div !->
					Dom.style
						Flex: true
						marginLeft: '10px'
					Dom.text Plugin.userName(user.key())
				Dom.div !->
					Dom.style
						marginRight: '-6px'
						fontSize: '130%'
					r = Db.shared.peek('rounds', roundId, 'results', user.key())||0
					s = Db.shared.peek('rounds', roundId, 'scores', user.key())||0

					Dom.text s
					Dom.div !->
						Dom.style
							display: 'inline-block'
							textAlign: 'center'
							width: '20px'
						Dom.text (if r>=0 then " + " else "  - ")
					Dom.text Math.abs(r)
		, (user) ->
			-((Db.shared.peek('rounds', roundId, 'scores', user.key())||0)+(Db.shared.peek('rounds', roundId, 'results', user.key())||0))

count = !-> # ♫ Final countdown! ♬
	c = Db.local.peek('start') + questionTime # ten seconds
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

renderTimer = (timeOut, size)!->
	Dom.div !-> # timer
		Obs.observe !->
			Dom.style
				position: 'relative'
				height: '30px'
				width: size||"#{Page.width()}px"
				backgroundColor: "hsl(#{130/timeOut*+(cooldownO.get()||timeOut)},100%, #{95 - Math.pow(timeOut-(cooldownO.get()||timeOut),0.7)}%)"
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
					width: size||"#{Page.width()}px"
					height: '30px'
					backgroundColor: "hsl(#{130/timeOut*+(cooldownO.get()||timeOut)},100%, #{87 - Math.pow(timeOut-(cooldownO.get()||timeOut),0.3)}%)"
					_transform: "scaleX(#{(cooldownO.get()||timeOut)/timeOut})"
					_transition: "transform 2s, background-color 1s linear"
					WebkitTransition_: "transform 1s linear, background-color 1s linear"
		Dom.div !->
			Dom.style
				_transform: 'translate3D(0,0,0)'
			Dom.text cooldownO.get()||timeOut

renderAnswers = (hideAnswers = false, solution = false, showOwn = false) !->
	renderAnswer(i, solution, hideAnswers, showOwn) for i in [0..3]

whoknows = !->
	# check if we arrived here validly
	if !Db.shared.get 'rounds', roundId, 'new'
		Ui.emptyText tr("Voting just closed, sorry!")
		return

	initialValue = Db.shared.peek('rounds', roundId, 'votes', Plugin.userId())||{}
	votesO = Obs.create initialValue
	initialValue = JSON.stringify initialValue
	Dom.section !-> # other users
		Dom.style
			textAlign: 'center'

		hiddenForm = Form.hidden 'submitTrigger'

		Form.setPageSubmit (values) !->
			log "sync", votesO.peek()
			Server.sync 'vote', roundId, votesO.peek(), !->
				Db.shared.set 'rounds', roundId, 'votes', Plugin.userId(), votesO.peek()
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

# Old render result:
# Dom.h4 !->
# 	Dom.style
# 		textAlign: 'center'
# 		fontSize: '90%'
# 	Dom.text tr("Correct answer was:")
# # renderAnswer(i, true) for i in [0..3]
# renderAnswers(false, true)

# Dom.section !->
# 	userVotes = Db.shared.get 'rounds', roundId, 'votes'

# 	getVotes = (uId) !->
# 		votes = 0
# 		for k,v of userVotes
# 			for k2,v2 of v
# 				if +k2 is +uId then ++votes
# 		return votes

# 	Dom.style
# 		margin: "8px -8px 0px"
# 		padding: "4px 0px"

# 	# legend
# 	Dom.div !->
# 		Dom.style
# 			Box: 'left'
# 			margin: '4px 8px'
# 			textAlign: 'center'
# 			fontWeight: 'lighter'
# 			color: '#888'
# 		Dom.div !->
# 			Dom.style width: '40px'
# 			Dom.text tr("user")
# 		Dom.div !->
# 			Dom.style width: '40px'
# 			Dom.text tr("score")
# 		Dom.div !->
# 			Dom.style Flex: true
# 			Dom.text tr("voted on")
# 		Dom.div !->
# 			Dom.style width: '35px'
# 			Dom.text tr("total")

# 	# User results
# 	Plugin.users.observeEach (user) !->
# 		Dom.div !->
# 			Dom.style
# 				Box: 'left middle'
# 				margin: '4px 8px'
# 			Ui.avatar Plugin.userAvatar(user.key()),
# 				style:
# 					margin: '0 0 1px 0'

# 			Dom.div !-> # score
# 				s = Db.shared.peek('rounds', roundId, 'scores', user.key())||0
# 				Dom.style
# 					width: '30px'
# 					height: '30px'
# 					lineHeight: '30px'
# 					fontSize: '18px'
# 					margin: "5px 0px 5px 5px"
# 					textAlign: 'center'
# 					borderRadius: '2px'
# 					backgroundColor: scoreColors[s]
# 				Dom.text s

# 			Dom.div !-> # show votes
# 				Dom.style
# 					margin: "5px 8px"
# 					Flex: true
# 					Box: 'left'
# 					overflow: 'hidden'
# 				votes = Db.shared.get('rounds', roundId, 'votes', user.key())||[]
# 				for k,v of votes
# 					Dom.div !->
# 						Dom.style
# 							position: 'relative'
# 						Ui.avatar Plugin.userAvatar(k),
# 							size: 28
# 							style:
# 								margin: '0px 2px'
# 						Dom.div !->
# 							Dom.style
# 								borderRadius: '50%'
# 								position: 'absolute'
# 								top: '0px'
# 								left: '2px'
# 								height: '30px'
# 								width: '30px'
# 								backgroundColor:  if v > 0 then "rgba(105, 240, 136, 0.3)" else "rgba(255, 102, 102, 0.3)"

# 			Dom.div !-> # totals
# 				r = Db.shared.peek('rounds', roundId, 'results', user.key())||0
# 				s = Db.shared.peek('rounds', roundId, 'scores', user.key())||0
# 				Dom.style
# 					width: '30px'
# 					height: '30px'
# 					lineHeight: '30px'
# 					fontSize: '18px'
# 					margin: "5px 0px 5px 5px"
# 					textAlign: 'center'
# 					borderRadius: '2px'
# 					backgroundColor: scoreColors[Math.min(6,(r+s))]
# 				Dom.text (r+s)
# 	, (user) -> -Db.shared.peek('rounds', roundId, 'scores', user.key())||0

# Older render result:

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