DAT objectName          byte "StepperSpiX", 0
CON
{{

  15h Doesn't work even with CS on I/O pin.
  Change name from "OledAsmScratch150415l" to "StepperSpi150416a."
  18d Abandon 18c.
  18d Use both P2 and shared SPI clock in ADC code.
  The ADC works with using P2 but not when using the shared clock.
  Shared clock wasn't starting low. Fixed.
  18e Try using shared data. Shared data doesn't work.
  18f Try using '595 CS line.
  18g Use separate data pin for ADC.
  18h Abandon 18g.
  18i Try to get rid of redundant code.
  18i Still works.
  18j Try shared data again. Doesn't work with shared data.
  25a Use separate pin for '165 data line. "shiftMisoMask"
  25b Had read and write in jump table wrong.
  Change name from "StepperSpi150425d" to "StepperSpi."
  
************************************************
* OLED_AsmFast (well, faster)                  *
* Thomas P. Sullivan                           *
* Copyright (c) 2012                           *
* Some original comments left/modified         *
* See end of file for terms of use.            *
************************************************
Revision History:

  Version 140828a modified by Duane Degn.
           SPI calls sped up. Variables and methods
           changed to conform with Parallax Gold
           Standard conventions.
           
  V1.0   - Original program 12-2-2012
  V1.1   - Changes to comments and modification 
           of a few commands.
  V1.2   - Added support for the 128x64 display 12-16-2012

This is a Propeller driver object for the Adafruit
SSDD1306 OLED Display. It has functions to draw
individual pixels, lines, and rectangles. It also
has character functions to print 16x32 characters
derived from the Propeller's internal fonts.


     ┌───────────────────────────────┐    
     │            SSD1306            │    
     │            Adafruit           │    
     │             128x32            │    
     │          OLED Display         │    
     │                               │    
     │  resetPin clockPin VIN    GND │    
     │csPin   D/C   dataPin   3.3    │    
     └─┬───┬───┬───┬───┬───┬───┬───┬─┘    
       │   │   │   │   │   │   │   │


This file is based on the following code sources:
************************************************
* Propeller SPI Engine                    v1.2 *
* Author: Beau Schwabe                         *
* Copyright (c) 2009 Parallax                  *
* See end of file for terms of use.            *
************************************************

...and this code:

*********************************************************************
This is a library for our Monochrome OLEDs based on SSD1306 drivers

  Pick one up today in the adafruit shop!
  ------> http://www.adafruit.com/category/63_98

These displays use SPI to communicate, 4 or 5 pins are required to  
interface

Adafruit invests time and resources providing this open source code, 
please support Adafruit and open-source hardware by purchasing 
products from Adafruit!

Written by Limor Fried/Ladyada  for Adafruit Industries.  
BSD license, check license.txt for more information
All text above, and the splash screen below must be included in
any redistribution
*********************************************************************
Note: The splash screen is way down in the DAT section of this file.
         
}}
CON

  BLACK = 0
  WHITE = 1

  TYPE_128X32                   = 32
  TYPE_128X64                   = 64
  OLED_BUFFER_SIZE    = 1024

  SSD1306_LCDWIDTH              = 128
  SSD1306_LCDHEIGHT32           = 32
  SSD1306_LCDHEIGHT64           = 64
  SSD1306_LCDCHARMAX            = 8

  SSD1306_SETCONTRAST           = $81
  SSD1306_DISPLAYALLON_RESUME   = $A4
  SSD1306_DISPLAYALLON          = $A5
  SSD1306_NORMALDISPLAY         = $A6
  SSD1306_INVERTDISPLAY         = $A7
  SSD1306_DISPLAYOFF            = $AE
  SSD1306_DISPLAYON             = $AF
  SSD1306_SETDISPLAYOFFSET      = $D3
  SSD1306_SETCOMPINS            = $DA
  SSD1306_SETVCOMDETECT         = $DB
  SSD1306_SETDISPLAYCLOCKDIV    = $D5
  SSD1306_SETPRECHARGE          = $D9
  SSD1306_SETMULTIPLEX          = $A8
  SSD1306_SETLOWCOLUMN          = $00
  SSD1306_SETHIGHCOLUMN         = $10
  SSD1306_SETSTARTLINE          = $40
  SSD1306_MEMORYMODE            = $20
  SSD1306_COMSCANINC            = $C0
  SSD1306_COMSCANDEC            = $C8
  SSD1306_SEGREMAP              = $A0
  SSD1306_CHARGEPUMP            = $8D
  SSD1306_EXTERNALVCC           = $1
  SSD1306_SWITCHCAPVCC          = $2

  'Scrolling #defines
  SSD1306_ACTIVATE_SCROLL       = $2F
  SSD1306_DEACTIVATE_SCROLL     = $2E
  SSD1306_SET_VERT_SCROLL_AREA  = $A3
  SSD1306_RIGHT_HORIZ_SCROLL    = $26
  SSD1306_LEFT_HORIZ_SCROLL     = $27
  SSD1306_VERTRIGHTHORIZSCROLL  = $29
  SSD1306_VERTLEFTHORIZSCROLL   = $2A

  SHIFT_OUT_BYTE = 1
  SHIFT_OUT_BUFFER = 2
  
