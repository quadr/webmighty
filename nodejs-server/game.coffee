
# CONSTANTS
PROFILE_WIDTH = 250
PROFILE_CARD_GAP = 15
CARD_WIDTH = 71
CARD_HEIGHT = 96
CARD_OVERLAP = 20
DEFAULT_SPEED_BASE = 50
SPEED_BASE = 50
PI = Math.PI
PLAYED_CARD_RADIUS = 60
COLLECTED_CARD_GAP = 20
PLAYER_LOCATION =
	5: [
		{ side: "bottom", location: 0.5, angle: PI * (3 / 2)}
		{ side: "left", location: 0.6, angle: PI * (3 / 2 - 2 / 5) }
		{ side: "top", location: 0.25, angle: PI * (3 / 2 - 4 / 5) }
		{ side: "top", location: 0.75, angle: PI * (3 / 2 - 6 / 5) }
		{ side: "right", location: 0.6, angle: PI * (3 / 2 - 8 / 5) }
	]
	6: [
		{ side: "bottom", location: 0.7, angle: PI * (1+1 / 3)}
		{ side: "bottom", location: 0.3, angle: PI * (1+2 / 3)}
		{ side: "left", location: 0.5, angle: PI * (2) }
		{ side: "top", location: 0.25, angle: PI * (2 + 1 / 3) }
		{ side: "top", location: 0.75, angle: PI * (2 + 1 / 3) }
		{ side: "right", location: 0.5, angle: PI * (1) }
	]
DISAPPEAR_DIRECTION =
	left: [-CARD_HEIGHT, 0]
	right: [CARD_HEIGHT, 0]
	top: [0, -CARD_HEIGHT]
	bottom: [0, CARD_HEIGHT]

SCORE_CARD_VALUES = "tjqk1"
VALUE_ORDER = "23456789tjqk1"
SUIT_NAMES =
	s: "스페이드"
	h: "하트"
	c: "클로버"
	d: "다이아몬드"
	n: "노기루다"
	" ": "&nbsp;"
VALUE_NAMES = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "잭", "퀸", "킹", "에이스"]

# UTILITIES
floor = Math.floor
lexicographic_compare = (a, b) ->
	if a == b
		0
	else if a < b
		-1
	else
		1
assert = (conditional, message = "") ->
	if not conditional
		console.log(message)
		alert(message)

Array::remove = (elem) ->
	@splice(@indexOf(elem), 1)[0]

runInterval = (interval, funcs) ->
	runner = ->
		funcs[0]()
		funcs.splice(0, 1)
		if funcs.length > 0
			setTimeout(runner, interval)
	setTimeout(runner, interval)

# 게임 관련 유틸리티

renderFaceName = (face) ->
	suit = SUIT_NAMES[face[0]]
	value = VALUE_NAMES[VALUE_ORDER.indexOf(face[1])]
	return "#{suit} #{value}"

isScoreCard = (face) ->
	face[1] in SCORE_CARD_VALUES

# MODELS
class Card
	constructor: (@playing_field, @face, @direction, x, y) ->
		# 카드 엘레멘트 생성
		@elem = $(".card_template")
			.clone()
			.removeClass("card_template")
			.addClass(@face)
			.addClass(@direction)
			.appendTo(@playing_field.elem)

		size = @getSize()
		@elem.css("left", (x - floor(size.width / 2)) + "px")
			.css("top", (y - floor(size.height / 2)) + "px")

		@playing_field.addCard(this)

	getSize: ->
		if @direction == "vertical"
			{width: CARD_WIDTH, height: CARD_HEIGHT}
		else
			{width: CARD_HEIGHT, height: CARD_WIDTH}

	moveTo: (cx, cy, duration) ->
		sz = @getSize()
		left = cx - floor(sz.width / 2)
		top = cy - floor(sz.height / 2)
		@elem.animate({left: left, top: top}, duration)

	setFace: (face) ->
		@elem.removeClass(@face).addClass(face)
		@face = face

	setDirection: (direction) ->
		@elem.removeClass(@direction).addClass(direction)
		@direction = direction

	remove: ->
		@elem.remove()
		null

