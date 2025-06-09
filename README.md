## HS010

Happy Synthesis 010 - lead and bass synth with a multi-head sequencer.

This script started out as a 101-esque engine for use with other Norns sequencer scrips, 
but over time grew out into a full fledged, nb and fx mod enabled poly/mono voice and multi-headed step sequencer
heavily inspired by Fors.fm Roullete.

The synth is a pretty standard 101 affair with all of the parameters you'd expect and a few additions.
It has been expanded with:
- a morphing LFO:  
  From 0 to 0.8 morphping between Sine, Tri, Square and Saw,  
  From 0.8 to 0.9 functioning as a Sample and Hold,  
  From 0.9 till 1 as pure white noise  
- polyphony:  
  The *voice mode* parameter has three options:  
  1 - mono  
  2 - unison (6 voices with unison detune)  
  3 - 6 voice poly  
  While in mono or unison mode the *mono mode* option changes mono behaviour from legato, always retrigger or always glide.
- presets:
  You can load and save presets independently from norns .psets

Along these two there's also a param refresh button that resends the currently on screen params to the engine and a midi panic button.

The sequencer is, as mentioned before, inspired by roullete by fors and consists of 7 independent lanes:
- pitch (7 scale degrees)  
- velocity (8 levels)  
- Octave (8 octaves)  
- Offset A (+- 12 semitones)
- Offset B (+- 12 semitones)
- Gate  
- Slide  

Offset A and offset B add onto the current pitch or, if you press and hold key 1 and turn encoder 3 to turn that step into a polystep, play that step polyphonically.   
The polyphony works by taking the current pitch from lane 1 (the pitch lane), adding the offset, quantizing the new note to the scale and sending that note to the synth engine.  

You can navigate the sequencer with encoder 1, change the actively editable step with encoder 2 and change the value with encoder 3.  
Key 1 can be held down to reach additional functions, when turning encoder 1 you can change the length of that lane, turning encoder 2 changes step division and encoder 3, as mentioned before, on Offset A and B lanes makes that step play polyphonically.   
Key 2 stops the sequencer and key 3 resets the playheads back to step 1 on all lanes.

And that's pretty much it, enjoy playing!  

Known bugs:  
  - Slide when playing a polyphonic engine holds down a note indefinitely, will have to think of some other way to achieve slides.  
  - Probably many more that I don't know of.



  