PRI SpiInit(shiftRegisterOutputPtr_, debugPtr) 
'' Call SpiInit prior to calling Start.
  Com.Str(0, string(11, 13, "SpiInit Method"))

  'spiLock := lock
  spiLock := locknew
   
  commandAddress := @command 'commandAddress_
  
  oledBufferPtr := @buffer
  
  {Com.Str(0, string(11, 13, "mailboxAddr = "))
  Pst.Dec(mailboxAddr)
  Com.Str(0, string(11, 13, "oledBufferPtr = "))
  Pst.Dec(oledBufferPtr)}
  
  shiftRegisterOutputPtr := shiftRegisterOutputPtr_
  shiftRegisterInputPtr := shiftRegisterOutputPtr_ + 4
  shiftRegisterOutputCog := shiftRegisterOutputPtr_
  shiftRegisterInputCog := shiftRegisterOutputPtr_ + 4
  adcPtr := shiftRegisterOutputPtr_ + 8
  
  {commandAddress_ += 4
  repeat result from 0 to 2
    csChanMaskX[result] := 1 << byte[csChanPtr][result]
    resetChanMaskX[result] := 1 << byte[csChanPtr + 3][result]
    sleepChanMaskX[result] := 1 << byte[csChanPtr + 6][result]  }
  debugAddress := debugPtr
  repeat result from 0 to Header#MAX_DEBUG_SPI_INDEX
    debugAddress0[result] := debugPtr
    debugPtr += 4
    
  'clockMask := 1 << clockPin
  'mosiMask := 1 << mosiPin
  'misoMask := 1 << misoPin
  'latch595Mask := 1 << latch595Pin
  'latch165Mask := 1 << latch165Pin
  'csOledChanMask := 1 << csOledChan
  'csAdcChanMask := 1 << csAdcChan
  
  'result := cognew(@oledBuffer, commandAddress)

  waitcnt(clkfreq / 100 + cnt)
  
  'OledInit

PUB ReadableBin(localValue, size) | bufferPtr, localBuffer[12]    
'' This method display binary numbers
'' in easier to read groups of four
'' format.

  bufferPtr := Format.Ch(@localBuffer, "%")
  
  result := size // 4
   
  if result
    size -= result
    bufferPtr := Format.Bin(bufferPtr, localValue >> size, result)
    if size
      bufferPtr := Format.Ch(bufferPtr, "_")
  size -= 4
 
  repeat while size => 0
    bufferPtr := Format.Bin(bufferPtr, localValue >> size, 4)
    if size
      bufferPtr := Format.Ch(bufferPtr, "_")  
    size -= 4
    
  byte[bufferPtr] := 0  
  Com.Str(0, @localBuffer)
  
PUB PressToContinue
  
  Com.Str(0, string(11, 13, "Press to continue."))
  repeat
    result := Com.RxHowFull(0)
  until result
  Com.RxFlush(0)

PRI SafeTx(localCharacter)
'' Debug lock should be set prior to calling this method.

  if (localCharacter > 32 and localCharacter < 127)
    Com.Tx(0, localCharacter)    
  else
    Com.Tx(0, 60)
    Com.Tx(0, 36) 
    Com.Hex(0, localCharacter, 2)
    Com.Tx(0, 62)

DAT

commandAddress          long 0
shiftRegisterOutputPtr  long 0
shiftRegisterInputPtr   long 0
oledBufferPtr           long 0
shiftRegisterOutputSpin long 0

  
DAT

cog                     long 0
command                 long 0
mailbox                 long 0
vccState                long 0
displayType             long 0
displayWidth            long 0
displayHeight           long 0
autoUpdate              long 0
resetChan               long 1 << Header#RESET_OLED_595
dataCommandChan         long 1 << Header#DC_OLED_595
debugAddress            long 0-0
refreshCount            long 0
  
buffer                  byte 0[OLED_BUFFER_SIZE]
'dataCommandPin          byte 0
'resetPin                byte 2
adcChannelsInUse        byte Header#DEFAULT_ADC_CHANNELS
firstAdcChannelInUse    byte Header#DEFAULT_FIRST_ADC_CHANNEL
spiLock                 byte 255

OBJ

  Header : "HeaderCnc"
  'Pst : "Parallax Serial TerminalDat"
  Com : "Serial4PortSd"
  Format : "StrFmt"
   
PUB Start(vccState_, type_, shiftRegisterOutputPtr_, debugPtr)
'' Start SPI Engine - starts a cog
'' returns false if no cog available

  'Stop
  SpiInit(shiftRegisterOutputPtr_, debugPtr)
  
  ''Initialize variables 
  longmove(@vccState, @vccState_, 2)

  displayType := type_

  bufferAddress := @buffer
                    
  mailboxAddr := @mailbox
  refreshCountPtr := @refreshCount
  bitsFromSpinPtr := @shiftRegisterOutputSpin
  adcInUsePtr := @adcChannelsInUse
  firstAdcPtr := @firstAdcChannelInUse
  
  result := cog := cognew(@entry, @command) + 1

  repeat while command
   
  InitDisplay
    
{PUB Stop
'' Stop SPI Engine - frees a cog

  if cog
     cogstop(cog~ - 1)
  command~
 }
PUB LSpi

  repeat while lockset(spiLock)

PUB CSpi

  lockclr(spiLock)
  
PUB SetCommand(cmd)

  LSpi
  command := cmd                '' Write command 
  repeat while command          '' Wait for command to be cleared, signifying receipt
    {if cmd == Header#ADC_SPI
  
      Com.Str(0, string(11, 13, "adcRequest = "))
      Pst.Dec(long[debugAddress0])
      Com.Str(0, string(" = "))
      ReadableBin(long[debugAddress0], 32)
      Com.Str(0, string(11, 13, "activeAdcPtr = "))
      Pst.Dec(long[debugAddress1])
      Com.Str(0, string(", adcPtr = "))
      Pst.Dec(adcPtr)
      Com.Str(0, string(11, 13, "dataValue = "))
      Pst.Dec(long[debugAddress2])
      Com.Str(0, string(" = "))
      ReadableBin(long[debugAddress2], 32)
      Com.Str(0, string(11, 13, "bufferAddress = "))
      Pst.Dec(long[debugAddress3])
      Com.Str(0, string(11, 13, "dataOut = "))
      Pst.Dec(long[debugAddress4])
      Com.Str(0, string(" = "))
      ReadableBin(long[debugAddress4], 32)
      Com.Str(0, string(11, 13, "byteCount = "))
      Pst.Dec(long[debugAddress5])
      Com.Str(0, string(11, 13, "location clue = "))
      Pst.Dec(long[debugAddress6])
      Com.Str(0, string(11, 13, "dataOutToShred = "))
      Pst.Dec(long[debugAddress7])
      Com.Str(0, string(" = "))
      ReadableBin(long[debugAddress7], 32)
      Com.Str(0, string(11, 13, "adcInUseCog = "))
      Pst.Dec(long[debugAddress8])   }
  CSpi
      
