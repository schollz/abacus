
## abacus

sequence rows of samples with calculated beats.

![Image](https://user-images.githubusercontent.com/6550035/97828526-2956aa00-1c7c-11eb-9845-9a6b8000cf4c.gif)


this norns script creates sequences of samples from a tape. you can load any tape and splice it into up to 26 samples (named a-z). samples can then be patterned into 16-subdivided measures. patterns can then be chained together.

this script follow a lot of previous things. i got inspiration/code from [glitchlets](https://github.com/schollz/glitchlets) and [beets](https://llllllll.co/t/beets-1-0/30069) and designed a lot of aspects similar to how the po-33 sampler works, but more tuned to my tastes.

future directions:

- fix all the 🐛🐛🐛
- add sample specific filters

### Requirements

- norns

### Documentation

- K1+E1 changes mode
- K1+K3 starts/stops chain

sample mode

- E1 changes sample
- E2/E3 change splice position
- K2 zooms
- K3 plays sample

pattern mode

- K2 patterns
- K1+K2 erases pattern
- E1 changes pattern
- E2 selects sample
- E3 positions sample

chain mode

- E2 positions
- E3 selects pattern
- K2/K3 do effects

## demo 

<p align="center"><a href="https://www.instagram.com/p/CHDXh2QB_9L/"><img src="?" alt="Demo of playing" width=80%></a></p>

## my other norns

- [barcode](https://github.com/schollz/barcode): replays a buffer six times, at different levels & pans & rates & positions, modulated by lfos on every parameter.
- [blndr](https://github.com/schollz/blndr): a quantized delay with time morphing
- [clcks](https://github.com/schollz/clcks): a tempo-locked repeater
- [oooooo](https://github.com/schollz/oooooo): digital tape loops
- [piwip](https://github.com/schollz/piwip): play instruments while instruments play.
- [glitchlets](https://github.com/schollz/glitchlets): 
add glitching to everything.

## license 

mit 



