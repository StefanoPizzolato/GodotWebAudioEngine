extends Control

onready var d = {1:$Level1,2:$Level2,3:$Level3} #dictionary for level cues
export var bpm = 60 #bpm of music cues
export var bar_subdivision = 4 #the metric subdivision of a bar (4/4, 3/4, etc)
export var n_bars = 4 #n of bars in the cues

onready var transition_q = 4 #the beats needed to perform a transition

export var transition_duration = 0.5 #seconds
var transition_type = 3 #Quadratic curve for Equal power crossfade

var last_cue = null #holds the last cue played
var new_cue = null #holds the new cue to play
var current_cue_position = 0

var timer = Timer.new() #timer for new cue
var timer_stinger = Timer.new() #timer for stinger

var music_volume = 0 #default volume
var music_volume_duck = 3 #db to duck from original value

func _ready():
	#transform the slider value into number of beats
	transition_q = pow(int(2),int(get_node("../TransitionQBeats").value)) 
	get_node("../transitionLabel").text="Transition every "+str(transition_q)+" beats"
	
func _process(delta):
	#show the current beat
	if last_cue!=null:
		var beat = fmod(ceil(d[last_cue].get_playback_position()*bpm / 60)-1,transition_q)+1
		get_node("Beat").text = str(beat)

func _on_level1_pressed():
	play_cue(1)

func _on_level2_pressed():
	play_cue(2)

func _on_level3_pressed():
	play_cue(3)

func fade_out(stream_player):
	$TweenOut.interpolate_property(stream_player, "volume_db", music_volume, -80, transition_duration, transition_type, Tween.EASE_IN, 0)
	$TweenOut.start()
	
func fade_in(stream_player):
	stream_player.play(current_cue_position);
	if last_cue!=null:
		$TweenIn.interpolate_property(stream_player, "volume_db", -80, music_volume, transition_duration, transition_type, Tween.EASE_OUT, 0)
		$TweenIn.start()
		
func duck(stream_player):
	stream_player.volume_db-=music_volume_duck;

func _on_TweenOut_tween_completed(object, key):
	# stop the music -- otherwise it continues to run at silent volume
	object.stop()
	
func _on_TweenIn_tween_completed(object, key):
	pass

func play_cue(cue):	
	
	if new_cue==cue:
		return;
	else:
		new_cue=cue;

	#immediate transition vs timed transition
	if get_node("../immediateTrans").is_pressed():	
		play(cue)
	else:
		#here is where the quantization magic happens
		var tot_cue_length = 60/bpm*bar_subdivision*n_bars
		var q_time = 60/bpm*transition_q
		current_pos() #update current_pos
		#crossfades in the middle
		var time_to_end_q = fmod(tot_cue_length-current_cue_position, q_time)-transition_duration/2
		
		# STINGER PLAY
		if get_node("../transitions").is_pressed():	
			timer_stinger = Timer.new()
			#ASSUMING THAT ALL STINGERS START 1 beat before the change
			var time_to_stinger = time_to_end_q+transition_duration/2-float(30)/float(bpm)
			#RULE: Play stinger only if we are in time to play it
			if time_to_stinger>0: 
				timer_stinger.wait_time = time_to_stinger
				timer_stinger.one_shot = true
				timer_stinger.connect("timeout",self,"play_stinger")
				add_child(timer_stinger)
				timer_stinger.start()
		
		# MAIN CUE PLAY
		# if transition triggered in the crossfade window of the previous cue
		# then it will play on the second beat, so you still have a nice crosfade
		# and you don't have to wait another transition_q
		timer = Timer.new()
		print("time to end q "+str(time_to_end_q))
		timer.wait_time = time_to_end_q
		timer.one_shot = true
		timer.connect("timeout",self,"play",[cue])
		add_child(timer)
		timer.start()

func current_pos():
	if last_cue!=null:
		#get position of music in the playing cue so you know where to start next cue
		current_cue_position = d[last_cue].get_playback_position(); 
	else:
		current_cue_position = 0; #first cue played
	
func play(cue):
	current_pos()
	for i in range(1,d.size()+1):
		if i!=cue:
			fade_out(d[i]) #fade out all cues except the one that should play
	fade_in(d[cue])
	last_cue=cue;
	
func play_stinger():
	print("play stinger")
	if new_cue!=null && last_cue!=null:
		duckMusic()
		if new_cue-last_cue>0:
			playLevelUp()
		if new_cue-last_cue<0:
			playLevelDown()
	
func playLevelUp():
	$LevelUp.play()
	
func playLevelDown():
	$LevelDown.play()

func duckMusic():
	if get_node("../duckingForTransitions").is_pressed():
		duck(d[last_cue])

#----------
# TRIGGERS
func _on_TransitionQBeats_value_changed(value):
	transition_q = pow(int(2),int(get_node("../TransitionQBeats").value))
	get_node("../transitionLabel").text="Transition every "+str(transition_q)+" beats"

func _on_immediateTrans_toggled(button_pressed):
	if button_pressed:
		get_node("../transitions").disabled = true
		get_node("../duckingForTransitions").disabled = true
		get_node("../TransitionQBeats").editable = false
		get_node("../transitionLabel").text="Immediate transition"
		$Beat.visible=false
	else:
		get_node("../transitions").disabled = false
		get_node("../duckingForTransitions").disabled = false
		get_node("../TransitionQBeats").editable = true
		get_node("../transitionLabel").text="Transition every "+str(transition_q)+" beats"
		$Beat.visible=true
