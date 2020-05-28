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
 * File:   spgh.h 
 *              Header file for SectorPulseGenerator.ino
 * 
 * Version: 1.0, May 2020
 *
 * Copyright (c) 2020 Holger Linning <HolgerLinning@yahoo.com>
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

#define icpPin 8 // ICP input pin (from disk drive)
#define outPin 2 // output pin (to controller)

/* assume analog mode = 1 /	digital mode = 0 */
#define SPG_ANALOG 0

/* queue 5 elements	for analog mode, 1 for digital mode	*/
#define SPG_BUFSIZE 1

#if SPG_ANALOG
/* same as BUFSIZE			*/
#define SPG_QSIZE SPG_BUFSIZE
#else /* SPG_DIGITAL */
/* 1 extra for queue management */
#define SPG_QSIZE (SPG_BUFSIZE + 1)
#endif

/* Input Capture Noise Canceler (4 CKs), should not be necessary */
#define SPG_CANCEL_NOISE 0

/* Pulses start with falling edge */
#define SPG_START_SENSE 0

/* Disk type */
#define SPG_NO_DISK 0U
#define SPG_SOFT_SECTOR 1U
#define SPG_HARD_SECTOR_10 10U
#define SPG_HARD_SECTOR_16 16U
#define SPG_UNKNOW_DISK 255U

/* Disk type to emulate */
#define SPG_DISK_TYPE SPG_HARD_SECTOR_10

/* define prescale values*/
#define SPG_PRESCALER 64U
#define SPG_PRESCALER_TIMER_1 (bit(CS11) | bit(CS10))
#define SPG_PRESCALER_TIMER_2 bit(CS22)

/* start stop timers */
#define START_TIMER1 TCCR1B |= SPG_PRESCALER_TIMER_1
#define STOP_TIMER1 TCCR1B &= 0B11111000
#define CLEAR_TIMER1 TCNT1 = 0

#define START_TIMER2 TCCR2B |= SPG_PRESCALER_TIMER_2
#define STOP_TIMER2 TCCR2B &= 0B11111000
#define CLEAR_TIMER2 TCNT2 = 0

/* Some timings in ticks for 16MHz and prescaler 64 */
#define SPG_SECOND_PER_TICK 0.000004 // (1.0 / F_CPU) * SPG_PRESCALER
#define SPG_TICKS_PER_MILLI 250U     // (1.0 / SPG_SECOND_PER_TICK) / 1000.0
#define SPG_TICKS_PER_MILLI2 125U    // (1.0 / SPG_SECOND_PER_TICK) / 2000.0

/* Sector / track timings in ticks to determine type of disk */
/* Disk speed SPG_RPM = 300 */
#define SPG_TIME_SS_TRACK 200U * SPG_TICKS_PER_MILLI  // ((1.0 / SPG_RPM) * 60.0) in ticks
#define SPG_TIME_HS10_TRACK 20U * SPG_TICKS_PER_MILLI // (SPG_TIME_SS_TRACK / 10.0) in ticks
#define SPG_TIME_HS16_TRACK 12U * SPG_TICKS_PER_MILLI // (SPG_TIME_SS_TRACK / 16.0) in ticks

/* High and low value for soft sector: 200 ms +/- 8.0 ms*/
#define SPG_SS_HIGH (SPG_TIME_SS_TRACK + (SPG_TICKS_PER_MILLI * 8)) /* 200 ms + 8 ms in ticks*/
#define SPG_SS_LOW (SPG_TIME_SS_TRACK - (SPG_TICKS_PER_MILLI * 8))  /* 200 ms - 8 ms in ticks*/

/* High and low values for hard sector 10, sector to sector: 20 ms +/- 1.0 ms*/
#define SPG_HS10_HIGH (SPG_TIME_HS10_TRACK + SPG_TICKS_PER_MILLI) /* 20 ms + 1.0 ms in ticks */
#define SPG_HS10_LOW (SPG_TIME_HS10_TRACK - SPG_TICKS_PER_MILLI)  /* 20 ms - 1.0 ms in ticks */

/* High and low values for hard sector 10, track to sector: 10ms +/- 0.5ms*/
#define SPG_HS10_HIGH2 ((SPG_TIME_HS10_TRACK / 2) + SPG_TICKS_PER_MILLI2) /* 10 ms + 0.5 ms in ticks */
#define SPG_HS10_LOW2 ((SPG_TIME_HS10_TRACK / 2) - SPG_TICKS_PER_MILLI2)  /* 10 ms - 0.5 ms in ticks */

/* High and low values for hard sector 16, sector to sector: 12 ms +/- 1.0 ms*/
#define SPG_HS16_HIGH (SPG_TIME_HS16_TRACK + SPG_TICKS_PER_MILLI) /* 12 ms + 1.0 ms in ticks */
#define SPG_HS16_LOW (SPG_TIME_HS16_TRACK - SPG_TICKS_PER_MILLI)  /* 12 ms - 1.0 ms in ticks */

/* High and low values for hard sector 16, track to sector: 6ms +/- 0.5ms*/
#define SPG_HS16_HIGH2 ((SPG_TIME_HS16_TRACK / 2) + SPG_TICKS_PER_MILLI) /* 6 ms + 1.0 ms in ticks */
#define SPG_HS16_LOW2 ((SPG_TIME_HS16_TRACK / 2) - SPG_TICKS_PER_MILLI2) /* 6 ms - 0.5 ms in ticks */

/*
 * Typedefs
 */
typedef unsigned int spg_timer_ticks;
typedef unsigned int spg_total_ticks;

/*
 * API Prototypes
 */
void spg_queue_init(void);
void spg_queue_enq(spg_timer_ticks);
spg_timer_ticks spg_queue_fetch(void);
