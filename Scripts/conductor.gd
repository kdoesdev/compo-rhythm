extends MidiPlayer

@onready var main_track : AudioStreamPlayer = $MainTrack
@onready var sound_hit_player : AudioStreamPlayer = $EventResultSound
@export var sound_missed : AudioStreamWAV = null

@export var song_spec : SongSpec = null

var track_names : Dictionary[int, String]

# [track, fx_stack_count]
var track_fx : Dictionary[int, int]
var wants_fx : Dictionary[int, bool]

# [delta, time]
var section_times : Dictionary[float, float]

var want_next_section : bool = false

signal song_started
signal event_added(event : BeatEvent)

class BeatEvents:
	func UpdateStatus(new_status : RuleSet.WindowStatus):
		_status = new_status
		for event in events:
			event.update.emit(event, _status)
	var _status : RuleSet.WindowStatus = RuleSet.WindowStatus.CLOSED
	var events : Array[BeatEvent] = []

# all events that have been queued up [time][events]
var _queued_events : Dictionary[float, BeatEvents]

var bpm : float

func _ready():
	
	midi = song_spec.midi
	
	var stream_synced := AudioStreamSynchronized.new()
	stream_synced.stream_count = song_spec.layers.size() + 1
	
	stream_synced.set_sync_stream(0, song_spec.base_track)
	
	for i in song_spec.layers:
		stream_synced.set_sync_stream(i, song_spec.layers[i])
		stream_synced.set_sync_stream_volume(i, -80)
	
	main_track.stream = stream_synced
	
	await get_tree().create_timer(1).timeout
	
	assert(midi.format == 1)
	
	if midi.format != 1:
		return
	
	#print(midi.tracks)
	var section_time : float = 0
	for track in midi.get_tracks():
		# first track contains song meta
		# set the tempo (plugin currently fails to do this for you)
		if track['events'][0]['track'] == 0:
			for event in track["events"]:
				match event['subtype']:
					81:
						midi.set_tempo(event['data'])
					6:
						var delta = event['delta']
						section_time += delta
						section_times.get_or_add(delta, section_time)
			continue
			
		# Note events won't contain the track name
		# So match it to the track number in advance
		var track_meta = track["events"][0]
		if track_meta["type"] == "meta":
			track_names.get_or_add(track_meta["track"], track_meta["data"])
			track_fx.get_or_add(track_meta["track"], 0)
			wants_fx.get_or_add(track_meta["track"], false)
	
	bpm = 60000000.0/Conductor.midi.tempo
	bpm = ceil(bpm) if is_equal_approx(bpm, ceil(bpm)) else bpm
	
	# link the AudioStreamPlayer in your scene
	# that contains the music associated with the midi
	# NOTE: this must be an array, you can link multiple ASPs or one as
	# shown below and they will all sync with playback of the MIDI
	link_audio_stream_player([main_track])
	note.connect(note_event)
	meta.connect(meta_event)
	play()
	song_started.emit()


func _process(_delta: float) -> void:
	process_beat()

func meta_event(event, _track):
	if event['subtype'] != 6:
		return
	var marker_name : String = event['data']
	
	print(marker_name)
	
	if marker_name.contains('Section'):
		var delta : float = event['delta']
		print("delta: " + str(delta))
		var time : float = section_times.get(delta)
		print("time: " + str(time))
		if delta == 0:
			return
		
		if !want_next_section:
			var prev_time : float = (time - delta) / 1000 / bpm * 60
			
			print("setting time: " + str(prev_time))
			main_track.seek(prev_time)
			set_current_time(prev_time)
			update_beat_timings(0)

func note_event(event, _track):
	var note : int = event['note']
	var layer := int(event['track'])
	
	if note == 0 && event['subtype'] == MIDI_MESSAGE_NOTE_OFF:
		
		pop_fx(layer)
		return
	else: queue_fx(layer)
	
	#var player : AudioStreamPlayer = AudioStreamPlayer.new()
	#add_child(player)
	#player.stream = sound
	#player.play()
	#player.finished.connect(player.queue_free)

	#print("[Track: " + str(track_name) + "] Note played: " + str(event['note'] ))

func get_queued_events() -> Dictionary[float, BeatEvents]:
	return _queued_events

# The timing track is an updatable list of ACTIVE beat events
func add_event(event: BeatEvent):
	_queued_events.get_or_add(event.time, BeatEvents.new())
	_queued_events[event.time].events.append(event)
	event_added.emit(event)