class ChangePromiseHelper
	constructor: (suit, value, @minTarget, @elem, afterInit = -> )->
		@selectedSuit = suit
		@selectedValue = value
		@minValue = value

		# 현재 선택된 무늬 밑 숫자 표시
		@updateSelected()

		# + - 기능
		@elem.find(".plus_promise_button").unbind("click").click(=> @setValue(Math.min(20, @selectedValue+1)))
		@elem.find(".minus_promise_button").unbind("click").click(=> @setValue(Math.max(@minValue, @selectedValue-1)))

		# 처음엔 disable
		@elem.find(".value_select_buttons button").attr("disabled", "")

		self = this
		# 기루 무늬 고르기 버튼
		@elem.find(".select_suit button")
			.unbind("mouseover")
			.unbind("mouseout")
			.unbind("click")
			.mouseover(->
				self.showSuit self.getSuit this
				self.showValue self.minTarget[self.getSuit this])
			.mouseout(=>
				@showSuit(@selectedSuit)
				@showValue(@selectedValue))
			.click(->
						self.elem.find(".select_suit button.selected").removeClass("selected")
						$(this).addClass("selected")
						self.setSuit self.getSuit this

						# 숫자는 해당 무늬의 최소 숫자로
						self.setValue(self.minValue)
			)

		# 값 설정
		@setSuit(@selectedSuit)
		@setValue(@selectedValue)
		console.log this
		afterInit()


	updateSelected: ->
		@elem.find(".select_suit button").removeClass("selected")
		@elem.find(".select_suit button." + @selectedSuit).addClass("selected")

	showSuit: (suit) ->
		@elem.find(".selected .select_suit").html(SUIT_NAMES[suit])

	setSuit: (suit) ->
		@selectedSuit = suit
		@minValue = @minTarget[@selectedSuit]
		@showSuit(suit)

	showValue: (val) ->
		@elem.find(".selected .select_promise").html(if val == 0 then "" else val)

	setValue: (val) ->
		@selectedValue = val
		@showValue(val)
		if @minTarget[@selectedSuit] < @selectedValue
			@elem.find(".minus_promise_button").removeAttr("disabled")
		else
			@elem.find(".minus_promise_button").attr("disabled", "")
		if @selectedValue < 20
			@elem.find(".plus_promise_button").removeAttr("disabled")
		else
			@elem.find(".plus_promise_button").attr("disabled", "")

	getSuit: (button) ->
		$(button).attr("data-suit")

