# Template for plugins.
# Happening 2015

Page = require 'page'
Questionview = require 'questionview'
Overview = require 'overview'

exports.render = !->
	if Page.state.get(0) is "question"
		return Questionview.render()
	else
		return Overview.render()