func add_event_to_track(timing : float, note : Variant) -> BeatEvent:

	if get_state() == 2 || get_current_time() <= 0:
		return
	var event : BeatEvent = BeatEvent.create(timing, note)
	add_event(event)
	return event

func attempt_events():
	
	for timestamp in _queued_events:
		if _queued_events[timestamp]._status != RuleSet.WindowStatus.OPEN:
			return
			
		var timing_result := get_timing_result(timestamp)
		for beat_event in _queued_events.get(timestamp).events as Array[BeatEvent]:
			beat_event.result.emit(beat_event, timing_result)
			_queued_events.erase(timestamp)
	
			#var track_name : String = Conductor.track_names.get(beat_event.note['track'])
			#var sound : AudioStreamWAV = load("res://sound/songs/" + track_name + ".wav")
			#var player : AudioStreamPlayer = AudioStreamPlayer.new()
			#add_child(player)
			#player.stream = sound
			#player.finished.connect(player.queue_free)
			
			var note : Variant = beat_event.note
			var layer := int(note['track'])
			
			match timing_result:
				RuleSet.EventResult.PERFECT:
					sound_hit_player.play()
					if note['note'] == 0:
						try_fx(layer)
				RuleSet.EventResult.GOOD:
					sound_hit_player.play()
					if note['note'] == 0:
						try_fx(layer)
				RuleSet.EventResult.MISSED:
					sound_hit_player.play()
					duck_fx(layer)
					
			#player.play()

func process_beat():
	for event_beat in _queued_events:
		
		var time_diff_ms : float = abs(get_time_diff_ms(event_beat))
		var new_status := get_beat_status_from_ms(time_diff_ms)
		
		if _queued_events[event_beat]._status == new_status:
			continue
		
		_queued_events[event_beat].UpdateStatus(new_status)
		if (new_status == RuleSet.WindowStatus.CLOSED && time_diff_ms > 0):
			for event in _queued_events[event_beat].events:
				event.result.emit(event, RuleSet.EventResult.MISSED)
				_queued_events.erase(event_beat)
				sound_hit_player.stream = sound_missed
				sound_hit_player.play()

func get_timing_result(event_beat : float) -> RuleSet.EventResult:
	var time_diff_ms : float = abs(get_time_diff_ms(event_beat))
	for timing_window in RuleSet.timing_windows_ms:
		if time_diff_ms <= timing_window:
			return RuleSet.timing_windows_ms[timing_window]
			
	return RuleSet.EventResult.MAX

func get_beat_status(event_beat : float) -> RuleSet.WindowStatus:
	var time_diff_ms : float = get_time_diff_ms(event_beat)
	return get_beat_status_from_ms(time_diff_ms)

func get_time_diff_ms(event_beat: float) -> float:
	return (event_beat - get_current_time()) * 1000

func get_beat_status_from_ms(time_diff_ms : float) -> RuleSet.WindowStatus:
	if abs(time_diff_ms) <= RuleSet.window_open_ms:
		return RuleSet.WindowStatus.OPEN
	
	# approaching is from one direction
	if time_diff_ms <= 0 && abs(time_diff_ms) <= RuleSet.window_approaching_ms:
		return RuleSet.WindowStatus.APPROACHING
		
	return RuleSet.WindowStatus.CLOSED
	
func update_beat_timings(delta : float):
	for time in _queued_events:
		var beat_events : BeatEvents = _queued_events[time]
		for event in beat_events.events:
			event.time += delta
		
		time += delta
		
func queue_fx(track : int):
	track_fx[track] += 1
	if wants_fx[track] == true:
		var synced := main_track.stream as AudioStreamSynchronized
		synced.set_sync_stream_volume(track, 0)
	
func try_fx(track : int):
	if track_fx[track] > 0:
		var synced := main_track.stream as AudioStreamSynchronized
		synced.set_sync_stream_volume(track, 0)
	wants_fx[track] = true

func duck_fx(track : int):
	var synced := main_track.stream as AudioStreamSynchronized
	synced.set_sync_stream_volume(track, -80)
	wants_fx[track] = false

func pop_fx(track : int, pop_all : bool = false):
	if pop_all:
		track_fx[track] = 0
	else:
		track_fx[track] -= 1
		track_fx[track] == max(track_fx[track], 0)
		
	if track_fx[track] == 0:
		var synced := main_track.stream as AudioStreamSynchronized
		synced.set_sync_stream_volume(track, -80)
		wants_fx[track] = false
