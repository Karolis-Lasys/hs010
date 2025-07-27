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

Since version 1.1.0 there's also grid support:

<img width="761" height="509" alt="Screenshot 2025-07-26 at 20 48 47" src="https://github.com/user-attachments/assets/77ffef3a-81ff-47b8-8409-9ce20e1c53fa" />

Rows 1 to 7 represent their respective sequencer lanes, row 8 is global functions.
Cell 1 on row 8 is a toggle to stop/start playback, cell 2 resets the playheads.
Cell 3 turns on edit mode:

<img width="628" height="492" alt="Screenshot 2025-07-26 at 20 58 32" src="https://github.com/user-attachments/assets/f86843ce-4e0f-4a18-9bc8-adbacda64cc8" />

You can edit the value of the step by holding it and selecting a value on the new menu that appears on the other side of the grid. The dimmer the value - the lower the value of the cell. The fullbright cell represents the current value. You close the selection menu by releasing the held step.

Cell 4 turns on sequence length edit mode:

<img width="764" height="511" alt="Screenshot 2025-07-26 at 21 02 43" src="https://github.com/user-attachments/assets/01f19d3b-915e-4da7-af4b-95e1795ab08b" />

Change the respective row's sequence length by pushing a cell, the row will grow/shrink to your selected length. One thing to note is when shrinking all of the values that were cut off are stored in a temp buffer - this can be a good performance tool.

Cell 5 is step length edit mode:

<img width="789" height="518" alt="Screenshot 2025-07-26 at 21 08 17" src="https://github.com/user-attachments/assets/f7d791d9-b8c1-483f-9e45-6fa8bbee5656" />

Here you can edit how long a single step takes on that respective sequence row.

Cells 13 to 16 change global sequencer step pages, that is, on page one you can edit steps from 1 to 16, page two - 17 to 32 and so on.

And that's pretty much it, enjoy playing!  

Known bugs:  
  - Slide when playing a polyphonic engine holds down a note indefinitely, will have to think of some other way to achieve slides. (maybe not a bug but a feature?)
  - Probably many more that I don't know of.



  

