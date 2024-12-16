Engine_HS010 : CroneEngine {

	var wt, lfowt;
	var polyman;
	var synthgroup;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {

		// prereqs for generating synth
		var harmnum = 64;
		var serv = context.server;
		synthgroup = ParGroup.new(serv, \addToHead);

		wt = Buffer.allocConsecutive(4, serv, 2048, 1);
		wt[0].loadCollection(Signal.sineFill(1024,[1],[0]).asWavetable); // sine
		wt[1].loadCollection(
			Signal.sineFill(1024,harmnum.collect({|a, idx| if(a.even, {1/(a+1).pow(2)}, {0}) }),([pi, 0, 0, 0]!(harmnum/4)).flatten).asWavetable
		); // tri
		wt[2].loadCollection(Signal.sineFill(1024,harmnum.collect({|a, idx| 1/(1+a) }),pi!harmnum).asWavetable); // saw

		lfowt = Buffer.allocConsecutive(4, serv, 2048, 1);
		lfowt[0].loadCollection(Signal.sineFill(1024, [1], [pi]).asWavetable); //sine lfo
		lfowt[1].loadCollection(Env([0, 1, 0], [1, 1]).asSignal(1024).asWavetable); //tri lfo
		lfowt[2].loadCollection(Env([1, 1, 0, 0], [1, 0, 1]).asSignal(1024).asWavetable); //sqr lfo
		lfowt[3].loadCollection(Env([1, 0], [1]).asSignal(1024).asWavetable); //saw lfo

		SynthDef(\HS010, {
			|
			freq = 440, out = 0, amp = 1, gate = 1, pan = 0, vel = 0, // general suff
			sinidx, triidx, sawidx, lfoidx, // indexes
			pw = 0.5, pwlfo = 0, pwenv = 0, // pw
			lfosel = 0, lfofreq = 0.1, pitchlfo = 0, // lfo
			sinelev = 1, trilev = 0, sawlev = 0, pulselev = 0, sublev = 0, noiselev = 0, // mixer
			lpf = 1200, lpq = 1.5, lpfenv = 1000, lpflfo = 0, lpfpitch = 0, // lpf
			att = 0.01, dec = 0.5, sus = 0.5, rel = 1, crv = -4, // adsr
			subtype = 0, envtype = 0, glide = 0, // selections
			sendA = 0, sendB = 0, sendABus = 0, sendBBus = 0 // fx mod
			|
			var noise = WhiteNoise.ar;
			var lfo = Select.kr(
				((lfosel - 0.61) * 10 - 1).floor.clip(0, 3),
				[
					VOsc.kr(lfoidx + lfosel.clip(0, 0.8).linlin(0, 0.8, 0, 2.99), lfofreq),
					Latch.kr(noise, Impulse.kr(lfofreq)),
					noise
			]);
			var env = EnvGen.kr(Env.adsr(att, dec, sus, rel, curve: crv), gate);
			var cutoff = (lpf + (lpflfo * lfo) + (lpfenv * env) + (lpfpitch * freq)).clip(20, 20000);
			var pulsew = (pw + (pwlfo * lfo) + (pwenv * env)).clip(0, 1);
			var finfreq = Lag.kr(freq, glide) + (pitchlfo * lfo);
			var sine = Osc.ar(sinidx, finfreq);
			var tri = Osc.ar(triidx, finfreq);
			var saw = Osc.ar(sawidx, finfreq);
			var pulse = saw - DelayL.ar(saw, 1, (1/finfreq) * pulsew);
			var sub1 = ToggleFF.ar(saw);
			var sub2 = ToggleFF.ar(sub1);
			var sub = Select.ar(subtype, [
				sub1,
				sub2,
				((sub1 + sub2) - 1).clip(0, 1)
			]) * 2 - 1;
			var sig = Clip.ar(Mix.ar([
				sine*sinelev,
				tri*trilev,
				saw*sawlev,
				pulse*pulselev,
				LPF.ar(sub*sublev, 5000),
				noise*noiselev
			]), -1, 1);
			var finenv = Select.kr(envtype, [env, Lag.kr(gate, 0.02)]);
			sig = RLPF.ar(sig, cutoff, lpq);
			sig = RLPF.ar(sig, cutoff, lpq);
			sig = Pan2.ar(sig * finenv, pan, amp * vel);
			sig = LeakDC.ar(sig);
			Out.ar(out, LeakDC.ar(sig));
			Out.ar(sendABus, sendA * sig);
			Out.ar(sendBBus, sendB * sig);
		}).add;

		serv.sync;

		polyman = Polyphonia.new(6, synthgroup, \HS010, [
			\sinidx, wt[0],
			\triidx, wt[1],
			\sawidx, wt[2],
			\lfoidx, lfowt[0],
			\sendABus, (~sendA ? serv.outputBus),
			\sendBBus, (~sendB ? serv.outputBus),
			\gate, 0
		]);

		serv.sync;

		this.addCommands();

	}

	addCommands {

		var cmd = [
			[\pan, "f", -1, 1],
			[\amp, "f", 0, 1],
			[\pw, "f", 0, 1],
			[\pwlfo, "f", -1, 1],
			[\pwenv, "f", -1, 1],
			[\lfosel, "f", 0, 1],
			[\lfofreq, "f", 0.01, 100],
			[\pitchlfo, "i", 0, 20000],
			[\sinelev, "f", 0, 1],
			[\trilev, "f", 0, 1],
			[\sawlev, "f", 0, 1],
			[\pulselev, "f", 0, 1],
			[\sublev, "f", 0, 1],
			[\noiselev, "f", 0, 1],
			[\lpf, "i", 20, 20000],
			[\lpq, "f", 0.05, 1.5],
			[\lpfenv, "i", 0, 20000],
			[\lpflfo, "i", 0, 20000],
			[\lpfpitch, "f", 0, 1],
			[\att, "f", 0.01, 10],
			[\dec, "f", 0.01, 10],
			[\sus, "f", 0, 1],
			[\rel, "f", 0.01, 10],
			[\crv, "i", -6, 0],
			[\subtype, "i", 0, 3],
			[\envtype, "i", 0, 1],
		];

		this.addCommand(\noteOn, "if", {
			|msg|
			var id = msg[1], vel = msg[2];
			polyman.play(id, vel);
		});

		this.addCommand(\noteOff, "i", {
			|msg|
			var id = msg[1];
			polyman.stop(id);
		});

		this.addCommand(\noteOffAll, "", {
			polyman.killAll;
		});

		cmd.do({
			| a, idx |
			this.addCommand(a[0], a[1], {
				| msg |
				polyman.set([a[0], msg[1].clip(a[2], a[3])]);
			});
		});

		this.addCommand(\unidetune, "f", {
			| msg |
			polyman.uni_detune = msg[1].clip(0, 10);
		});

		this.addCommand(\voicemode, "i", {
			| msg |
			polyman.voice_mode = msg[1].clip(0, 2);
		});

		this.addCommand(\monomode, "i", {
			| msg |
			polyman.mono_mode = msg[1].clip(0, 2);
		});

		this.addCommand(\pitchslide, "f", {
			| msg |
			polyman.glide_time = msg[1].clip(0, 2);
		});
	}

	free {
		polyman.free;
		wt.do({ | val | val.free });
		lfowt.do({ | val | val.free });
		context.server.sync;
	}

}
