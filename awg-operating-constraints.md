# ACQ400 AWG Operation

## Modes
AWG runs in one of 3 basic MODES:
ONESHOT, ONESHOT_AUTO_REPEAT, CONTINUOUS

## Regimes
it also runs in one of two "Operating Regimes": LONG, SHORT

## Segments
and there's also a SEGmented mode, where N patterns can be preloaded for playout with a rapid switch between SEG's.

There's one big GOTCHA with the whole setup:
# RULE#1 : DO NOT follow a very short waveform with a very long waveform.
This was not a design intention, but it does appear to be an actuality.


# Under the Hood:
To understand what's happening, it's important to know something about the DMA system that drives the AWG.

1. The 1GB ZYNQ DRAM (ZDRAM) is partitioned 50:50 between OS and data storage, so by default we have 512MB dedicated to data storage (AI) and AWG pattern memory (AO).

2. The Data Storage is divided into KBUFS, these are blocks of contiguous memory. Linux slab allocator rules mean these buffers are a power of 2, max 4MB. We default to 512 buffers of 1MB.
This can be set by the user in /mnt/local/sysconfig/acq400.sh, by setting the NBUF and BLEN variables. eg
NBUF=512; BLEN=1024576 and NBUF=128; BLEN=4194304 allocate the same 512 memory, but using 1MB and 4MB buffers respectively. 
The larger buffer size is useful for higher data rates (eg 2 x 32c x 512k). The smaller buffer size is useful for shorter waveforms. It's possible to allocate smaller buffers, but not really recommended.
The data system doesn't always have to  _use_  the full allocation.

3. Data Storage is relatively simple for the case AI only and for AO only. For a mixed AI/AO system, the memory is partitioned. This is the function of the Distributor First Buffer knob.

4. The AWG system was designed for "LONG" waveforms - pattern space greater than one buffer. The AWG system uses the ZYNQ/ARM hard core PL330 DMAC.
This is a highly capable DMA controller, and we've adapted it to work closely with the FPGA hardware; however it's extremely unconventional (think: micro-coded special purpose processor); in the author's opinion it's also a little too clever for its own good, because it doesn't fit standard DMA programming models well - for example the new buffer tee-up process takes a lot of cycles and is the limit on the system. Also, it should be said, there's very little evidence of other usage of this device, and Xilinx themselves replaced it in the ZYNQUS series.

There are some restrictions:
4.1 DMA length MUST be a multiple of sample size. It must also be a multiple of some internal byte count parameter; it's unclear to what that is - to be safe we say 256 bytes.
4.2 For LONG waveforms, we operate two DMA channels in a "Ping-Pong" configuration - that means that a DMA is always teed up and ready to go, and that's critical to limit the real-time issue of the long time-to-setup next buffer. With Ping-Pong, this time is always "time to consume one buffer". "Ping-Pong" (each DMA microcode other than the first in the series begins with "WFE: Wait For Event" and each DMA microcode other than the last ends with "STV: Set event" to trigger the next transfer). In general, once started, a DMA MUST COMPLETE or the system will be left in an undefined state. 
That means that the loaded pattern space will be 2N buffers long; in addition we found that the system needs a minimum of 4 buffers to run. This means, for a system with 1MB buffers, the MINIMUM AWG pattern space is 4MB, and the loader system will pad the waveform with the final value in the pattern to make 2N buffers. That means you could end up with a 1MB waveform followed by 3MB of flat.

=> The 2N method is OK for ONE_SHOT, ONE_SHOT_AUTO_REARM. It's not great for CONTINUOUS there will be a long flat period in the WF unless the pattern is designed to fill the space completely.

NB: It's debateable how useful the AWG is in CONTINUOUS mode - the waveforms have to be engineered with many cycles (or be really really slow). There's probably a better way - ie a Function Gen logic in FPGA (Sine/Ramp/Square) or a short waveform buffer in FPGA BRAM. Let us know if you really wanted to use the unit as a Function Generator :-).

4.3 For SHORT waveforms, the 4 buffer PING PONG can feel slow. There have been complaints!  There's an answer to this, and that is, if the entire waveform can fit in a single buffer, then it's feasible just to load a single channel DMA and fire it off. The software automatically switches to this more if the user pattern is less than one buffer. ie Default 1MB.
This works really well for ONE_SHOT, and ONE_SHOT_AUTO_REARM.  It's still not great for continuous (heavy real time requirement on the DMA load at the corner turn - with no ping-pong, chances are it's going to miss the deadline.

You can see when the WF is in SHORT mode - examine the interrupts page, there are 8 interrupts for the 8 hard-core pl330 DMA channels. In SHORT mode, ONE_SHOT you'll see just the one interrupt. One and Done.   In LONG mode, you'll see minimum 4 interrupts per ONE_SHOT.

4.4 If the SHORT mode is useful, but not long enough, there's a simple answer, and that's to switch to 4MB buffer allocations.

# GOTCHA: Do not mix Regimes!
GOTCHA: It has been discovered by multiple users that switching Regime from SHORT to LONG causes the box to fall over. I can only think this is some illegal setup in the DMAC. I don't propose to try to fix that; instead we'll document that users should ensure that ALL patterns in a session are either SHORT or LONG, not mixing. I think that is mostly reasonable, since one would expect most patterns to be similar size. UNLESS, one is setting the patterns length with a view of setting the waveform frequency. However, I'd assert that this is a misuse of the ARBITRARY WF feature - if you just needed a function generator, just get a function generator!.
