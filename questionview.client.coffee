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

questionTime = (if Util.debug() then 20 else 20) # you have 20 seconds to answer the question
enterDelay = 5
questionID = 0
roundId = 0
order = []
questionOptions = []
solution = []
items = []
stateO = Obs.create('entering')
cooldownO = Obs.create(null)

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

startTimer = !->
	Db.local.set 'start', Math.floor(0|(Date.now()*.001))
	# already set the answer on the server to "user gave no answer"
	Server.sync 'answer', roundId, -1, !->
		Db.shared.merge 'rounds', roundId, 'answers', Plugin.userId(), -1

endTimer = !->
	Db.local.remove 'start'

exports.render = ->
	roundId = Page.state.get(0)

	Page.setTitle tr("Question")
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
				# already set an answer, if there is none
				if !Db.shared.peek('rounds', roundId, 'answers', Plugin.userId())?
					log "Sending default answer"
					Server.sync 'answer', roundId, [0,1,2,3], !->
						Db.shared.set('rounds', roundId, 'answers', Plugin.userId(), [0,1,2,3])
				Form.setPageSubmit (values) !->
					log "done"
					endTimer()
				, 1
				SoftNav.nav 'answering'
			when 'entering'
				cooldownO.set enterDelay
				Obs.onTime enterDelay*1000+100, !->
					Db.local.set 'start', (Date.now()*.001)
				tick = !->
					log "tick"
					timer = Obs.onTime 1000, !->
						cooldownO.incr -1
						if cooldownO.peek() > 0 then tick()
				tick()
				SoftNav.nav 'entering'
			# when 'voting'
			# 	SoftNav.nav 'voting'

	if Util.debug()
		Ui.bigButton "Resolve", !->
			Server.send 'resolve', roundId

entering = !->
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
		Dom.text tr("Get ready to answer the question by dragging four items to the correct order.")

answering = !->
	renderTimer(20)
	Dom.section !->
		Dom.style
			padding: "0px 8px 8px"
			margin: '0px -8px'
		Dom.h4 !->
			Dom.text tr("Answers:")
		orderTitles = Util.getOrderTitles(roundId)
		Dom.div !->
			Dom.style
				textAlign: 'center'
				fontSize: '80%'
				color: '#aaa'
				margin: '0px'
			Dom.text orderTitles[0]
		Dom.div !->
			log "--rendering items--"
			items = []
			order = Db.shared.get('rounds', roundId, 'answers', Plugin.userId())||[0,1,2,3]
			renderDraggableAnswer(i, Dom.get()) for i in order
		Dom.div !->
			Dom.style
				textAlign: 'center'
				fontSize: '80%'
				color: '#aaa'
				margin: '8px 0px 0px'
			Dom.text orderTitles[1]

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

resolved = !->
	Dom.h4 !->
		Dom.style
			textAlign: 'center'
			fontSize: '90%'
		Dom.text tr("Correct answer was:")
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
					r = Db.shared.get('rounds', roundId, 'results', user.key())||0
					s = Db.shared.get('rounds', roundId, 'scores', user.key())||0

					Dom.text s
					Dom.div !->
						Dom.style
							display: 'inline-block'
							textAlign: 'center'
							width: '20px'
						Dom.text (if r>=0 then " + " else "  - ")
					Dom.text Math.abs(r)
		, (user) ->
			-((Db.shared.get('rounds', roundId, 'scores', user.key())||0)+(Db.shared.get('rounds', roundId, 'results', user.key())||0))

count = !-> # ♫ Final countdown! ♬
	log "count"
	c = Db.local.peek('start') + questionTime # twenty seconds
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
		Dom.h4 Util.getQuestion(roundId)

renderTimer = (timeOut, size)!->
	Dom.div !-> # timer
		Obs.observe !->
			Dom.style
				position: 'relative'
				height: '30px'
				width: size||"#{Page.width()}px"
				backgroundColor: "hsl(#{130/timeOut*+(cooldownO.get()||0)},100%, #{95 - Math.pow(timeOut-(cooldownO.get()||0),0.7)}%)"
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
					backgroundColor: "hsl(#{130/timeOut*+(cooldownO.get()||0)},100%, #{87 - Math.pow(timeOut-(cooldownO.get()||0),0.3)}%)"
					_transform: "scaleX(#{(cooldownO.get()||0)/timeOut})"
					_transition: "transform 2s, background-color 1s linear"
					WebkitTransition_: "transform 1s linear, background-color 1s linear"
		Dom.div !->
			Dom.style
				_transform: 'translate3D(0,0,0)'
			Dom.text cooldownO.get()||0

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
			Dom.h4 tr("Select any number of people. You earn a point for each who gave a correct answer. But you lose a point for each who answered wrong.")

		size = (Page.width()-40) / Math.floor((Page.width()-0)/100)-1
		Plugin.users.observeEach (user) !->
			return if +user.key() is Plugin.userId() # skip yourself
			Dom.div !->
				v = votesO.get()
				selected = v[user.key()]
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
					Dom.style
						width: "#{size-16}px"
						textOverflow: 'ellipsis'
						whiteSpace: 'nowrap'
						fontSize: '90%'
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
		, (user) -> -Db.shared.peek('scores', user.key())|| 0