class PlayingField
	constructor: (@elem) ->
		@cards = []
		@players = []
		@playedCards = []
		@collected = []
		@cardStack = []

	getLocationInfo: (player) ->
		 PLAYER_LOCATION[@players.length][player]

	getCardDirection: (player) ->
		side = @getLocationInfo(player).side
		if side in ["top", "bottom"] then "vertical" else "horizontal"

	# 플레이어 x가 y장째 수집한 카드의 위치는?
	getCollectedPosition: (player, index) ->
		return @getHandPosition(player, @collected[player].length, index, COLLECTED_CARD_GAP)
		#return @getHandPosition(player, 14, index + 15)

	# 플레이어 x가 y장 카드를 가지고 있을 때, z번 카드의 가운데 위치는?
	getHandPosition: (player, cards, index, adjust = 0) ->
		{side: side, location: location} = @getLocationInfo(player)
		PLAYER_LOCATION[@players.length][player]
		# 깔끔하게 구현하고 싶지만.. -_-
		adjustx = adjusty = 0
		dx = dy = 0
		if side in ["top", "bottom"]
			cx = @convertRelativePosition(location, 0).x
			if side == "top"
				cy = CARD_HEIGHT / 2
				dx = -1
				adjusty = adjust
			else
				cy = @getSize().height - CARD_HEIGHT / 2
				dx = 1
				adjusty = -adjust
		else
			cy = @convertRelativePosition(0, location).y
			if side == "left"
				cx = CARD_HEIGHT / 2
				dy = 1
				adjustx = adjust
			else
				cx = @getSize().width - CARD_HEIGHT / 2
				dy = -1
				adjustx = -adjust
		totalWidth = CARD_WIDTH + (cards - 1) * CARD_OVERLAP
		fx = cx + dx * (floor(totalWidth / 2) - CARD_WIDTH / 2) + adjustx
		fy = cy + dy * (floor(totalWidth / 2) - CARD_WIDTH / 2) + adjusty
		{x: floor(fx - dx * CARD_OVERLAP * index), y: floor(fy - dy * CARD_OVERLAP * index)}

	getProfilePosition: (player) ->
		{side: side, location: location} = @getLocationInfo(player)
		# 깔끔하게 구현하고 싶지만.. -_-
		width = if side in ["top", "bottom"] then 254 else 200
		height = if side in ["top", "bottom"] then 50 else 104
		computedGap = CARD_HEIGHT + PROFILE_CARD_GAP + COLLECTED_CARD_GAP
		if side in ["top", "bottom"]
			return {
				side: side,
				x: @convertRelativePosition(location, 0).x - width / 2,
				y: if side == "top" then computedGap else @getSize().height - height - computedGap
			}
		else
			return {
				side: side,
				y: @convertRelativePosition(0, location).y - height / 2,
				x: if side == "left" then computedGap else @getSize().width - width - computedGap
			}

	clearDialogs: ->
		$("#dialog > div").hide()

	clearCards: ->
		@cards.pop().remove() while @cards.length > 0
		null

	getSize: ->
		{width: @elem.width(), height: @elem.height()}

	addCard: (card) ->
		@cards.push(card)

	convertRelativePosition: (x, y) ->
		sz = @getSize()
		{x: floor(sz.width * x), y: floor(sz.height * y)}

	setSortOrder: (faceOrder) =>
		@sortOrder = faceOrder

	sortHands: (player) ->
		faceOrder = @sortOrder
		faceOrder ?= "jsdch"
		if @hands[player].length == 0 or @hands[player][0].face[0] == "b"
			return
		@hands[player].sort((a, b) ->
			if a.face[0] != b.face[0]
				- (faceOrder.indexOf(a.face[0]) - faceOrder.indexOf(b.face[0]))
			else
				VALUE_ORDER.indexOf(a.face[1]) - VALUE_ORDER.indexOf(b.face[1])
		)
		n = @hands[player].length
		for i in [0...n]
			@hands[player][i].elem.css({"z-index": n-i+20})
		@repositionCards(player)

	createCardsFromFace: (faces, player = null) ->
		center = @convertRelativePosition(0.5, 0.5)
		cards = []
		for face in faces
			card = new Card(this, face, "vertical", center.x, center.y)
			if player?
					card.setDirection @getCardDirection player
			card.elem.show()
			cards.push(card)

		return cards
			

	# 각 플레이어의 카드가 주어질 때 셔플 애니메이션을 보여주고, hand[] 에 각 카드를 등록한다
	deal: (cards, startFrom, done=->) ->
		@clearCards()
		assert(cards.length == @players.length, "플레이어 수와 나눠줄 카드 덱 수가 동일해야함")
		@hands = ([] for i in [0...@players.length])
		@collected = ([] for i in [0...@players.length])
		center = @convertRelativePosition(0.5, 0.5)
		@cardStack = []
		for i in [0..52]
			card = new Card(this, "back", "vertical", center.x, center.y - floor(i / 4) * 2)
			card.elem.addClass("group" + (floor(i / 4) %2)).delay(i * SPEED_BASE / 10).fadeIn(0)
			@cardStack.push(card)
		# 마지막 카드가 보여지고 나면 셔플 동작을 한다
		@cardStack[52].elem.promise().done(=>
			for i in [0..0]
				$(".group0")
					.animate({left: "-=37"}, SPEED_BASE*3)
					.animate({top: "-=2"}, 0)
					.animate({left: "+=74"}, SPEED_BASE*6)
					.animate({top: "+=2"}, 0)
					.animate({left: "-=37"}, SPEED_BASE*3)
				$(".group1")
					.animate({left: "+=37"}, SPEED_BASE*3)
					.animate({top: "+=2"}, 0)
					.animate({left: "-=74"}, SPEED_BASE*6)
					.animate({top: "-=2"}, 0)
					.animate({left: "+=37"}, SPEED_BASE*3)
			# 셔플을 다 하고 나면 카드를 돌린다
			$(".group1").promise().done(=>
				dealt = 0
				for index in [0...cards[0].length]
					for pl in [0...@players.length]
						player = (startFrom + pl) % @players.length
						card = @cardStack.pop()
						@hands[player].push(card)
						face = cards[player][index]
						do (card, face, player, index, dealt) =>
							setTimeout(
								=>
									card.setFace face
									card.setDirection @getCardDirection player
									pos = @getHandPosition(player, cards[0].length, index)
									card.moveTo(pos.x, pos.y, SPEED_BASE)
									null
								, dealt * SPEED_BASE)
						dealt++

				setTimeout(
					=>
						for i in [0...@cardStack.length]
							@cardStack[i].elem.animate({top: "-=#{i * 2}", left: "-=#{ i * 2 }"}, 50)
						for player in [0...@players.length]
							@sortHands(player)
						null
					, dealt * SPEED_BASE
				)
				setTimeout(done, dealt * SPEED_BASE)
				null
			)
			null
		)
		null

	repositionCards: (player) ->
		for i in [0...@hands[player].length]
			pos = @getHandPosition(player, @hands[player].length, i)
			@hands[player][i].moveTo(pos.x, pos.y, SPEED_BASE * 5)

	# cardStack 에 남은 카드들을 player 에게 준다.
	dealAdditionalCards: (faces, player, done=->) ->
		n = faces.length
		# 6마 고려하면 무의미한 assert
		#assert(n == @cardStack.length, "남은 카드 장 수와 추가로 지급하기로 한 카드 수가 다릅니다.")
		for idx in [0...n]
			if not @cardStack? or @cardStack.length == 0
				@cardStack = []
				card = new Card(this, "back", "vertical", center.x, center.y)
				card.elem.fadeIn(0)
				@cardStack.push(card)
			card = @cardStack.pop()
			do (idx, card) =>
				setTimeout(
					=>
						card.setFace(faces[idx])
						card.setDirection @getCardDirection player
						@hands[player].push(card)
						@repositionCards(player)
						null
					, idx * SPEED_BASE*5
				)
		setTimeout(
			=>
				@sortHands(player)
				done()
			, n * SPEED_BASE*5)
		null

	globalMessage: (message, fadeOutAfter=5000) ->
		$("#global_message").hide().clearQueue().html(message).fadeIn(500).delay(fadeOutAfter).fadeOut(500)


	clearPlayerMessages: ->
		for i in [0...5]
			@playerMessage i, "", ""

	playerMessage: (player, type, message = "") ->
		elem = @players[player].profile_elem
		elem.find("dd")
			.clearQueue()
			.stop()
			.animate({"background-color": "rgba(255, 255, 255, 0.8)"}, 150)
			.animate({"background-color": "rgba(0, 0, 0, 0.1)"}, 4000)
		elem.find(".message_type").html(type)
		elem.find(".message_content").html(message)

	setPlayers: (players) ->
		if @players
			player.profile_elem.remove() for player in @players
		@players = players
		for i in [0...@players.length]
			{side: side, y: y, x: x} = @getProfilePosition(i)
			elem = $(".profile_template")
				.clone()
				.removeClass("profile_template")
				.addClass(side)
				.appendTo(@elem)
			elem.find(".picture").attr({src: @players[i].picture})
			elem.find(".name").html(@players[i].name)
			elem.css({left: x, top: y})
			elem.show()
			@players[i].profile_elem = elem

	setPlayerType: (player, typeName) ->
		@players[player].profile_elem.find(".type").html(typeName).addClass(typeName)
		elem = @players[player].profile_elem
		if typeName.indexOf("주공") != -1 or typeName.indexOf("프렌드") != -1
			elem.addClass('ruler')
		else
			elem.removeClass('ruler')

	playCard: (player, card, render_as=null) ->
		if typeof(card) == "string"
			face = card
			card = null
			for c in @hands[player]
				if c.face == face
					card = c
					break
		if card == null
			card = @hands[player].pop()
			card.setFace(face)
		else
			@hands[player].remove(card)
		@playedCards.push(card)
		@playerMessage(player, "플레이", render_as or renderFaceName(card.face))
		@repositionCards(player)

		card.elem.css("z-index", @playedCards.length)
		card.setDirection("vertical")
		@moveToPlayedPosition(player, card)

	moveToPlayedPosition: (player, card)->
		angle = @getLocationInfo(player).angle
		center = @convertRelativePosition(0.5, 0.5)
		x = center.x + Math.cos(angle) * PLAYED_CARD_RADIUS
		y = center.y - Math.sin(angle) * PLAYED_CARD_RADIUS
		card.moveTo(x, y, SPEED_BASE * 5)

	displayPlayerInAction: (index) ->
		for player in @players
			player.profile_elem.removeClass('in_action')
		@players[index].profile_elem.addClass('in_action')

	endTurn: (winner, collectCards=false) ->
		take = []
		collect = []
		for card in @playedCards
			if isScoreCard(card.face) and collectCards
				collect.push(card)
			else
				take.push(card)
		@playerMessage(winner, "턴 승리", "이 턴을 승리!")
		@takeCards(winner, take)
		@collectCards(winner, collect)
		@playedCards = []

	# 프렌드 먹은 카드 없애기 위한 구현
	removeCollectedCards: (player) ->
		card.remove() for card in @collected[player]
		@collected[player] = []

	collectCards: (player, cards) ->
		for card in cards
			@collected[player].push(card)
		index = 0
		for card in @collected[player]
			card.setDirection @getCardDirection player
			pos = @getCollectedPosition(player, index)
			card.moveTo(pos.x, pos.y, SPEED_BASE * 5)
			card.elem.css({"z-index":@collected[player].length-index})
			index += 1

	takeCards: (player, cards, done = ->) ->
		home = @getHandPosition(player, 1, 0)
		[dx, dy] = DISAPPEAR_DIRECTION[@getLocationInfo(player).side]
		cx = home.x + dx
		cy = home.y + dy

		for i in [0...cards.length]
			e = cards[i].elem
			cards[i].elem
				.animate({top: cy, left: cx}, SPEED_BASE * 5)
				.fadeOut(0, -> e.remove())
		setTimeout(
			=>
				#card.remove() for card in cards
				done()
			, SPEED_BASE * 5)

	setPlayerListHandler: (handler) ->
		$("#player_list_dialog .ready").unbind("click").click(handler)

	showPlayerList: ->
		$("#player_list_dialog").show()

	hidePlayerList: ->
		$("#player_list_dialog").hide()

	addPlayerToList: (index, name, image) ->
		elem = $("#player_list_dialog").find("li").eq(index)
		if image == ""
			image = "static/guest.png"
		if elem?
			elem.find(".picture").attr({src: image})
			elem.find(".name").html(name)
			elem.find(".type").text("")
			elem.find(".message_content").text("전적 없음")

	clearPlayerList: ->
		@removePlayerFromList i for i in [0...5]

	removePlayerFromList: (index) ->
		elem = $("#player_list_dialog").find("li").eq(index)
		if elem?
			elem.find(".picture").attr({src: "static/question.png"})
			elem.find(".name").html("")
			elem.find(".type").text("빈 자리")
			elem.find(".message_content").text("")

	chooseSuit: (giru, done=->) ->
		finish = (suit) =>
			$("#choose_suit_dialog").hide()
			done(suit)
		$("#choose_suit_dialog .g")
			.unbind("click")
			.click(-> finish(giru))
		$("#choose_suit_dialog .c")
			.unbind("click")
			.click(-> finish('c'))
		$("#choose_suit_dialog .d")
			.unbind("click")
			.click(-> finish('d'))
		$("#choose_suit_dialog .s")
			.unbind("click")
			.click(-> finish('s'))
		$("#choose_suit_dialog .h")
			.unbind("click")
			.click(-> finish('h'))
		$("#choose_suit_dialog .cancel")
			.unbind("click")
			.click(-> finish())
		$("#choose_suit_dialog").fadeIn(100)

	chooseCard: (done=->) ->
		player = 0
		baseY = @getHandPosition(player, 1, 0).y - CARD_HEIGHT / 2
		finish = (card) =>
			for c in @hands[player]
				c.elem
					.removeClass("canChoose")
					.unbind()
			done(card)
		for card in @hands[player]
			do (card) =>
				card.elem
					.addClass("canChoose")
					.mouseover(-> $(this).animate({top: baseY-10 + "px"}, SPEED_BASE))
					.mouseout(-> $(this).animate({top: baseY + "px"}, SPEED_BASE))
					.mousedown(-> finish(card))

	chooseFilteredCard: (filter, done=->) ->
		player = 0
		baseY = @getHandPosition(player, 1, 0).y - CARD_HEIGHT / 2
		finish = (card) =>
			for c in @hands[player]
				c.elem
					.removeClass("canChoose")
					.unbind()
			done(card)
		for card in @hands[player]
			do (card) =>
				if filter(card)
					card.elem
						.addClass("canChoose")
						.mouseover(-> $(this).animate({top: baseY-10 + "px"}, SPEED_BASE))
						.mouseout(-> $(this).animate({top: baseY + "px"}, SPEED_BASE))
						.mousedown(-> finish(card))

	chooseMultipleCards: (choose, suit, target, minTarget, done=->) ->
		player = 0
		baseY = @getHandPosition(player, 1, 0).y - CARD_HEIGHT / 2
		@chosen = []
		multiple = $("#choose_multiple")
		$("#choose_multiple .open_change_promise").unbind().click(->
			multiple.addClass("enable_change_promise")
		)
		multiple.find(".choose_count").html(choose)
		multiple.fadeIn(500)

		# 테스트를 위한 기본값
		if not minTarget?
			if suit == 'n'
				minTarget = {
					n: target
					s: Math.min(target+1, 20)
					d: Math.min(target+1, 20)
					c: Math.min(target+1, 20)
					h: Math.min(target+1, 20)
				}
			else
				minTarget = {
					n: Math.min(target+1, 20)
					s: Math.min(target+2, 20)
					d: Math.min(target+2, 20)
					c: Math.min(target+2, 20)
					h: Math.min(target+2, 20)
				}
				minTarget[suit] = target

		helper = new ChangePromiseHelper(suit, target, minTarget, $("#choose_multiple"))

		finished = () =>
			if @chosen.length != choose
				return
			multiple.fadeOut(500)
			multiple.removeClass("enable_change_promise")
			for card in @hands[player]
				card.elem
					.removeClass("canChoose")
					.unbind()
			done(@chosen, helper.selectedSuit, helper.selectedValue)

		originalSuit = suit
		originalValue = target
		multiple.find(".reset_promise").unbind().click(->
			helper.setSuit(originalSuit)
			helper.setValue(originalValue)
			helper.updateSelected())

		# 카드 선택 부분 구현

		getHandlers = (card) =>
			raised = false

			raise = ->
				if not raised
					raised = true
					card.elem.animate({top: baseY-10 + "px"}, SPEED_BASE)
			deraise = ->
				if raised
					raised = false
					card.elem.animate({top: baseY + "px"}, SPEED_BASE)

			{
				onMouseOver: =>
					if @chosen.length < choose and card not in @chosen
						raise()
				onMouseDown: =>
					if @chosen.length < choose and card not in @chosen
						@chosen.push(card)
						card.elem.addClass("chosen")
						raise()
					else if card in @chosen
						@chosen.remove(card)
						card.elem.removeClass("chosen")
						deraise()
					if @chosen.length == choose
						multiple.find("button.confirm")
							.removeAttr("disabled")
							.unbind()
							.click(finished)
					else
						multiple.find("button.confirm").attr("disabled", "")

				onMouseOut: =>
					if card not in @chosen
						deraise()
			}

		for card in @hands[player]
			console.log card
			handlers = getHandlers(card)
			card.elem
				.addClass("canChoose")
				.mouseover(handlers.onMouseOver)
				.mousedown(handlers.onMouseDown)
				.mouseout(handlers.onMouseOut)
		null

	confirmYesNo: (question, yesName, noName, callback=(res) ->) ->
		$("#confirm_dialog .title").html(question)
		$("#confirm_dialog .confirm").text(yesName)
		$("#confirm_dialog .cancel").text(noName)

		handler = (yesno) ->
			$("#confirm_dialog").hide()
			callback(yesno)
		$("#confirm_dialog .confirm").unbind().click(-> handler(true))
		$("#confirm_dialog .cancel").unbind().click(-> handler(false))
		$("#confirm_dialog").fadeIn(100)

	showDealMissHand: (hand, name="김딜미") ->
		$("#dealmiss_dialog .you").text(name)
		faceOrder = "jsdch"
		hand.sort((a, b) ->
			if a[0] != b[0]
				- (faceOrder.indexOf(a[0]) - faceOrder.indexOf(b[0]))
			else
				VALUE_ORDER.indexOf(a[1]) - VALUE_ORDER.indexOf(b[1])
		)

		class DealmissField
			constructor: (@elem)->
				@cards = []
			addCard: (card)->
				@cards.push(card)
				card.elem
					.css("z-index", @cards.length+100)
					.delay(50*@cards.length+100)
					.fadeIn(100)
			clear: ->
				card.remove() for card in @cards
				@cards = []

		dealmissField = new DealmissField($("#dealmiss_dialog .cards"))

		$("#dealmiss_dialog .close").unbind().click(->
			$("#dealmiss_dialog").hide().clearQueue()
			dealmissField.clear()
		)
		$("#dealmiss_dialog")
			.fadeIn(100)
			.delay(5000).fadeOut(100, ->
				dealmissField.clear()
			)

		p = {
			left: 0
			top: 0
		}
		for c in hand
			card = new Card(dealmissField, c, "vertical", p.left + CARD_WIDTH/2, p.top + CARD_HEIGHT/2)
			p.left += CARD_OVERLAP

	prompt: (question, defaultValue = null, callback=(res) ->) ->
		defaultValue ?= ""
		$("#prompt_dialog .title").text(question)
		$("#prompt_dialog .value").val(defaultValue)
		handler = ->
			ret = $("#prompt_dialog .value").val()
			if ret == ""
				return
			$("#prompt_dialog").hide()
			callback(ret)

		$("#prompt_dialog .value")
			.unbind("keypress")
			.keypress((e) ->
				if e.keyCode == 13
					handler()
			)
		$("#prompt_dialog .confirm")
			.unbind("click")
			.click(handler)
		$("#prompt_dialog").fadeIn(100)
		$("#prompt_dialog .value").focus()
		
	scrollChatToEnd: ->
		$("#chatbox .content")
			.scrollTop($("#chatbox .content").prop("scrollHeight"))

	addChatHTML: (name, msg)->
		if name == ""
			$("#chatbox .content")
				.append(msg + "<BR>")
		else
			$("#chatbox .content")
				.append(name+": " + msg + "<BR>")
		@scrollChatToEnd()

	addChatMessage: (name, msg)->
		msg = $("#chatbox .escaper").text(msg).html()
		$("#chatbox .content")
			.append(name+": " + msg + "<BR>")
		@scrollChatToEnd()

	setChatHandler: (handler)->
		$("#chatbox .value")
			.unbind("keypress")
			.keypress((e) ->
				if e.keyCode == 13
					ret = $("#chatbox .value").val()
					$("#chatbox .value").val("")
					if ret == ""
						return
					handler(ret)
		)

	setAnimationOn: ->
		SPEED_BASE = DEFAULT_SPEED_BASE

	setAnimationOff: ->
		SPEED_BASE = 0

	setStatusBar: (htmlTxt)->
		buildMinimizedCardHtml = (face, content) ->
			content ?= ""
			'<span class="smallcard inline ' + face + '">'+content+'</span>'
		if (typeof(htmlTxt) == "function")
			[l, r] = htmlTxt(buildMinimizedCardHtml)
			l ?= ""
			r ?= ""
			$("#statusbar .left").html(l)
			$("#statusbar .right").html(r)
		else
			$("#statusbar .left").html(htmlTxt)
			$("#statusbar .right").html("")

	choosePromise: (minNoGiru, minOthers, canDealMiss, defaultSuit=" ", defaultValue=0, callback=(res) ->) ->
		minTarget =
			n: minNoGiru
			s: minOthers
			d: minOthers
			c: minOthers
			h: minOthers
		
		helper = new ChangePromiseHelper(defaultSuit, defaultValue, minTarget, $("#choose_promise_dialog"), ->
			$("#choose_promise_dialog .confirm").removeAttr("disabled"))

		finish = (res) ->
			$("#choose_promise_dialog").hide()
			callback(res)

		# 핸들러
		$("#promise_confirm_button")
			.unbind("click")
			.click(-> finish({"result": "confirm", "suit": helper.selectedSuit, "value": helper.selectedValue}))
		$("#promise_pass_button")
			.unbind("click")
			.click(-> finish({"result": "pass"}))
		$("#promise_dealmiss_button")
			.unbind("click")
			.click(-> finish({"result": "dealmiss"}))


		$("#choose_promise_dialog .confirm").attr("disabled", "")

		if canDealMiss
			$("#promise_dealmiss_button").show()
		else
			$("#promise_dealmiss_button").hide()

		# 준비 끝!
		$("#choose_promise_dialog").fadeIn(100)


