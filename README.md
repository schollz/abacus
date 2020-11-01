
## abacus

sequence rows of samples with calculated beats.

![Image](?)

*lets glitch with glitchlets.*                                                         

this norns script creates sequences of samples from a tape. you can load any tape and splice it into up to 26 samples (named a-z). samples can then be patterned into 16-subdivided measures. patterns can then be chained together.

this script follow a lot of previous things. i got inspiration/code from [glitchlets](https://github.com/schollz/glitchlets) and [beets](https://llllllll.co/t/beets-1-0/30069) and designed a lot of aspects similar to how the po-33 sampler works, but more tuned to my tastes.

future directions:

- fix all the 🐛🐛🐛
- add sample specific filters

### Requirements

- norns

### Documentation

**quickstart:** put music into line-in. set norns global tempo in `clock -> tempo` to tempo of music. open glitchlets and press K1+K2.

all five glitchlets can be consciously controlled via global params or quick menu. quick menu:

- first set clock->tempo then reload glitchlets
- K1+K2 does quick start
- hold K1 to turn off glitches
- K2 manually glitches
- K3 or K1+K3 switch glitchlet
- E1 switches parameters
- E2/E3 modulate parameters

*note:* make sure to restart norns the first time you install because it has a new supercollider engine that needs to be compiled.

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



