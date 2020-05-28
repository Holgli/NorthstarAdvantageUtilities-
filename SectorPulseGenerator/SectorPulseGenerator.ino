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
 * File:    SectorPulseGenerator.ino 
 *              Arduino sketch to generate hard sector pulses for soft 
 *              sectored diskettes
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

#include "spg_queue.c"
#include "spg.h"
#include "device.h"

/**********************************************************************************
 *
 * Global variables for timers and timings.
 *
 **********************************************************************************/
typedef unsigned int spg_timer_ticks;

//timer 1 vars for capturing pulses
spg_timer_ticks spg_start_time;        // start of sector/index pulse
spg_timer_ticks spg_track_sector_time; // time between two sector/index pulses
spg_timer_ticks spg_index_pulse_time;  // duration of sector/index pulse

//timer 2 vars for sector timing
spg_timer_ticks spg_sector_time;       //time in ticks for each sector
spg_timer_ticks spg_delta_time;        //time between sector pulses
spg_timer_ticks spg_first_sector_time; //index puls is half between two sectors
spg_timer_ticks current_period_time;   //time we are counting
unsigned char overflowsToCount;        //count of overflows for timer2 (count down to zero)

// Variables shared with the main loop for serial output
volatile float spg_rpm;           // disk speed
volatile unsigned char disk_type; // type of actual diskette (SS, HS10, HS16)

/**********************************************************************************
 *
 * Helper routines.
 *
 **********************************************************************************/

/**
 * Returns true if value is in range [low..high], else false
 *
 */
bool inRange(unsigned int low, unsigned int high, unsigned int value)
{
   return (low <= value && value <= high);
}

/**
 * Start Timer 2 with a 16 Bit value.  
 * When upper byte is counted down to zero, the the period is over 
 */
void start_period(spg_timer_ticks period)
{
   overflowsToCount = highByte(period) + 1; //Overflows are counted down in Timer2 Overflow Interrupt
   TCNT2 = lowByte(256U - lowByte(period)); //Start value to generate first overflow interrupt
   START_TIMER2;                            //Set prescaler to start counting
}

/**
 * Compute the timings for a sector  
 *     track_time: time in ticks for a track (example 200 ms = 50000 ticks)
 *     pulse_time: time in ticks for last index pulse (example 4 ms = 1000 ticks)
 * 
 * Start timer2 to measure the time for the rest of the last sector, since we
 * start with a half sector (index pulse is between 2 sectors)
 */
void spg_generate_pulses(spg_timer_ticks track_time, spg_timer_ticks pulse_time)
{
   spg_sector_time = track_time / SPG_DISK_TYPE;             //time in ticks for each sector
   spg_delta_time = spg_sector_time - pulse_time;            //time between pulses
   current_period_time = (spg_sector_time / 2) - pulse_time; //index puls is between two sectors
   spg_timer2_init();                                        //init timer to defaults
   start_period(current_period_time);                        //start with gap to first sector
}

/**
 * Indicate waiting by a specific intervall 
 */
void indicate_waiting(unsigned long interval)
{
   unsigned long currentMillis = millis();
   static int ledState = LOW;
   static unsigned long previousMillis = 0;

   if (currentMillis - previousMillis >= interval)
   {
      previousMillis = currentMillis;                     // save current time
      digitalWrite(LED_BUILTIN, (ledState) ? HIGH : LOW); // toggle state
      ledState = !ledState;                               // save current state
   }
}
/**********************************************************************************
 *
 * Interrupt Handlers:
 * 
 * TIMER2_OVF():  Timer2 is used for timings of the generated sectors  
 * TIMER1_CAPT(): Capture events are used to measure timings of the current disk
 * TIMER1_OVF():  When timer1 overflows we didn't find an index hole, so we assume
 *                that the disk is no longer rotating
 *
 **********************************************************************************/

/**
 *  TIMER2_OVF()
 * 
 *  If we have counted to the end of our actual period (overflows = 0), we can 
 *  set the marker for the edge of a new sector. 
*/
ISR(TIMER2_OVF_vect)
{
   overflowsToCount--; //count down overflows
   if (overflowsToCount == 0)
   {
      /* set next period */
      if (current_period_time == spg_index_pulse_time)
      {
         /* set output pin to mark end of pulse */
         digitalWrite(outPin, HIGH); // end of sector pulse
         current_period_time = spg_delta_time;
      }
      else
      {
         /* set output pin to mark end/start of sector*/
         digitalWrite(outPin, LOW); // set start of new sector
         current_period_time = spg_index_pulse_time;
      }
      //Count next setor / pulse
      start_period(current_period_time);
   }
}

/**
 * TIMER1_CAPT()
 *
 * Timer 1 capture interrupt is used for measuring timer ticks between
 * falling and rising edge of an index/sector pulse. The pulse should 
 * have a duration of about 4ms.
 */
