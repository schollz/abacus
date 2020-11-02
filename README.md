
## abacus

sequence rows of samples with calculated beats.

![Image](https://user-images.githubusercontent.com/6550035/97828526-2956aa00-1c7c-11eb-9845-9a6b8000cf4c.gif)

this norns script creates sequences of samples from a tape. you can load any tape and splice it into up to 26 samples (named a-z). samples can then be patterned into 16-subdivided measures. patterns can then be chained together.

this script was a hard one to make because at a certain point i kept getting caught up playing with for hours instead of figuring out how to make it user-friendly... 

this script builds off others. it is inspired a lot from ideas in [glitchlets](https://llllllll.co/t/glitchlets) (no realtime here) and a lot of code ideas from @mattbiddulph's exquisite [beets](https://llllllll.co/t/beets-1-0/30069) (initially i forked beets but i didn't want to ruin the code with my hacks). also inspiration from the po-33. and, it is inspired by @csboling's beautiful waveform renderings.

future directions:

- fix all the 🐛🐛🐛
- add individual parameters for samples
- add play trigger

### Requirements

- norns (version 201023+)

### Documentation

- K1+E1 changes mode

sample mode

- E1 changes sample
- E2/E3 change splice position
- K1+K3 starts/stops chain
- K2 zooms
- K3 plays sample

pattern mode

- E1 changes pattern
- E2 selects sample
- E3 positions sample
- K2 patterns
- K3 plays sample
- K1+K2 erases position
- K1+K3 plays pattern

chain mode

- E2 positions
- E3 selects pattern
- K2/K3 does effects

## demo 


<p align="center"><a href="https://www.instagram.com/p/CHEyfpZB0YZ/"><img src="https://user-images.githubusercontent.com/6550035/97829923-468d7780-1c80-11eb-9b89-89e7a003b4ac.png" alt="Demo of playing" width=80%></a></p>


<p align="center"><a href="https://www.instagram.com/p/CHDXh2QB_9L/"><img src="https://user-images.githubusercontent.com/6550035/97828771-e812ca00-1c7c-11eb-8241-9fd73a5c3b06.png" alt="Demo of playing" width=80%></a></p>

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



