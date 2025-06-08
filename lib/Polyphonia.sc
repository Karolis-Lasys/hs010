Polyphonia {

	var voice_count;
	var def_name;
	var active_voice;
	var <voice_mode;  // 0 - mono, 1 - unison, 2 - poly
	var <>mono_mode; // 0 - legato on overlaying notes, 1 - always retrig, 2 - always glide
	var synth_group;
	var <>glide_time;
	var <note_list;
	var params;
	var <>uni_detune;

	*new {
		arg voicecount, target, synthdef, init_param, voicemode = 0, monomode = 0, unidetune = 0.2, glidetime = 0;
		^super.new.init(voicecount, target, synthdef, init_param, voicemode, monomode, unidetune, glidetime);
	}

	init {
		arg voicecount, target, synthdef, init_param, voicemode, monomode, unidetune, glidetime;
		voice_count = voicecount;
		synth_group = target;
		def_name = synthdef;
		active_voice = 0;
		params = Dictionary.newFrom(init_param);
		note_list = Array.fill(voicecount, {
			|i|
			var synthvoice = Synth.newPaused(synthdef, init_param, synth_group);
			[0, synthvoice];
		});
		voice_mode = voicemode;
		mono_mode = monomode;
		uni_detune = unidetune;
		glide_time = glidetime;
	}

	play {
		arg note, vel, forceslide = false;
		var freq = note.midicps;
		var monoglide = 0;
		note_list[active_voice].postln;
		("note on - " ++ note ++ " slide - " ++ (note_list[active_voice][0] != 0)).postln;
		switch(mono_mode.asInteger,
			0, {
				if((note_list[active_voice][0] != 0) || forceslide, {
					monoglide = glide_time;
				}, {
					monoglide = 0;
				});
			},
			1, {
				monoglide = 0;
			},
			2, {
				monoglide = glide_time;
			}
		);

		switch(voice_mode.asInteger,
			0, {
				active_voice = 0;
				note_list[0][0] = note;
				note_list[0][1].run;
				note_list[0][1].set(
					\gate, 1,
					\freq, freq,
					\vel, vel,
					\glide, monoglide
				);
			},
			1, {
				active_voice = 0;
				note_list.do {
					| voice, idx |
					note_list[idx][0] = note;
					voice[1].run;
					voice[1].set(
						\gate, 1,
						\freq, freq + (uni_detune * idx),
						\vel, vel,
						\glide, monoglide
					);
				}
			},
			2, {
				active_voice = (active_voice + 1) % voice_count;
				note_list[active_voice][0] = note;
				note_list[active_voice][1].run;
				note_list[active_voice][1].set(
					\gate, 1,
					\freq, freq,
					\vel, vel,
					\glide, glide_time
				);
			}
		);

	}

	stop {
		arg note;
		("note off - " ++ note).postln;
			note_list.do({
				| val, idx |
				if (val[0] == note, {
					this.kill(idx);
				}, {})
			});
	}

	set {
		arg set_params;
		params.putPairs(set_params);
		synth_group.set(*set_params);
	}

	kill {
		arg voice_no;
		note_list[voice_no][0] = 0;
		note_list[voice_no][1].set(\gate, 0);
	}

	killAll {
		synth_group.set(\gate, 0);
		note_list.do {
			| val, idx |
			note_list[idx][0] = 0;
		}
	}

	resetAll {
		note_list.do {
			| val, idx |
			this.reset(idx)
		}
	}

	reset {
		arg voice_no;
		var clipped_no = voice_no.clip(0, voice_count-1);
		note_list[clipped_no][1].free;
		note_list[clipped_no][1] = Synth.newPaused(def_name, params, synth_group);
	}

	free {
		synth_group.free;
		super.free;
	}

	voice_mode_ {
		arg vmode;
		voice_mode = vmode;
		active_voice = 0;
		this.killAll;
	}

}