ISR(TIMER1_CAPT_vect)
{
   spg_timer_ticks capture_time;
   unsigned char sense;

   /* capture time */
   capture_time = ICR1;

   /* reverse sense */
   sense = bitRead(TCCR1B, ICES1);
   bitToggle(TCCR1B, ICES1);

   /* what kind of event ? */
   if (sense == SPG_START_SENSE)
   {
      /*
       * Falling edge detected, so this is the start of the index / sector pulse.
       */

      /* reset time, start of new pulse/period */
      CLEAR_TIMER1;

      /* start timer 1 to measure next period */
      START_TIMER1;

      /* stop timer 2 */
      STOP_TIMER2; // stops generating pulses

      /* set output pin low to mirror the input*/
      digitalWrite(outPin, LOW);

      /* turn on LED to indicate pulse */
      digitalWrite(LED_BUILTIN, HIGH);

      /* timer was not started before, nothing measured */
      if (capture_time == 0)
         return;

      /*
        * Ticks between two start events, can be:
        * soft sector: track - track, 200ms
        * hard sector (10): sector - sector, 20ms
        * hard sector (10): track - sector, 10ms
        * hard sector (16): sector - sector, 12.5ms
        * hard sector (16): track - sector, 6.25ms
        */
      spg_track_sector_time = capture_time;

      /* determine type of disk */
      if (inRange(SPG_SS_LOW, SPG_SS_HIGH, spg_track_sector_time))
      {
         /* Soft sector */
         disk_type = SPG_SOFT_SECTOR;
         spg_rpm = 1.0 / (spg_track_sector_time * SPG_SECOND_PER_TICK) * 60.0;
      }
      else if (inRange(SPG_HS10_LOW2, SPG_HS10_HIGH2, spg_track_sector_time) || inRange(SPG_HS10_LOW, SPG_HS10_HIGH, spg_track_sector_time))
      {
         /* Hard sector 10 */
         disk_type = SPG_HARD_SECTOR_10;
         if (inRange(SPG_HS10_LOW2, SPG_HS10_HIGH2, spg_track_sector_time))
            spg_rpm = 1.0 / (spg_track_sector_time * 20.0 * SPG_SECOND_PER_TICK) * 60.0;
         else
            spg_rpm = 1.0 / (spg_track_sector_time * 10.0 * SPG_SECOND_PER_TICK) * 60.0;
      }
      else if (inRange(SPG_HS16_LOW2, SPG_HS16_HIGH2, spg_track_sector_time) || inRange(SPG_HS16_LOW, SPG_HS16_HIGH, spg_track_sector_time))
      {
         /* Hard sector 16 */
         disk_type = SPG_HARD_SECTOR_16;
         if (inRange(SPG_HS16_LOW2, SPG_HS16_HIGH2, spg_track_sector_time))
            spg_rpm = 1.0 / (spg_track_sector_time * 32.0 * SPG_SECOND_PER_TICK) * 60.0;
         else
            spg_rpm = 1.0 / (spg_track_sector_time * 16.0 * SPG_SECOND_PER_TICK) * 60.0;
      }
      else
      {
         /* Unknown disk */
         disk_type = SPG_UNKNOW_DISK;
         spg_rpm = 0.0;
         /* turn oFF LED */
         digitalWrite(LED_BUILTIN, LOW);
      }

      /* if we have a soft sectored disk we remember time to generate sector pulses */
      if (disk_type == SPG_SOFT_SECTOR)
      {
         /* remember time since previous pulse */
         spg_queue_enq(spg_track_sector_time);
      }
   }
   else
   {
      /*
       * Rising edge detected, so this is the end of the index / sector pulse.
       */

      /* set our output pin high to mirror the input*/
      digitalWrite(outPin, HIGH);

      /* turn oFF LED */
      digitalWrite(LED_BUILTIN, LOW);

      /* if we have a valid time and a soft sectored disk we generate pulses */
      if (capture_time != 0 && disk_type == SPG_SOFT_SECTOR)
      {
         spg_index_pulse_time = capture_time; /* timer was running before*/

         /* start generating pulses */
         spg_generate_pulses(spg_queue_fetch(), spg_index_pulse_time);
      }
   }

   return;
}

/**
 *  TIMER1_OVF()
 * 
 *  Timer1 overflows after about 262ms. On a timer1 overflow we didn't get
 *  an index/sector pulse so that we assume that the drive has stopped 
 *  rotating. 
 */
ISR(TIMER1_OVF_vect)
{
   spg_init(); /* re-init SectorPulseGenerator and wait for next Input Capture Insterrupt */
}