field = null

TEST_CARDS = [["s1", "h2", "ht", "h1", "h4", "sk", "s2", "s3", "s4", "c3"],
		 ["back", "back", "back", "back", "back", "back", "back", "back", "back", "back"],
 		 ["back", "back", "back", "back", "back", "back", "back", "back", "back", "back"],
 		 ["back", "back", "back", "back", "back", "back", "back", "back", "back", "back"],
		 ["back", "back", "back", "back", "back", "back", "back", "back", "back", "back"]]
TEST_CARDS6 = [["s1", "h2", "ht", "h1", "h4", "sk", "s2", "s3", ],
		 ["back", "back", "back", "back", "back", "back", "back", "back"],
 		 ["back", "back", "back", "back", "back", "back", "back", "back"],
 		 ["back", "back", "back", "back", "back", "back", "back", "back"],
 		 ["back", "back", "back", "back", "back", "back", "back", "back"],
		 ["back", "back", "back", "back", "back", "back", "back", "back"]]

$(document).ready(->
	window.field = new PlayingField $ "#playing_field"

	$("#option_buttons .toggle_sound").click(->
		v = $("#option_buttons .toggle_sound").text()
		if v == "mute"
			$("#option_buttons .toggle_sound").text("unmute")
			$("#option_buttons").find("audio").prop({muted: true})
		else
			$("#option_buttons .toggle_sound").text("mute")
			$("#option_buttons").find("audio").prop({muted: false})
	)

	$("#option_buttons .toggle_animation").click(->
		v = $("#option_buttons .toggle_animation").text()
		if v == "animation off"
			window.field.setAnimationOff()
			$("#option_buttons .toggle_animation").text("animation on")
		else
			window.field.setAnimationOn()
			$("#option_buttons .toggle_animation").text("animation off")
	)


	$("#chatbox .toggle_size").unbind().click(->
		if $("#chatbox").width() == 400
			$("#chatbox").width(200)
			$("#chatbox .toggle_size").text('>')
			window.field.scrollChatToEnd()
		else
			$("#chatbox").width(400)
			$("#chatbox .toggle_size").text('<')
			window.field.scrollChatToEnd()
	)

	$("#chatbox .toggle_member_list").unbind().click(->
		$("#chatbox .member_list").toggle()
		if $("#chatbox .content").hasClass("reduced")
			$("#chatbox .content").removeClass("reduced")
		else
			$("#chatbox .content").addClass("reduced")
		window.field.scrollChatToEnd()
	)

	#$("button.prompt").click(->
		#window.field.prompt("프롬프트 테스트", "기본값", (r) -> alert r))
	#$("button.choose_promise").click(->
		#window.field.choosePromise(13, 14, true, " ", 0, (res) -> console.log(res)))
	#$("button.choose_promise_previous").click(->
		#window.field.choosePromise(17, 17, true, "h", 17, (res) -> console.log(res)))

	# 딜미스 보여주기
	#window.field.showDealMissHand ["s1","s2","s3","s4","jr","s5","s6","s8",'s9','d9']
	if window.LIBGAME?
		return


#	chooseMultiple 테스트 코드
#	window.field.setPlayers([
#		{name: "JongMan Koo", picture: "http://profile.ak.fbcdn.net/hprofile-ak-snc4/49218_593417379_9696_q.jpg"}
#		{name: "Wonha Ryu", picture: "http://profile.ak.fbcdn.net/hprofile-ak-snc4/41489_100000758278961_2887_q.jpg"}
#		{name: "Jinho Kim", picture: "http://profile.ak.fbcdn.net/hprofile-ak-snc4/161338_100000247121062_7309182_q.jpg"}
#		{name: "DoKyoung Lee", picture: "http://profile.ak.fbcdn.net/hprofile-ak-snc4/273911_100001947905915_2944452_q.jpg"}
#		{name: "Hyun-hwan Jung", picture: "http://profile.ak.fbcdn.net/hprofile-ak-snc4/202947_100002443708928_4531642_q.jpg"}
#	])
#	window.field.deal TEST_CARDS, 1, ->
#		window.field.chooseMultipleCards(3, 'n', 15, null, ->)



	window.field.setPlayers([
		{name: "JongMan Koo", picture: "http://profile.ak.fbcdn.net/hprofile-ak-snc4/49218_593417379_9696_q.jpg"}
		{name: "JongMan2 Koo", picture: "http://profile.ak.fbcdn.net/hprofile-ak-snc4/49218_593417379_9696_q.jpg"}
		{name: "Wonha Ryu", picture: "http://profile.ak.fbcdn.net/hprofile-ak-snc4/41489_100000758278961_2887_q.jpg"}
		{name: "Jinho Kim", picture: "http://profile.ak.fbcdn.net/hprofile-ak-snc4/161338_100000247121062_7309182_q.jpg"}
		{name: "DoKyoung Lee", picture: "http://profile.ak.fbcdn.net/hprofile-ak-snc4/273911_100001947905915_2944452_q.jpg"}
		{name: "Hyun-hwan Jung", picture: "http://profile.ak.fbcdn.net/hprofile-ak-snc4/202947_100002443708928_4531642_q.jpg"}
	])
	window.field.globalMessage("새 게임을 시작합니다")
	GAP = SPEED_BASE * 20
	window.field.deal TEST_CARDS6, 1, ->
		window.field.globalMessage("선거가 시작됩니다!")
		setTimeout(
			->
				window.field.playerMessage(1, "패스")
			, GAP)
		setTimeout(
			->
				window.field.playerMessage(2, "공약", "다이아몬드 14")
			, GAP*2)
		setTimeout(
			->
				window.field.playerMessage(3, "공약", "클로버 15")
			, GAP*3)
		setTimeout(
			->
				window.field.playerMessage(4, "패스")
			, GAP*4)
		setTimeout(
			->
				window.field.playerMessage(0, "공약", "스페이드 16")
			, GAP*5)
		setTimeout(
			->
				window.field.playerMessage(2, "패스")
			, GAP*6)
		setTimeout(
			->
				window.field.playerMessage(3, "패스")
				window.field.globalMessage("JongMan Koo 님이 당선되었습니다!")
				window.field.playerMessage(0, "당선", "스페이드 16")
				window.field.setPlayerType(0, "주공")
			, GAP*7)
		setTimeout(
			->
				###
				window.field.dealAdditionalCards(["back", "back", "back"], 1,
				->
					window.field.takeCards(1, (window.field.hands[1].pop() for i in [0..2]))
				)
				###
				window.field.dealAdditionalCards(["sq", "jr", "hk"], 0,
				->
					window.field.globalMessage("JongMan Koo님이 당을 재정비하고 있습니다.")
					window.field.chooseMultipleCards(3, 's', 16,
						(chosen) ->
							window.field.takeCards(0, chosen,
								->
									window.field.hands[0].remove(card) for card in chosen
									window.field.repositionCards(0)
									window.field.globalMessage("1턴이 시작되었습니다 !")

									window.field.playerMessage(0, "플레이", "차례입니다.")
									window.field.chooseCard((card) ->
										console.log("will play", card.face)
										window.field.playCard(0, "jr", "기루다 컴!")
										runInterval(GAP,
											[
												-> window.field.playCard(1, "ct")
												-> window.field.playCard(2, "sj")
												-> window.field.playCard(3, "c2")
												-> window.field.playCard(4, "st")
												-> window.field.endTurn(0, false)
											])
									)
							)
					)
				)
				# ##
			, GAP*8)

)
