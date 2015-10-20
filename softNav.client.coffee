Dom = require 'dom'
Obs = require 'obs'

pages = {}
containers = {}
state = null

exports.register = (name, func) !->
	pages[name] = func

exports.render = !->
	for k,v of pages
		Dom.div !->
			Dom.style display: 'none'
			v.call()
			containers[k] = Dom.get()

exports.nav = (id) !->
	log 'navigate', state, '->', id
	if state
		containers[state].style display: 'none'
	state = id
	containers[state].style display: 'block'