PRI InitDisplay

  if displayType == TYPE_128X32
    displayWidth := SSD1306_LCDWIDTH
    displayHeight := SSD1306_LCDHEIGHT32
  else
    displayWidth := SSD1306_LCDWIDTH
    displayHeight := SSD1306_LCDHEIGHT64

  SpinLow595(Header#DC_OLED_595) ' ***
  'SpinHigh595(Header#DC_OLED_595) ' ***
  
  ''Setup reset and pin direction
  SpinHigh595(Header#RESET_OLED_595) 
  'High(resetPin)
  ''VDD (3.3V) goes high at start; wait for a ms
  waitcnt(clkfreq / 100000 + cnt)
  ''force reset low
  SpinLow595(Header#RESET_OLED_595)
  'Low(resetPin)
  ''wait 10ms
  waitcnt(clkfreq / 100000 + cnt)
  ''remove reset
  SpinHigh595(Header#RESET_OLED_595)
  'High(resetPin)

  if displayType == TYPE_128X32
    ''************************************
    ''Init sequence for 128x32 OLED module
    ''************************************
    Ssd1306Command(SSD1306_DISPLAYOFF)             
    Ssd1306Command(SSD1306_SETDISPLAYCLOCKDIV)     
    Ssd1306Command($80)                            
    Ssd1306Command(SSD1306_SETMULTIPLEX)           
    Ssd1306Command($1F)
    Ssd1306Command(SSD1306_SETDISPLAYOFFSET)       
    Ssd1306Command($0)                             
    Ssd1306Command(SSD1306_SETSTARTLINE | $0)      
    Ssd1306Command(SSD1306_CHARGEPUMP)             
     
    if vccstate == SSD1306_EXTERNALVCC 
      Ssd1306Command($10)
    else 
      Ssd1306Command($14)
     
    Ssd1306Command(SSD1306_MEMORYMODE)             
    Ssd1306Command($00)                            
    Ssd1306Command(SSD1306_SEGREMAP | $1)
    Ssd1306Command(SSD1306_COMSCANDEC)
    Ssd1306Command(SSD1306_SETCOMPINS)             
    Ssd1306Command($02)
    Ssd1306Command(SSD1306_SETCONTRAST)            
    Ssd1306Command($8F)
    Ssd1306Command(SSD1306_SETPRECHARGE)           
     
    if vccstate == SSD1306_EXTERNALVCC 
      Ssd1306Command($22)
    else 'SSD1306_SWITCHCAPVCC 
      Ssd1306Command($F1)
     
    Ssd1306Command(SSD1306_SETVCOMDETECT)          
    Ssd1306Command($40)
    Ssd1306Command(SSD1306_DISPLAYALLON_RESUME)    
    Ssd1306Command(SSD1306_NORMALDISPLAY)          
     
    Ssd1306Command(SSD1306_DISPLAYON)'--turn on oled panel
       ''************************************   
  else ''Init sequence for 128x64 OLED module
       ''************************************
    Ssd1306Command(SSD1306_DISPLAYOFF)             
    Ssd1306Command(SSD1306_SETLOWCOLUMN)  ' low col = 0
    Ssd1306Command(SSD1306_SETHIGHCOLUMN) ' hi col = 0
    Ssd1306Command(SSD1306_SETSTARTLINE)  ' line #0
    Ssd1306Command(SSD1306_SETCONTRAST)            

    if vccstate == SSD1306_EXTERNALVCC 
      Ssd1306Command($9F)
    else 
      Ssd1306Command($CF)

    Ssd1306Command($A1)
    Ssd1306Command(SSD1306_NORMALDISPLAY)
    Ssd1306Command(SSD1306_DISPLAYALLON_RESUME)
    Ssd1306Command(SSD1306_SETMULTIPLEX)           
    Ssd1306Command($3F)
    Ssd1306Command(SSD1306_SETDISPLAYOFFSET)       
    Ssd1306Command($0) 'No offset                            
    Ssd1306Command(SSD1306_SETDISPLAYCLOCKDIV)     
    Ssd1306Command($80)                            
    Ssd1306Command(SSD1306_SETPRECHARGE)

    if vccstate == SSD1306_EXTERNALVCC 
      Ssd1306Command($22)
    else 
      Ssd1306Command($F1)

    Ssd1306Command(SSD1306_SETVCOMDETECT)          
    Ssd1306Command($40)

    Ssd1306Command(SSD1306_SETCOMPINS)          
    Ssd1306Command($12)

    Ssd1306Command(SSD1306_MEMORYMODE)          
    Ssd1306Command($00)

    Ssd1306Command(SSD1306_SEGREMAP | $1)

    Ssd1306Command(SSD1306_COMSCANDEC)

    Ssd1306Command(SSD1306_CHARGEPUMP)

    if vccstate == SSD1306_EXTERNALVCC 
      Ssd1306Command($10)
    else
      Ssd1306Command($14)
     
    Ssd1306Command(SSD1306_DISPLAYON)'--turn on oled panel

  InvertDisplay(false)
  autoUpdateOn
  ClearDisplay

PUB ShiftOut(value)

  mailbox := value           
  SetCommand(Header#OLED_WRITE_ONE_SPI)

PUB WriteBuff(addr)

  mailbox := addr           
  SetCommand(Header#OLED_WRITE_BUFFER_SPI)
       
PUB InvertDisplay(invertFlag)
  'This in an OLED command that inverts the display. Probably faster
  'than complimenting the screen buffer.
  if invertFlag == true
    Ssd1306Command(SSD1306_INVERTDISPLAY)
  else
    Ssd1306Command(SSD1306_NORMALDISPLAY)

PUB StartScrollRight(scrollStart, scrollStop)
  ''startscrollright
  ''Activate a right handed scroll for rows start through stop
  ''Hint, the display is 16 rows tall. To scroll the whole display, run:
  ''display.scrollright($00, $0F) 
  Ssd1306Command(SSD1306_RIGHT_HORIZ_SCROLL)
  Ssd1306Command($00)
  Ssd1306Command(scrollStart)
  Ssd1306Command($00)
  Ssd1306Command(scrollStop)
  Ssd1306Command($01)
  Ssd1306Command($FF)
  Ssd1306Command(SSD1306_ACTIVATE_SCROLL)

PUB StartScrollLeft(scrollStart, scrollStop)
  ''startscrollleft
  ''Activate a right handed scroll for rows start through stop
  ''Hint, the display is 16 rows tall. To scroll the whole display, run:
  ''display.scrollright($00, $0F) 
  Ssd1306Command(SSD1306_LEFT_HORIZ_SCROLL)
  Ssd1306Command($00)
  Ssd1306Command(scrollStart)
  Ssd1306Command($00)
  Ssd1306Command(scrollStop)
  Ssd1306Command($01)
  Ssd1306Command($FF)
  Ssd1306Command(SSD1306_ACTIVATE_SCROLL)

PUB StartScrollDiagRight(scrollStart, scrollStop)
  ''startscrolldiagright
  ''Activate a diagonal scroll for rows start through stop
  ''Hint, the display is 16 rows tall. To scroll the whole display, run:
  ''display.scrollright($00, $0F) 
  Ssd1306Command(SSD1306_SET_VERT_SCROLL_AREA)      
  Ssd1306Command($00)
  Ssd1306Command(displayHeight)
  Ssd1306Command(SSD1306_VERTRIGHTHORIZSCROLL)
  Ssd1306Command($00)
  Ssd1306Command(scrollStart)
  Ssd1306Command($00)
  Ssd1306Command(scrollStop)
  Ssd1306Command($01)
  Ssd1306Command(SSD1306_ACTIVATE_SCROLL)

PUB StartScrollDiagLeft(scrollStart, scrollStop)
  ''startscrolldiagleft
  ''Activate a diagonal scroll for rows start through stop
  ''Hint, the display is 16 rows tall. To scroll the whole display, run:
  ''display.scrollright($00, $0F) 
  Ssd1306Command(SSD1306_SET_VERT_SCROLL_AREA)      
  Ssd1306Command($00)
  Ssd1306Command(displayHeight)
  Ssd1306Command(SSD1306_VERTLEFTHORIZSCROLL)
  Ssd1306Command($00)
  Ssd1306Command(scrollStart)
  Ssd1306Command($00)
  Ssd1306Command(scrollStop)
  Ssd1306Command($01)
  Ssd1306Command(SSD1306_ACTIVATE_SCROLL)

PUB StopScroll
  ''Stop the scroll
  
  Ssd1306Command(SSD1306_DEACTIVATE_SCROLL)

PUB ClearDisplay
  ''Clearing the display means just writing zeroes to the screen buffer.
  
  bytefill(@buffer, 0, ((displayWidth * displayHeight) / 8))
  UpdateDisplay 'Clearing the display ALWAYS updates the display

PUB PlotPoint(x, y, color) | pp
  ''Plot a point x,y on the screen. color is really just on or off (1 or 0)
  
  x &= $7F
  if y > 0 and y < displayHeight
    if color == WHITE
      buffer[x + ((y >> 3) * 128)] |= |< (y // 8)
    else  'Clear the bit and it's off (black)
      buffer[x + ((y >> 3) * 128)] &= !(|< (y // 8))
   
PUB UpdateDisplay | i, tmp
  ''Writes the screen buffer to the memory of the display
  
  Ssd1306Command(SSD1306_SETLOWCOLUMN)  ' low col = 0
  Ssd1306Command(SSD1306_SETHIGHCOLUMN) ' hi col = 0
  Ssd1306Command(SSD1306_SETSTARTLINE)  ' line #0

  SpinHigh595(Header#DC_OLED_595) 
  'High(dataCommandPin)
  WriteBuff(@buffer)    

PRI Swap(a, b) | t
  ''Needed by Line function below
  
  t := long[a]
  long[a] := long[b]
  long[b] := t 

PUB Line(x0, y0, x1, y1, c) | steep, deltax, deltay, error, ystep, yy, xx
  ''Draws a line on the screen
  ''Adapted/converted from psuedo-code found on Wikipedia:
  ''http://en.wikipedia.org/wiki/Bresenham's_line_algorithm      
  steep := ||(y1 - y0) > ||(x1 - x0)
  if steep
    swap(@x0, @y0)
    swap(@x1, @y1)
  if x0 > x1 
    swap(@x0, @x1)
    swap(@y0, @y1)
  deltax := x1 - x0
  deltay := ||(y1 - y0)
  error := deltax << 1
  yy := y0
  if y0 < y1
    ystep := 1
  else
    ystep := -1
  repeat xx from x0 to x1
    if steep
      plotPoint(yy, xx, c)
    else
      plotPoint(xx, yy, c)
    error := error - deltay
    if error < 0
      yy := yy + ystep
      error := error + deltax
  if autoUpdate
    UpdateDisplay
  
PUB Box(x0, y0, x1, y1, c)
  ''Draw a box formed by the coordinates of a diagonal line
  
  Line(x0, y0, x1, y0, c)
  Line(x1, y0, x1, y1, c)
  Line(x1, y1, x0, y1, c)
  Line(x0, y1, x0, y0, c)

PUB Write1x8String(str, len) | i
  ''Write a string on the display starting at position zero (left)
  
  repeat i from 0 to (len <# SSD1306_LCDCHARMAX) - 1
    write16x32Char(byte[str][i], 0, i) 

PUB Write2x8String(str, len, row) | i

  row &= $1 'Force in bounds
  if displayType == TYPE_128X64
    repeat i from 0 to (len <# SSD1306_LCDCHARMAX) - 1
      write16x32Char(byte[str][i], row, i) 
     
PUB Write16x32Char(ch, row, col) | h, i, j, k, q, r, s, mask, cbase, cset, bset

  if row == 0 or row == 1 and (col => 0 and col < 8)
    ''Write a 16x32 character to the screen at position 0-7 (left to right)
    cbase := $8000 + ((ch & $FE) << 6)  ' Compute the base of the interleaved character 
      
    repeat j from 0 to 31       ' For all the rows in the font
      bset := |< (j // 8)       ' For setting bits in the OLED buffer.
                                ' The mask is always a byte and has to wrap
      if ch & $01
        mask := $00000002       ' For the extraction of the bits interleaved in the font
      else
        mask := $00000001       ' For the extraction of the bits interleaved in the font
      r := long[cbase][j]       ' Row is the font data with which to perform bit extraction
      s := 0                    ' Just for printing the font  to the serial terminal (DEBUG)
      h := @buffer + row * 512  ' Get the base address of the OLED buffer
      h += ((j >> 3) * 128) + (col * 16)  ' Compute the offset to the column of data and add to the base...
                                ' ...then add the offset to the character position
      repeat k from 0 to 15     ' For all 16 bits we need from the interlaced font...
        if r & mask             ' If the bit is set...
          byte[h][k] |= bset    ' Set the column bit
        else
          byte[h][k] &= !bset   ' Clear the column bit
        mask := mask << 2       ' The mask shifts two places because the fonts are interlaced
    if autoUpdate
      updateDisplay             ' Update the display
     
{PUB Write4x16String(str, len, row, col) | i, j
  ''Write a string of 5x7 characters to the display @ row and column
  
  repeat j from 0 to len - 1
    Write5x7Char(byte[str][j], row, col)  
    col++
    if(col > 15)
      col := 0
      row++
  if autoUpdate
    updateDisplay               ' Update the display

PUB Write5x7Char(ch, row, col) | i    
  ''Write a 5x7 character to the display @ row and column
  
  col &= $F
  if displayType == TYPE_128X32
    row &= $3
    repeat i from 0 to 7
      buffer[row * 128 + col * 8 + i] := byte[@Font5x7 + 8 * ch + i]
  else
    row &= $7
    repeat i from 0 to 7
      buffer[row * 128 + col * 8 + i] := byte[@Font5x7 + 8 * ch + i]
  if autoUpdate
    UpdateDisplay               ' Update the display
            }
PUB AutoUpdateOn                'With autoUpdate On the display is updated for you

  autoUpdate := TRUE

PUB AutoUpdateOff               'With autoUpdate Off the system is faster.
                                'Update the display when you want

  autoUpdate := FALSE

PUB GetDisplayHeight            'For things that need it

  return displayHeight

PUB GetDisplayWidth             'For things that need it

  return displayWidth

PUB GetDisplayType              'For things that need it

  return displayType

{PUB High(pin)
  ''Make a pin an output and drives it high
  
  dira[pin] := 1
  outa[pin] := 1
         
PUB Low(pin)
  ''Make a pin an output and drives it low
  
  dira[pin] := 1
  outa[pin] := 0
   }
PUB SpinHigh595(chan)
  
  {if chan == Header#RESET_DRV8711_X_595
    dira[2] := 1
    outa[2] := 1
  elseif chan == Header#SLEEP_DRV8711_X_595
    dira[0] := 1
    outa[0] := 1  }
  shiftRegisterOutputSpin |= 1 << chan
  SetCommand(Header#SPIN_595_SPI)
         
PUB SpinLow595(chan)

  {if chan == Header#RESET_DRV8711_X_595
    dira[2] := 1
    outa[2] := 0
  elseif chan == Header#SLEEP_DRV8711_X_595
    dira[0] := 1
    outa[0] := 0  }
  shiftRegisterOutputSpin &= !(1 << chan)
  SetCommand(Header#SPIN_595_SPI)
  
PUB Ssd1306Command(localCommand) 'Send a byte as a command to the display
  ''Write SPI command to the OLED
  
  SpinLow595(Header#DC_OLED_595)
  'Low(dataCommandPin)
  ShiftOut(localCommand)   

PUB Ssd1306Data(localData)   'Send a byte as data to the display
  ''Write SPI data to the OLED
  
  SpinHigh595(Header#DC_OLED_595)
  'High(dataCommandPin)
  ShiftOut(localData)   

PUB GetBuffer                   'Get the address of the buffer for the display

  result := @buffer

'PUB GetSplash                   'Get the address of the Adafruit Splash Screen

  'result := @splash

PUB GetObjectName

  result := @objectName
  
PUB SetAdcChannels(firstChan, numberOfChans)

  adcChannelsInUse := 1 #> numberOfChans <# 8
  firstAdcChannelInUse := 0 #> firstChan <# (8 - adcChannelsInUse) 

  SetCommand(Header#SET_ADC_CHANNELS_SPI)
    
PUB ReadAdc

  SetCommand(Header#ADC_SPI) 
  
PUB GetAdcPtr

  result := @adcChannelsInUse

PUB GetRefreshCount

  result := refreshCount
    
PUB GetPasmArea

  result := @entry 

PUB ReadDrv8711(axis, register) 

  axis := 1 << (axis * Header#CHANNELS_PER_CS)
  mailbox := @result
  SetCommand(Header#DRV8711_READ_SPI) ' PASM code should not retrun to normal loop until CS low again
  
  {Com.Str(0, string(11, 13, "ReadDrv8711("))
  Pst.Dec(axis)
  Com.Str(0, string(", "))
  Pst.Dec(register)
  Com.Str(0, string(") @result = "))
  Pst.Dec(@result)
  Com.Str(0, string(", resultPtr = "))
  Pst.Dec(long[debugAddress][0])

  Com.Str(0, string(11, 13, "@axis = "))
  Pst.Dec(@axis)
  Com.Str(0, string(", bufferAddress = "))
  Pst.Dec(long[debugAddress][1])
  Com.Str(0, string(11, 13, "axis = "))
  Pst.Dec(axis)
  Com.Str(0, string(" = "))
  ReadableBin(axis, 32)
  Com.Str(0, string(", shiftOutputChange = "))
  Pst.Dec(long[debugAddress][2])
  Com.Str(0, string(" = "))
  ReadableBin(long[debugAddress][2], 32)
  Com.Str(0, string(11, 13, "@register = "))
  Pst.Dec(@register)
  Com.Str(0, string(", from PASM = "))
  Pst.Dec(long[debugAddress][3])                 
  Com.Str(0, string(", outputData = "))
  Pst.Dec(long[debugAddress][4])                 
  Com.Str(0, string(" = "))
  ReadableBin(long[debugAddress][4], 32)                         
  Com.Str(0, string(11, 13, "outputData (before spiBits) = "))
  Pst.Dec(long[debugAddress][5])                 
  Com.Str(0, string(" = "))
  ReadableBin(long[debugAddress][5], 32)
  Com.Str(0, string(11, 13, "outputData (start spiBits) = "))
  Pst.Dec(long[debugAddress][6])                 
  Com.Str(0, string(" = "))
  ReadableBin(long[debugAddress][6], 32) }
  
PUB WriteDrv8711(axis, register, value) 

  axis := 1 << (axis * Header#CHANNELS_PER_CS)
  mailbox := @result
  SetCommand(Header#DRV8711_WRITE_SPI) ' PASM code should not retrun to normal loop until CS low again

DAT                     org
'------------------------------------------------------------------------------
entry
commandCog              or      dira, latch165Mask
dataOutToShred          or      outa, latch165Mask  ' This long gets reused as a temp variable
shiftRegisterInput      or      dira, latch595Mask
shiftOutputChange       or      dira, clockMask
dataValue               or      dira, mosiMask
dataOut                 or      dira, shiftMosiMask
byteCount               or      dira, shiftClockMask                        
                        
'bitCount                or      dira, p4
                                     
bitsFromPasmCog         mov     bitsFromPasmCog, csOledChanMask
bitsFromSpinCog         or      bitsFromPasmCog, csAdcChanMask
                        'or      dira, p4Cs
                        
                        wrlong  con111, debugAddressF                        
adcInUseCog             jmp     #setAdc
' Pass through only on start up.                        
'------------------------------------------------------------------------------
loopSpi                 wrlong  zero, par  ' used to indicate command complete
                        
smallLoop               call    #maintenanceRounds
                        rdlong  commandCog, par 'wz 
              'if_z      jmp     #smallLoop
                        add     commandCog, #jumpTable
                       
                        jmp     commandCog
jumpTable               jmp     #smallLoop
                        
                        jmp     #shiftOne
                        jmp     #writeBuff_
                        jmp     #spin595
                        jmp     #setAdc
                        jmp     #readAdcPasm
                        jmp     #writeDrv8711Pasm
                        jmp     #readDrv8711Pasm
                      
{ #0, IDLE_SPI, OLED_WRITE_ONE_SPI, OLED_WRITE_BUFFER_SPI
      SPIN_595_SPI, SET_ADC_CHANNELS_SPI, ADC_SPI
      DRV8711_WRITE_SPI, DRV8711_READ_SPI}                                  
'------------------------------------------------------------------------------
maintenanceRounds       call    #output595
                        call    #input165
maintenanceRounds_ret   ret     
'------------------------------------------------------------------------------
output595               mov     dataValue, bitsFromPasmCog
                        or      dataValue, bitsFromSpinCog
                        wrlong  dataValue, shiftRegisterOutputCog
                        mov     bitCount, bits595
                        ror     dataValue, bits595
loop595                 shl     dataValue, #1   wc
                        muxc    outa, shiftMosiMask
                        or      outa, shiftClockMask                        
                        andn    outa, shiftClockMask
                        djnz    bitCount, #loop595
                        or      outa, latch595Mask
                        andn    outa, latch595Mask
output595_ret           ret
'------------------------------------------------------------------------------
input165                mov     dataValue, zero
                        mov     bitCount, bits165
                        andn    outa, latch165Mask
                        or      outa, latch165Mask
                        
loop165                 or      outa, shiftClockMask                       
                        test    shiftMisoMask, ina wc
                        rcl     dataValue, #1
                        andn    outa, shiftClockMask
                      
                        djnz    bitCount, #loop165
                        wrlong  dataValue, shiftRegisterInputCog
input165_ret            ret
'------------------------------------------------------------------------------
high595                 or      bitsFromPasmCog, shiftOutputChange
                        call    #output595
high595_ret             ret           
'------------------------------------------------------------------------------
low595                  andn    bitsFromPasmCog, shiftOutputChange
                        call    #output595
low595_ret              ret           

'------------------------------------------------------------------------------
spin595                 rdlong  bitsFromSpinCog, bitsFromSpinPtr
                        jmp     #loopSpi       
'------------------------------------------------------------------------------
setAdc                  rdbyte  adcRequest, firstAdcPtr
                        mov     activeAdcPtr, adcRequest
                        shl     activeAdcPtr, #2        ' multiply by four to adjust long pointer 
                        rdbyte  adcInUseCog, adcInUsePtr
                        or      adcRequest, #Header#ADC_BASE_REQUEST ' request first channel
                        add     activeAdcPtr, adcPtr    ' adjust active pointer
                        jmp     #loopSpi
'------------------------------------------------------------------------------
DAT readAdcPasm         mov     dataOut, adcRequest
                        wrlong  adcRequest, debugAddress0
                        wrlong  activeAdcPtr, debugAddress1
                        wrlong  con111, debugAddress6
                        mov     byteCount, adcInUseCog '8
                        '*** drbug in use
                        wrlong  adcInUseCog, debugAddress8
                        mov     debugPtrCog, activeAdcPtr
                        add     debugPtrCog, #32
                        mov     bufferAddress, activeAdcPtr
                        andn    outa, clockMask
                        'andn    outa, p2
                        
adcLoop                 mov     dataOutToShred, dataOut
                        mov     shiftOutputChange, csAdcChanMask
                        call    #low595
                        'andn    outa, p0
                        'andn    dira, mosiMask 
                        'or      dira, mosiMask ' shared data an output
                        andn    outa, dataAdcMask
                        or      dira, dataAdcMask 
                        mov     bitCount, #5
                        ror     dataOutToShred, bitCount
                        wrlong  dataOutToShred, debugAddress7
                        wrlong  con222, debugAddress6
                        
                        
outputBitsAdc           shl     dataOutToShred, #1 wc                         
                        'muxc    outa, mosiMask
                        mov     wait, cnt
                        add     wait, bitDelay
                        
                        muxc    outa, dataAdcMask
                        or      outa, clockMask
                        'or      outa, p2
                        waitcnt wait, bitDelay                     
                        andn    outa, clockMask
                        'andn    outa, p2
                        waitcnt wait, bitDelay                      
                        
                        djnz    bitCount, #outputBitsAdc
                        wrlong  con333, debugAddress6
                        
                        'andn    outa, mosiMask
                        'andn    dira, mosiMask ' shared data an input
                        andn    outa, dataAdcMask
                        andn    dira, dataAdcMask
                        mov     bitCount, #13
                        mov     dataValue, zero
                        mov     wait, cnt
                        add     wait, bitDelay
                        
                        'mov     dataValue1, zero
                        
inputBitsAdc            or      outa, clockMask                        
                        'or      outa, p2
                        waitcnt wait, bitDelay                     
                        andn    outa, clockMask
                        'andn    outa, p2
                        waitcnt wait, bitDelay                     
                        'test    mosiMask, ina wc
                        'rcl     dataValue, #1
                        test    dataAdcMask, ina wc
                        rcl     dataValue, #1
                        djnz    bitCount, #inputBitsAdc
                        
                        wrlong  dataValue, bufferAddress
                        call    #high595
                        'or      outa, p0
                        'wrlong  dataValue, debugAddress2
                        'wrlong  dataValue1, debugPtrCog
                        'add     debugPtrCog, #4
                        add     bufferAddress, #4
                        add     dataOut, #1
                        wrlong  bufferAddress, debugAddress3
                        wrlong  dataOut, debugAddress4
                        wrlong  byteCount, debugAddress5
                        wrlong  con888, debugAddress6
                        djnz    byteCount, #adcLoop
                        wrlong  con999, debugAddress6
                        
                        'or      dira, mosiMask ' leave data an output
                        'andn    outa, mosiMask
                        or      dira, dataAdcMask
                        andn    outa, dataAdcMask
                        jmp     #loopSpi
'------------------------------------------------------------------------------
'Single OLED SPI shift routine
shiftOne                mov     shiftOutputChange, csOledChanMask
                        call    #low595
                        'andn    outa, csMask
                        rdlong  dataValue, mailboxAddr
                        ror     dataValue, #8
                        mov     bitCount, #8
                        
:msbShift               shl     dataValue, #1   wc
                        muxc    outa, mosiMask
                        andn    outa, clockMask
                        or      outa, clockMask                        
                        djnz    bitCount, #:msbShift
                        'or      outa, csMask
                        call    #high595
                        
                        or      outa, mosiMask
                        jmp     #loopSpi 'preLoop                        
            
'------------------------------------------------------------------------------
writeBuff_              rdlong  bufferAddress, mailboxAddr                        
                        mov     byteCount, bufferSize

readByte                mov     shiftOutputChange, csOledChanMask
                        call    #low595
                        'andn    outa, csMask
                        rdbyte  dataValue, bufferAddress
                        ror     dataValue, #8
                        mov     bitCount, #8 
                        add     bufferAddress, #1
:msbShift               shl     dataValue, #1   wc
                        muxc    outa, mosiMask
                        andn    outa, clockMask
                        or      outa, clockMask                        
                        djnz    bitCount, #:msbShift
                        'or      outa, csMask
                        call    #high595
                        
                        djnz    byteCount, #readByte
                        or      outa, mosiMask
                        add     refreshCountCog, #1
                        wrlong  refreshCountCog, refreshCountPtr
                        jmp     #loopSpi 'preLoop                                                         
            
'------------------------------------------------------------------------------
readDrv8711Pasm         rdlong  resultPtr, mailboxAddr                        
                        mov     bufferAddress, resultPtr
                        wrlong  con222, debugAddressF
                        wrlong  resultPtr, debugAddress0
                        add     bufferAddress, #4
                        rdlong  shiftOutputChange, bufferAddress ' CS mask              
                        wrlong  bufferAddress, debugAddress1
                        wrlong  shiftOutputChange, debugAddress2
                        add     bufferAddress, #4
                        mov     cogDelay, bitDelay
                        rdlong  outputData, bufferAddress ' register to read              
                        wrlong  bufferAddress, debugAddress3
                        wrlong  outputData, debugAddress4
                        call    #high595
                        'or      outa, p4Cs
                        
                        and     outputData, #7
                        or      outputData, #8
                        shl     outputData, #12
                        mov     bitCount, #16 
                        
                        wrlong  outputData, debugAddress5
                        
                        call    #spiBits
                     
                        and     inputData, twelveBits
                        wrlong  inputData, resultPtr                        
                        'andn    outa, p4Cs
                        call    #low595
                        wrlong  con999, debugAddressF
                        jmp     #loopSpi

                       
'------------------------------------------------------------------------------
writeDrv8711Pasm        rdlong  resultPtr, mailboxAddr                        
                        mov     bufferAddress, resultPtr
                        add     bufferAddress, #4
                        rdlong  shiftOutputChange, bufferAddress ' CS mask               
                        add     bufferAddress, #4
                        rdlong  outputData, bufferAddress  ' register to write           
                        add     bufferAddress, #4
                        mov     cogDelay, bitDelay
                        rdlong  dataValue, bufferAddress  ' data to write
                        shl     outputData, #12          ' shift regiter to make remove for data
                        or      outputData, dataValue    ' combine regiter and data     
                        call    #high595
                        'or      outa, p4Cs
                        mov     bitCount, #16 
                        
                        call    #spiBits
                        
                        'andn    outa, p4Cs
                        call    #low595
                        jmp     #loopSpi
                              
'------------------------------------------------------------------------------
'' The variables "outputData", "bitCount" and "bitDelay" should be set
'' prior to calling spiBits

spiBits                 ror     outputData, bitCount
                        wrlong  outputData, debugAddress6
                        wrlong  con777, debugAddressF
                        mov     wait, cnt
                        add     wait, cogDelay
:loop
                        rcl     outputData, #1  wc
                        waitcnt wait, cogDelay
                        andn    outa, clockMask
                        muxc    outa, mosiMask
                        waitcnt wait, cogDelay
                        or      outa, clockMask
                        test    misoMask, ina  wc
                        rcl     inputData, #1
                        djnz    bitCount, #:loop
spiBits_ret             ret
'------------------------------------------------------------------------------

zero                    long 0                  '' Constant
bufferSize              long OLED_BUFFER_SIZE
                                              
'csMask                  long %10000                  '' Used for Chip Select mask
mailboxAddr             long 0                    
bufferAddress           long 0                  '' Used for buffer address

DAT ' PASM Variables

negativeOne             long -1
bits595                 long Header#BITS_595
bits165                 long Header#BITS_165
twelveBits              long $F_FF
bitDelay                long 80
con111                  long 111
con222                  long 222
con333                  long 333
con444                  long 444
con555                  long 555
con666                  long 666
con777                  long 777
con888                  long 888
con999                  long 999
'p0                      long 1
'p1                      long %10
'p2                      long %100
{p3                      long %1000
p4                      long %10000 }

'oledBufferSize          long 1024               '' Buffer size
                                              
clockMask               long 1 << Header#SPI_CLOCK '' Used for ClockPin mask
mosiMask                long 1 << Header#SPI_MOSI
misoMask                long 1 << Header#SPI_MISO
shiftClockMask          long 1 << Header#SHIFT_CLOCK '' Used for ClockPin mask
shiftMosiMask           long 1 << Header#SHIFT_MOSI
shiftMisoMask           long 1 << Header#SHIFT_MISO
latch595Mask            long 1 << Header#LATCH_595_PIN
latch165Mask            long 1 << Header#LATCH_165_PIN           
dataAdcMask             long 1 << Header#ADC_DATA        
'dataAdcMask             long 1 << Header#SPI_MOSI      
csChanMaskX             long 1 << Header#CS_DRV8711_X_595 ' active high
csChanMaskY             long 1 << Header#CS_DRV8711_Y_595 ' active high
csChanMaskZ             long 1 << Header#CS_DRV8711_Z_595 ' active high
resetChanMaskX          long 1 << Header#RESET_DRV8711_X_595
resetChanMaskY          long 1 << Header#RESET_DRV8711_Y_595
resetChanMaskZ          long 1 << Header#RESET_DRV8711_Z_595
sleepChanMaskX          long 1 << Header#SLEEP_DRV8711_X_595
sleepChanMaskY          long 1 << Header#SLEEP_DRV8711_Y_595
sleepChanMaskZ          long 1 << Header#SLEEP_DRV8711_Z_595
csOledChanMask          long 1 << Header#CS_OLED_595 ' active low
csAdcChanMask           long 1 << Header#CS_ADC_595  ' active low

'p4Cs                    long 1 << 4 
'p2Reset                 long 1 << 2
'p0Sleep                 long 1
        
shiftRegisterInputCog   long 0-0
shiftRegisterOutputCog  long 0-0
adcPtr                  long 0-0
bitsFromSpinPtr         long 0-0
adcInUsePtr             long 0-0
firstAdcPtr             long 0-0
refreshCountCog         long 0
refreshCountPtr         long 0-0
'oledBufferPtr           long 0-0
debugAddress0           long 0-0
debugAddress1           long 0-0
debugAddress2           long 0-0
debugAddress3           long 0-0
debugAddress4           long 0-0
debugAddress5           long 0-0
debugAddress6           long 0-0
debugAddress7           long 0-0
debugAddress8           long 0-0
debugAddress9           long 0-0
debugAddressA           long 0-0
debugAddressB           long 0-0
debugAddressC           long 0-0
debugAddressD           long 0-0
debugAddressE           long 0-0
debugAddressF           long 0-0

cogDelay                res 1
wait                    res 1
adcRequest              res 1
activeAdcPtr            res 1
resultPtr               res 1
inputData               res 1
outputData              res 1
{commandCog              res 1
bitsFromPasmCog         res 1 
bitsFromSpinCog         res 1}
temp                    res 1
readErrors              res 1
{shiftRegisterInput      res 1
shiftOutputChange       res 1

dataValue               res 1                 
dataOut                 res 1
byteCount               res 1 }                     
bitCount                res 1
debugPtrCog             res 1
'dataValue1              res 1
                        fit