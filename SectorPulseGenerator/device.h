/*
 * SectorPulsGenerator
 *
 * This Arduino projekt allows to use soft sectored diskettes on a NorthStar
 * Advantage Computer from the early 80th. Since today hard sectored diskettes 
 * are no longer available today, you can use an Arduino to generate the necessary
 * sector pulses.
 * Tested with an Arduino Uno / Nano / Micro and an NorthStar Advantage
 *  - should run also run on other hard sectored systems - 
 *
 *
 * File:   device.h 
 *              when developing with Microsoft Visual Studio Code some 
 *              defines for the AVR_ATmega328P are missing. Not needed for the
 *              Arduino IDE. 
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


/*
 * Some includes for __AVR_ATmega328P__ not working? 
 * (necessary for MS Visual Studio Code)
 */
#ifndef TCCR2A
#define TCCR2A _SFR_MEM8(0xB0)
#define WGM20 0
#define WGM21 1
#define COM2B0 4
#define COM2B1 5
#define COM2A0 6
#define COM2A1 7
#endif

#ifndef TCCR2B
#define TCCR2B _SFR_MEM8(0xB1)
#define CS20 0
#define CS21 1
#define CS22 2
#define WGM22 3
#define FOC2B 6
#define FOC2A 7
#endif

#ifndef TCNT2
#define TCNT2 _SFR_MEM8(0xB2)
#define TCNT2_0 0
#define TCNT2_1 1
#define TCNT2_2 2
#define TCNT2_3 3
#define TCNT2_4 4
#define TCNT2_5 5
#define TCNT2_6 6
#define TCNT2_7 7
#endif