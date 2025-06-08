NB_HS010 {

	classvar wt, lfowt;
	classvar polyman;
	classvar synthgroup;

	*initClass {

		StartUp.add({
			var cmd;

			SynthDef(\NB_HS010, {
				|
				freq = 440, out = 0, amp = 0.6, gate = 0, pan = 0, vel = 0, // general suff
				sinidx, triidx, sawidx, lfoidx, // indexes
				pw = 0.5, pwlfo = 0, pwenv = 0, // pw
				lfosel = 0, lfofreq = 0.1, pitchlfo = 0, // lfo
				sinelev = 1, trilev = 0, sawlev = 0, pulselev = 0, sublev = 0, noiselev = 0, // mixer
				lpf = 1200, lpq = 1, lpfenv = 1000, lpflfo = 0, lpfpitch = 0, // lpf
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
				var env = EnvGen.kr(Env.adsr(att, dec, sus, rel, curve: crv), gate, doneAction: Done.pauseSelf);
				var cutoff = (lpf + (lpflfo * lfo) + (lpfenv * env) + (lpfpitch * freq)).clip(20, 19000);
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

			cmd = [
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
				[\sendA, "f", 0, 1],
				[\sendB, "f", 0, 1]
			];

			OSCFunc.new({ |msg, time, addr, recvPort|
				polyman.play(msg[1], msg[2], msg[3]);
			}, "/hs010/note_on");

			OSCFunc.new({ |msg, time, addr, recvPort|
				polyman.stop(msg[1]);
			}, "/hs010/note_off");

			OSCFunc.new({ |msg, time, addr, recvPort|
				polyman.killAll;
			}, "/hs010/note_off_all");

			OSCFunc.new({ |msg, time, addr, recvPort|
				polyman.uni_detune = msg[1].clip(0, 10);
			}, "/hs010/unidetune");

			OSCFunc.new({ |msg, time, addr, recvPort|
				var clipped_mode = msg[1].clip(0, 2);
				polyman.voice_mode_(clipped_mode);
			}, "/hs010/voicemode");

			OSCFunc.new({ |msg, time, addr, recvPort|
				polyman.mono_mode = msg[1].clip(0, 2);
			}, "/hs010/monomode");

			OSCFunc.new({ |msg, time, addr, recvPort|
				polyman.glide_time = msg[1].clip(0, 2);
			}, "/hs010/pitchslide");

			OSCFunc.new({ |msg, time, addr, recvPort|
				polyman.free;
				wt.do({ | val | val.free });
				lfowt.do({ | val | val.free });
			}, "/hs010/free_synth");

			cmd.do({
				| a, idx |
				OSCFunc.new({ |msg, time, addr, recvPort|
					polyman.set([a[0], msg[1].clip(a[2], a[3])]);
				}, "/hs010/" ++ a[0]);
			});

			(Routine.new {
				var harmnum;
				10.yield;
                Server.default.sync;
				"Happy Synthesis: conjuring HS010".postln;
			harmnum = 64;
			synthgroup = ParGroup.new(Server.default, \addToHead);

			wt = Buffer.allocConsecutive(4, Server.default, 2048, 1);
			wt[0].loadCollection(Signal.sineFill(1024,[1],[pi]).asWavetable); // sine
			wt[1].loadCollection(
				Signal.sineFill(1024,harmnum.collect({|a, idx| if(a.even, {1/(a+1).pow(2)}, {0}) }),([pi, 0, 0, 0]!(harmnum/4)).flatten).asWavetable
			); // tri
			wt[2].loadCollection(Signal.sineFill(1024,harmnum.collect({|a, idx| 1/(1+a) }),pi!harmnum).asWavetable); // saw

			lfowt = Buffer.allocConsecutive(4, Server.default, 2048, 1);
			lfowt[0].loadCollection(Signal.sineFill(1024, [1], [pi]).asWavetable); //sine lfo
			lfowt[1].loadCollection(Env([0, 1, 0], [1, 1]).asSignal(1024).asWavetable); //tri lfo
			lfowt[2].loadCollection(Env([1, 1, 0, 0], [1, 0, 1]).asSignal(1024).asWavetable); //sqr lfo
			lfowt[3].loadCollection(Env([1, 0], [1]).asSignal(1024).asWavetable); //saw lfo

			polyman = Polyphonia.new(6, synthgroup, \NB_HS010, [
				\sinidx, wt[0],
				\triidx, wt[1],
				\sawidx, wt[2],
				\lfoidx, lfowt[0],
				\sendABus, (~sendA ? Server.default.outputBus),
				\sendBBus, (~sendB ? Server.default.outputBus),
				\gate, 0
			]);

			}).play;

		});

	}

}
