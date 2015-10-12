Db = require 'db'
Dom = require 'dom'
Page = require 'page'
Plugin = require 'plugin'
Obs = require 'obs'
Ui = require 'ui'
{tr} = require 'i18n'
SF = require 'serverFunctions'

exports.render = ->
	Dom.section !->
		Dom.text "Hallo world"
		Ui.bigButton "Anser a question", !->
			Page.nav {0:"question"}