/**********************************************************************************
 *
 * Init-routines 
 * for timers 1 and 2 and the Arduino Sketch
 *
 **********************************************************************************/

/**
 * Set up the timer 1. 
 * Timer 1 is used to capture index/sector pulses
 */
void spg_timer1_init(void)
{

   TCCR1A = 0; /* nothing interesting to set in TCCR1A */

   TCCR1B = 0;                                /* clear prescaler to stop Timer 1*/
   bitWrite(TCCR1B, ICNC1, SPG_CANCEL_NOISE); /* set noise cancellation on/off */
   bitWrite(TCCR1B, ICES1, SPG_START_SENSE);  /* start with falling edge*/

   CLEAR_TIMER1; /* init counter to zero */

   TIMSK1 = 0;           /* init timer mask */
   TIMSK1 |= bit(TOIE1); /* enable timer overflow if no rotation  */
   TIMSK1 |= bit(ICIE1); /* enable input capture for detecting pulses*/

   return;
}

/**
 * Set up the timer 2. 
 * We use timer 2 to count the ticks between the edges of sector/index pulses.
 * This can be the pulse time of an index/index pulse, sector/index pulse or the time between two
 * sector pulses.   
 */

void spg_timer2_init(void)
{

   TCCR2A = 0; /* Nothing interesting to set in TCCR2A */
   TCCR2B = 0; /* clear prescaler to stop Timer 2 */

   CLEAR_TIMER2; /* init counter to zero */

   TIMSK2 = 0;           /* init timer mask */
   TIMSK2 |= bit(TOIE2); /* enable overflow interrupt */

   return;
}

/**
 * Init SectorPulseGenerator
 * Prepare Sketch so that it can start generating sector pulses if an index
 * pulse of a soft sectored diskette is detected. If additional sector pulses
 * are found, these pulses are mirrored to the output pin and no additial
 * pulses are generated.
 */
void spg_init(void)
{
   // Init times, nothing measured so far
   spg_start_time = 0;
   spg_track_sector_time = 0;
   spg_index_pulse_time = 0;
   spg_rpm = 0;
   disk_type = SPG_NO_DISK;
   spg_sector_time = 0;
   spg_delta_time = 0;
   spg_first_sector_time = 0;
   current_period_time = 0;
   overflowsToCount = 0;

   //  Init timers
   spg_timer1_init();
   spg_timer2_init();

   /* turn oFF LED */
   digitalWrite(LED_BUILTIN, LOW);
}

/**********************************************************************************
 *
 * Standard Arduino Sketch funcions
 *
 **********************************************************************************/
void setup()
{
   // Reset prescalers 0 and 1, and 2
   GTCCR &= ~(bit(PSRSYNC) | bit(PSRASY)); // clear existing flags
   GTCCR |= (bit(PSRSYNC) | bit(PSRASY));  // set wanted flags

   spg_init(); // init timers and times

   pinMode(icpPin, INPUT_PULLUP); // ICP pin (digital pin 8 on arduino) as input
   pinMode(outPin, OUTPUT);       // declare the ledPin as an OUTPUT
   pinMode(LED_BUILTIN, OUTPUT);  // buildin LED for indicating index pulses

   Serial.begin(115200);
   Serial.println("SectorPulseGenerator started...");
}

void loop()
{
   float rpm;
   static float last_rpm = -1;
   static unsigned int last_disk = SPG_UNKNOW_DISK;
   String info;
   String type;

   uint8_t oldSREG = SREG;
   cli();
   rpm = spg_rpm; // get disk speed
   SREG = oldSREG;

   switch (disk_type)
   {
   case SPG_NO_DISK:
      info = "No diskette detected. Waiting...";
      indicate_waiting(800);
      break;
   case SPG_SOFT_SECTOR:
      info = "Soft sectored diskette detected.";
      type = " (SS)";
      break;
   case SPG_HARD_SECTOR_10:
      info = "Hard sectored diskette (10 sectors) detected.";
      type = " (HS10)";
      break;
   case SPG_HARD_SECTOR_16:
      info = "Hard sectored diskette (16 sectors) detected.";
      type = " (HS16)";
      break;
   default:
      info = "Unknow diskette type detected.";
      indicate_waiting(200);
      break;
   }

   if (disk_type != last_disk)
      Serial.println(info);

   if ((disk_type == SPG_SOFT_SECTOR || disk_type == SPG_HARD_SECTOR_10 || disk_type == SPG_HARD_SECTOR_16) && roundf(last_rpm * 100) / 100 != roundf(rpm * 100) / 100)
   {
      //Enable to print rotational speed
      Serial.print("Current rotational speed: ");
      Serial.print(rpm, 2);
      Serial.println(" RPM" + type);
   }
   last_rpm = rpm;
   last_disk = disk_type;
}
