/*
 * SectorPulsGenerator
 *
 * This Arduino projekt allows to use soft sectored diskettes in a NorthStar
 * Advantage Computer from the early 80th. Since hard sectored diskettes 
 * are no longer available today, you can use an Arduino to generate the necessary
 * sector pulses.
 * Tested with an Arduino Uno / Nano / Micro and a NorthStar Advantage
 *  - should run also run on other hard sectored systems - 
 *
 *
 * File:   spg_queue.c 
 *              Queue to store sector timings 
 *
 * Version: 1.0, May 2020
 *
 * Copyright (c) 2020 Holger Linning <HolgerLinning@yahoo.com>
 *
 * based on 
 *
 * AVR135: Using Timer Capture to Measure PWM Duty Cycle
 *         Copyright (C) 2016 Atmel Corporation. All rights reserved.
 *
 *
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
*/


#include "spg.h"

/**
 * spg_queue[]
 *
 * Stores number of ticks for a track.
 *
 */
spg_timer_ticks spg_queue[SPG_QSIZE];

/**
 * spg_queue_tail, spg_queue_head
 *
 * Queue state variables for spg_queue.
 *
 * The head and tail indices need to be wide enough to
 * accommodate [0:RX_QSIZE). Since QSIZE should generally
 * not be very large, these are hard-coded as single bytes,
 * which gets around certain atomicity concerns.
 */
/* spg_queue insertion index */
unsigned char spg_queue_tail;

#if !SPG_ANALOG /* SPG_DIGITAL */

/* spg_queue retrieval index */
unsigned char spg_queue_head;

#endif

#if SPG_ANALOG
/**
 * spg_total
 *
 * Used in computing a moving average for SPG_ANALOG samples.
 *
 */
spg_total_ticks spg_total;
#endif /* SPG_ANALOG */

/**
 * spg_enq()
 *
 * Stores a new sample into the queue.
 */
void spg_queue_enq(spg_timer_ticks sample)
{
	unsigned char t;

	t = spg_queue_tail;
#if SPG_ANALOG
	spg_total += sample - spg_queue[t];
#endif
	spg_queue[t] = sample;
	if (++t >= SPG_QSIZE)
		t = 0;
#if !SPG_ANALOG
	/* digital: Check for overrun */
	if (t != spg_queue_head)
#endif
		spg_queue_tail = t;
	return;
}

/**
 * spg_fetch()
 *
 * Fetch a sample from the queue. For analog mode, this is a moving
 * average of the last QSIZE readings. For digital, it is the oldest
 * reading.
 */
spg_timer_ticks spg_queue_fetch(void)
{
	spg_timer_ticks r;

#if SPG_ANALOG
	/* moving average of last QSIZE samples */
	r = spg_total ;/// SPG_QSIZE;
#else  /* SPG_DIGITAL */
	unsigned char h;

	h = spg_queue_head;
	/* if head == tail, queue is empty */
	if (h == spg_queue_tail)
		r = (spg_timer_ticks)-1;
	else
	{
		/* fetch next entry				*/
		r = spg_queue[h];
		/* increment head, modulo QSIZE	*/
		if (++h >= SPG_QSIZE)
			h = 0;
		spg_queue_head = h;
	}
#endif /* SPG_DIGITAL */

	return (r);
}
