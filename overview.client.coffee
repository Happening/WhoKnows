Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Form = require 'form'
Icon = require 'icon'
Obs = require 'obs'
Page = require 'page'
Plugin = require 'plugin'
Server = require 'server'
Ui = require 'ui'
Util = require 'util'
{tr} = require 'i18n'

renderQuestion = (qid) !->
	Dom.div !->
		question = Db.shared.ref('rounds', qid)
		answered = question.get('answers', Plugin.userId())||0
		unResolved = !!question.get('new')
		unread = Event.isNew(question.get('time'), question.key())
		questionText = Util.getQuestion(qid)[0]
		Dom.style
			Box: 'left'
			margin: '0px 0px'
			padding: '10px 4px'
			borderRadius: '2px'
		if unResolved # either answered (but not resolved) or unanswered
			Icon.render
				data: if answered is 0 then 'question' else 'chronometer' #question2
				size: 30
				color: '#5b0' if unread
				style:
					display: 'inline-block'
					margin: '5px 17px 5px 5px'
		else # avatar of winner
			Ui.avatar Plugin.userAvatar(Util.getWinner(qid)),
				style:
					display: 'inline-block'
					margin: '0px 12px 0px 0px'
		Dom.div !->
			Dom.style
				Flex: true
				Box: 'middle'
				color: '#5b0' if unread
			if unResolved
				if answered is 0 or Db.local.get('start')?
					Dom.text tr("New question")
				else
					Dom.text tr("Question answered. Waiting for results")
			else
				Dom.text questionText
		Dom.onTap !->
			Page.nav {0:qid}
	Form.sep()
	Dom.last().style
		margin: "2px 4px"

renderSpawn = !->
	Ui.item !->
		Dom.style
			Box: 'left'
			margin: '0px 0px'
			padding: '10px 4px'
			borderRadius: '2px'
		Icon.render
			data: 'add'
			size: 30
			style:
				display: 'inline-block'
				margin: '5px 17px 5px 5px'
		Dom.div !->
			Dom.style
				Flex: true
				Box: 'middle'
				Dom.text tr("Request new question")
		Dom.onTap !->
			log "request new question"
			Server.send 'newRound'

exports.render = ->
	maxId = Db.shared.get 'maxRounds'
	unfinishedQuestion = !!Db.shared.get('rounds', maxId, 'new')

	Dom.div !-> # top 3 contenders
		Dom.style
			textAlign: 'center'
		Dom.onTap !->
			Page.nav {0:'scores'}

		scores = Db.shared.get 'scores'
		scoresOder = ((k for k of scores).sort (a, b) -> scores[b] - scores[a])[...3] # sort and get top 3
		for user, i in scoresOder
			Dom.div !->
				Dom.style
					display: 'inline-block'
					Box: 'vertical'
					margin: '5px 10px'
					width: ((Page.width()-16)/3)-20 + "px"
				Ui.avatar Plugin.userAvatar(user),
					size: 60
					style:
						position: 'inline-block'
						margin: '0px 0px 5px'
						display: 'inline-block'
				Dom.div !->
					Dom.style
						fontWeight: 'bold'
						textOverflow: 'ellipsis'
						overflow: 'hidden'
						whiteSpace: 'nowrap'
						fontSize: '13px'
					Dom.text (i+1) + ". " + Plugin.userName(user)
				Dom.div !->
					Dom.style fontSize: '13px'
					Dom.text tr("score: %1", scores[user])
	Dom.section !-> # the questions overview
		Dom.style padding: '0px 4px'

		renderSpawn() unless unfinishedQuestion or !!Db.shared.get('ooq') # ooq = out of questions

		Db.shared.observeEach 'rounds', (question) !->
			renderQuestion question.key()
		, (question) ->
			-question.key()

	if Util.debug()
		Ui.bigButton "Spawn question", !->
			Server.send('newRound')
		Ui.bigButton "Resolve question", !->
			Server.send('resolve')

exports.renderScores = !->
	Page.setTitle tr("Scores")
	Dom.section !->
		Db.shared.observeEach 'scores', (item) !->
			return unless Plugin.userName(item.key())? # skip empty (like 0)
			Ui.item !->
				Dom.div !->
				Ui.avatar Plugin.userAvatar(item.key()),
					style:
						position: 'inline-block'
					onTap: !-> Plugin.userInfo(item.key())
				Dom.div !->
					Dom.style
						Flex: true
						marginLeft: '10px'
					Dom.text Plugin.userName(item.key())
				Dom.div !->
					Dom.style
						width: '30px'
						textAlign: 'center'
						marginRight: '-6px'
						fontSize: '150%'
					Dom.text (item.get())
		, (item) ->
			-item.get()
