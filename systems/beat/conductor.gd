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
var section_times : Dictionary[StringName, int]

var _current_section_start : int = 0
var _current_section : StringName
var _section_index : int = 0

func get_section_idx() -> int:
	return _section_index

var want_next_section : bool = false

signal song_started
signal time_changed(new_time : float, delta_seconds : float)
signal section_changed(new_section : String, section_index : int)
signal event_added(event : BeatEvent)

class EventTiming:
	func UpdateStatus(new_status : RuleSet.WindowStatus):
		_status = new_status
		for event in events:
			event.update.emit(event, _status)
	var _status : RuleSet.WindowStatus = RuleSet.WindowStatus.CLOSED
	var events : Array[BeatEvent] = []

# all events that have been queued up [time][events]
var _timings : Dictionary[float, EventTiming]

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
	var section_time : int = 0
	for track in midi.get_tracks():
		# first track contains song meta
		# set the tempo (plugin currently fails to do this for you)
		if track['events'][0]['track'] == 0:
			for event in track["events"]:
				match event['subtype']:
					81:
						midi.set_tempo(event['data'])
					6:
						var delta : int = event['delta']
						section_time += delta
						section_times.get_or_add(event['data'], section_time)
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
	var marker_name : StringName = event['data']
	
	print(marker_name)
	
	if marker_name.contains('Section'):
		
		# scenario: resetting to previous section start immediatly triggers its marker
		if marker_name == _current_section:
			return
		
		var delta : int = event['delta']
		print("next section delta: " + str(delta))
		print("next section time: " + str(_current_section_start + delta))
		
		if delta == 0:
			want_next_section = true
		
		if want_next_section:
			_current_section = marker_name
			_current_section_start = section_times[_current_section]
			_section_index += 1
			section_changed.emit(_current_section, _section_index)
			want_next_section = false
		else:
			var seconds_per_tick : float = float(midi.tempo) / midi.division / 1000000.0;
			var prev_time : float = float(_current_section_start) * seconds_per_tick
			
			print("setting time: " + str(prev_time) + " section : " +  _current_section, "index: ", _section_index)
			var delta_seconds : float = delta * seconds_per_tick
			update_beat_timings(-delta_seconds)
			time_changed.emit(prev_time, -delta_seconds)
			main_track.seek(prev_time)
			set_current_time(prev_time)

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

	# print("[Track: " + str(_track) + "] Note played: " + str(event['note'] ))

func get_queued_events() -> Dictionary[float, EventTiming]:
	return _timings

# The timing track is an updatable list of ACTIVE beat events
func add_event(event: BeatEvent):
	_timings.get_or_add(event.time, EventTiming.new())
	_timings[event.time].events.append(event)
	event_added.emit(event)

func add_event_to_track(timing : float, note : Variant) -> BeatEvent:

	if get_state() == 2 || get_current_time() <= 0:
		return
	var event : BeatEvent = BeatEvent.create(timing, note)
	add_event(event)
	return event

func attempt_events():
	for events_at_time in _timings:
		if _timings[events_at_time]._status != RuleSet.WindowStatus.OPEN:
			continue
			
		var timing_result := get_timing_result(events_at_time)
		print("timing_result: " + str(timing_result))
		for beat_event in _timings.get(events_at_time).events as Array[BeatEvent]:
			beat_event.result.emit(beat_event, timing_result)
			_timings.erase(events_at_time)
	
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
	for event_timing in _timings:
		
		var time_diff_ms : float = abs(get_time_diff_ms(event_timing))
		var new_status := get_beat_status_from_ms(time_diff_ms)
		
		if _timings[event_timing]._status == new_status:
			continue
		
		_timings[event_timing].UpdateStatus(new_status)
		if (new_status == RuleSet.WindowStatus.CLOSED && time_diff_ms > 0):
			for event in _timings[event_timing].events:
				event.result.emit(event, RuleSet.EventResult.MISSED)
				_timings.erase(event_timing)
				#sound_hit_player.stream = sound_missed
				sound_hit_player.play()

func get_timing_result(timing : float) -> RuleSet.EventResult:
	var time_diff_ms : float = abs(get_time_diff_ms(timing))
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
	
func queue_fx(track : int):
	if !_is_valid_track(track):
		return
	
	track_fx[track] += 1
	if wants_fx[track] == true:
		var synced := main_track.stream as AudioStreamSynchronized
		synced.set_sync_stream_volume(track, 0)
	
func try_fx(track : int):
	if !_is_valid_track(track):
		return
		
	if !track_fx.has(track):
		return
	
	if track_fx[track] > 0:
		var synced := main_track.stream as AudioStreamSynchronized
		synced.set_sync_stream_volume(track, 0)
	wants_fx[track] = true

func duck_fx(track : int):
	if !_is_valid_track(track):
		return
	
	var synced := main_track.stream as AudioStreamSynchronized
	synced.set_sync_stream_volume(track, -80)
	wants_fx[track] = false

func pop_fx(track : int, pop_all : bool = false):
	if !_is_valid_track(track):
		return
	
	if pop_all:
		track_fx[track] = 0
	else:
		track_fx[track] -= 1
		track_fx[track] == max(track_fx[track], 0)
		
	if track_fx[track] == 0:
		var synced := main_track.stream as AudioStreamSynchronized
		synced.set_sync_stream_volume(track, -80)
		wants_fx[track] = false

func _is_valid_track(track : int) -> bool:
	if track <= 0:
		return false
	if !track_names.has(track):
		return false
	
	return true

func update_beat_timings(delta : float):
	for time in _timings.keys():
		var new_time : float = time + delta
		var beat_events : EventTiming = _timings[time]
		for event in beat_events.events:
			event.time = new_time
		var timing : EventTiming = _timings[time]
		_timings.erase(time)
		_timings.get_or_add(new_time, timing)
	print("new timings: ", _timings)
