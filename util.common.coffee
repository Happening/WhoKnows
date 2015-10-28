Db = require 'db'
Plugin = require 'plugin'
{tr} = require 'i18n'
Rand = require 'rand'

exports.debug = ->
	true

# Determines duration of the round started at 'currentTime'
# This comes from the Ranking Game plugin
exports.getRoundDuration = (currentTime) ->
	return false if !currentTime
	duration = 6*3600 # six hours
	while 22 <= (hrs = (new Date((currentTime+duration)*1000)).getHours()) or hrs <= 9
		duration += 6*3600
	return duration

exports.getQuestion = (roundId) ->
	id = Db.shared.peek 'rounds', roundId, 'qid'
	return questions()[id]

# we show [1..3] applied on key
exports.getOptions = (roundId) ->
	q = questions()[Db.shared.peek 'rounds', roundId, 'qid']
	k = getKey(roundId)
	log "getOptions; k:", k, "q:", q
	# return [q[k[0]+1], q[k[1]+1], q[k[2]+1], q[k[3]+1]]
	return [q[k[0]+1], q[k[1]+1], q[k[2]+1], q[k[3]+1]]

# the solution is index of options in key
exports.getSolution = (roundId) ->
	k = getKey(roundId)
	o = Db.shared.peek 'rounds', roundId, 'options'
	r = []
	for i in [0..3]
		r[i] = k.indexOf(o[i]-1)
	log "getSolution", roundId, k, o, ": ", r
	return r

# the key is a random order of [1..3]
exports.getKey = getKey = (roundId) ->
	o = Db.shared.peek 'rounds', roundId, 'options'
	s = rndOrder(roundId)
	r = [o[s[0]]-1, o[s[1]]-1, o[s[2]]-1, o[s[3]]-1]
	log "getKey", roundId, o, s, r
	return r

exports.makeRndOptions = (qId) -> # provide this in the 'correct' order. The client will rearrange them at random.
	q = questions()[qId]
	available = [1..q.length-1]
	r = []
	for i in [1..4]
		r.push +available.splice(Math.floor(Math.random()*available.length), 1)

exports.getWinner = (roundId) ->
	#walk through scores
	answers = Db.shared.get 'rounds', roundId, 'scores'
	winner = -1
	winningScore = -1
	for k,v of answers
		if v>winningScore
			winningScore = v
			winner = k
	return winner

exports.rndOrder = rndOrder = (roundId) ->
	seed = +Plugin.groupId() + +roundId
	srng = new Rand.Rand(seed)
	a = [0,1,2,3]
	r = []
	for x in [1..4]
		r.push +(a.splice(srng.rand2(0,a.length),1))
	log "rndOrder:", Plugin.groupId(), roundId, seed, r
	return r


exports.questions = questions = -> [
	# WARNING: indices are used, so don't remove items from this array (and add new questions at the end)
	# [0]: question, [1-x]: the answers in the correct order
	["Order Films by release date", "Citizen Kane", "James Bond: Dr. No", "The Good, the Bad and the Ugly", "The Godfather", "Jaws", "Star Wars: A New Hope", "ET", "Jurassic Park", "Schindler\'s List"] # 1984, 1963, 1968, 1972, 1975, 1977, 1982, 1993, 1994
	["Order buildings by ascending height", "Burj Khalifa", "Petronas Twin Towers", "Empire State Building", "Eiffel Tower", "Great Pyramid of Giza", "Big Ben", "Statue of Liberty", "Sydney Opera House", "Leaning Tower of Pisa" ] #828, 452, 381, 300, 139, 96, 93, 65, 56
	["Order wonders by construction date", "Great Pyramid of Giza", "Great Wall of China", "Petra", "Colosseum", "Chichen Itza", "Machu Picchu", "Taj Mahal", "Christ the Redeemer"]
	["Order TV series on broadcast date", "Star Trek: The Original Series", "The Bold and the Beautiful", "The Simpsons", "Futurama", "The X-Files", "South Park", "The Big Bang Theory", "Scrubs", "A Game of Thrones"] # 1966, 1987, 1989, 1998, 2000, 2004, 2007, 2010, 2011
	["Order movies by IMDb rating", "The Shawshank Redemption", "The Godfather", "The Dark Knight", "Pulp Fiction", "The Lord of the Rings: The Fellowship of the Ring", "Citizen Kane", "Toy Story", "Life of Brian", "Kill Bill"]
	["Order Disney films on release date", "Snow White and the Seven Dwarfs", "Bambi", "Alice in Wonderland", "One Hundred and One Dalmatians", "The Aristocats", "The Little Mermaid", "Aladdin", "The Lion King", "The Princess and the Frog"]
	["Order Pixar films on release date", "Toy Story", "A Bug's Life", "Monsters, Inc.", "Finding Nemo", "The Incredibles", "WALL-E", "Up", "Brave"]
	["Order Presidents of the United States Chronologically", "George Washington", "Abraham Lincoln", "Franklin D. Roosevelt", "John F. Kennedy", "Richard Nixon", "Bill Clinton", "George W Bush (jr.)", "Barack Obama"]
	["Order countries by population", "China", "India", "United States", "Brazil", "Japan", "Germany", "Iran", "Canada", "Iceland"]
	["Order weight per liter", "Petrol", "Alcohol", "Olive oil", "Diesel", "Sunflower oil", "Water", "Beer", "Milk", "Sea water", "Citric acid"]
	["Order creation chronologically according to the Bible", "Earth", "Water", "Land", "Sun", "Birds", "Man"]
	["Order these balls by size", "Table tennis ball", "Golf ball", "Pool ball", "Tennis ball", "Baseball ball", "Soccer ball", "Basketball ball"]
	["Order by invention date", "Stone tools", "The wheel", "The alphabet", "Coins", "Windmill", "Woodblock printing", "Toilet Paper", "Gunpowder", "Soap", "Telescope", "Steam Engine", "Light Bulb"]

	# WARNING: always add new questions to the end of this array
]
# questions that are deemed to difficult:
# ["Order Star Wars movies by release date", "A New Hope", "The Empire Strikes Back", "Return of the Jedi", "The Phantom Menace", "Attack of the Clones", "Revenge of the Sith", "The Force Awakens"]
# ["Order by Electromagnetic Frequency", "Radio waves", "Microwave radiation", "Infrared radiation", "Green light", "Blue light", "Ultraviolet radiation", "X-ray radiation", "Gamma radiation"]

# distance earth
# distance space
# size space
# wk soccer wins


exports.inverseCheck = ->
	[5,0,-3,"butt",-4,"miter",-5,4,4,2,0.019589437957492035,0.019589437957492035,2,2,0,0.0018773653552219825,2,2,0,0,4,2,1.0666666513406717,1.0666666513406717,2,2,-398.48159,-658.25586,5,0,-2,1,-6,1,7,0,10,2,398.48159,658.25586,11,2,398.48159,705.93359,11,2,446.33901,705.93359,11,2,446.33901,658.25586,11,2,398.48159,658.25586,12,0,10,2,437.2101,668.33789,11,2,440.01088,671.13672,11,2,416.01088,695.13672,11,2,404.81166,683.9375,11,2,407.61049,681.13672,11,2,416.01088,689.53711,11,2,437.2101,668.33789,12,0,8,1,"nonzero",6,0,6,0]