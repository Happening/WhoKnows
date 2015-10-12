# Template for plugins.
# Happening 2015

Page = require 'page'
Questionview = require 'questionview'
Overview = require 'overview'

exports.render = !->
	if s = Page.state.get(0)
		if s is "scores"
			return Overview.renderScores()
		return Questionview.render()
	else
		return Overview.render()