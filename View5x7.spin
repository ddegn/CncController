DAT programName         byte "View5x7", 0
CON
{{      

}}
{
  ******* Private Notes *******
  Change name from "CncCommonMethods150416a" to "StoreBitmap150416a."
  16a Successfully saved propBeanie bitmap.
  16b  splash
}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq
  MS_001   = CLK_FREQ / 1_000
  US_001   = CLK_FREQ / 1_000_000

  QUOTE = 34
  BELL = 7
  
OBJ

  Header : "HeaderCnc"
  Pst : "Parallax Serial TerminalDat"
  Format : "StrFmt"
  Sd[1]: "SdSmall" 
  'Spi : "StepperSpi"  
  Num : "Numbers"
   
VAR


  'long lastRefreshTime, refreshInterval
  long oledStack
  long sdErrorNumber, sdErrorString, sdTryCount
  long filePosition[Header#NUMBER_OF_AXES]
  long globalMultiplier
  long oledLabelPtr, oledDataPtr, oledDataQuantity ' keep together and in order
  long shiftRegisterOutput, shiftRegisterInput
  long adcData[8]
  long debugSpi[16]
  
  byte sdMountFlag[Header#NUMBER_OF_SD_INSTANCES]
  byte endFlag
  byte configData[Header#CONFIG_SIZE]
  byte sdFlag
  byte tstr[32]
  
DAT

designFileIndex         long -1             

machineState            byte Header#INIT_STATE
units                   byte Header#MILLIMETER_UNIT 
delimiter               byte 13, 10, ",", 9, 0
oledState               byte Header#DEMO_OLED

PUB Main | bitmapSize, fileName, bitmapPtr

  Pst.Start(115200)
  
  repeat
    result := Pst.RxCount
    Pst.str(string(11, 13, "Press any key to continue starting program."))
    waitcnt(clkfreq / 2 + cnt)
  until result
  Pst.RxFlush
  
  sdFlag := Header#INITIALIZING_SD
  
  Sd.fatEngineStart(Header#DOPIN, Header#ClkPIN, Header#DIPIN, Header#CSPIN, {
  } Header#WP_SD_PIN, Header#CD_SD_PIN, Header#RTC_PIN_1, Header#RTC_PIN_2, Header#RTC_PIN_3)
  
  
  Pst.str(string(11, 13, "SD Card Driver Started"))

  fileName := @bitmapFile          '' Change these two lines to match names of data
  bitmapPtr := @bitmap
  
  bitmapSize := @afterData - bitmapPtr
        
  {OpenOutputFileW(0, fileName)
  Sd.writeData(bitmapPtr, bitmapSize)
  Sd.closeFile  }
  result := CompareData(fileName, bitmapPtr, bitmapSize, 1)
  if result
    Pst.str(string(11, 13, "Error, data in file does not match data in RAM."))
    Pst.str(string(11, 13, "There were "))
    Pst.dec(result)
    Pst.str(string("differences found between the two data sets."))
  else
    Pst.str(string(11, 13, "Success, the data in the file matches the data in RAM."))   
  Pst.str(string(11, 13, "End of program."))
  repeat
      
PUB CompareData(fileName, localPtr, bitmapSize, displayFlag) | localByte, rowCount, byteCount

  rowCount := 0
  byteCount := 0
  
  Pst.Str(string(11, 13, "Comparing RAM with File."))

  Pst.Str(string(11, 13, "RAM address = $"))
  Pst.Hex(localPtr, 4)

  Pst.Str(string(11, 13, "File name = "))
  Pst.Str(fileName) 

  Pst.Str(string(11, 13, "Bytes to compare = $"))
  Pst.Hex(bitmapSize, 4)
  Pst.Str(string(11, 13))
   
  OpenFileToRead(0, fileName)
  repeat bitmapSize
  
    ifnot rowCount++ // 8
      if displayFlag

        Pst.Str(string(11, 13, "<$"))
        Pst.Hex(localPtr, 4)
        Pst.Str(string("&$"))
        Pst.Hex(byteCount, 4)
        Pst.Str(string(">"))

    localByte := Sd.readByte
    if displayFlag
      Pst.Str(string("|$"))
      Pst.Hex(byte[localPtr], 2)
    if byte[localPtr] == localByte
      if displayFlag
        Pst.Str(string("==$"))
    else
      if displayFlag
        Pst.Str(string(7, "<>$"))
      result++
    if displayFlag
      Pst.Hex(localByte, 2)  
    localPtr++
    byteCount++
    
  Pst.Str(string(11, 13, "The compare method found "))
  Pst.Dec(result)
  Pst.Str(string(" unmatched bytes."))

  if result
    Pst.Str(string(11, 13, BELL, " Failure!!! ", BELL))
  else
    Pst.Str(string(" Success!!! "))
  
PRI OpenFileToRead(sdInstance, basePtr)
    
  result := MountSd(sdInstance)
  if result == 1
    Pst.str(string(11, 13, "Error in program.  Problem mounting SD card."))
    waitcnt(clkfreq * 2 + cnt)
    result := Header#READ_FILE_ERROR_OTHER
    return
  elseif result
    Pst.str(string(11, 13, "MountSd returned = "))
    Pst.str(result)
    waitcnt(clkfreq * 2 + cnt)

  Pst.str(string(11, 13, "Looking for file ", 34))
  Pst.str(basePtr)
  Pst.char(34)
  sdErrorString := \Sd[sdInstance].openFile(basePtr, "R")
  if strcomp(sdErrorString, basePtr)
    Pst.str(string(11, 13, "File ", 34))
    Pst.str(basePtr)
    Pst.str(string(34, " found."))
    result := Header#READ_FILE_SUCCESS
  else
    Pst.str(string(11, 13, "File ", 34))
    Pst.str(basePtr)
    Pst.str(string(34, " not found."))
    Pst.str(string(11, 13, "sdErrorString = "))
    Pst.dec(sdErrorString)
    Pst.str(string(11, 13, "sdErrorString ", 34))
    Pst.str(sdErrorString)
    Pst.char(34)
    UnmountSd(sdInstance)
   
    result := Header#FILE_NOT_FOUND

PUB OpenOutputFileW(sdInstance, localPtr)

  ifnot sdMountFlag[sdInstance] 
    Pst.str(string(11, 13, "Calling MountSd."))
    MountSd(sdInstance)
    

  Pst.str(string(11, 13, "Attempting to create file ", 34))
  Pst.str(localPtr)
  Pst.char(34)

  repeat
    sdErrorString := \Sd[sdInstance].newFile(localPtr)
    sdErrorNumber :=  Sd[sdInstance].partitionError ' Returns zero if no error occurred.
       
    if(sdErrorNumber) ' Try to handle the "entry_already_exist" error.
      if(sdErrorNumber == Sd#Entry_Already_Exist)

        Sd[sdInstance].deleteEntry(localPtr)
        result := 0
      else
 
        Pst.str(string(11, 13, "Create File Errror = "))
        Pst.dec(sdErrorNumber)
        
        waitcnt(clkfreq * 2 + cnt)
        result := -1
    else
      'sdFlag := NEW_LOG_CREATED_SD
      'repeat until not lockset(debugLockID) 
      Pst.str(string(11, 13, "Creating file ", 34))
      Pst.str(localPtr)
      Pst.str(string(34, "."))     
      'waitcnt(clkfreq / 4 + cnt)  
      Sd[sdInstance].openFile(localPtr, "W")
      result := 1
  until result 

PUB MountSd(sdInstance)
'' Returns 1 is no SD card is found.

  Pst.str(string(11, 13, "MountSd Method"))
  if sdMountFlag[sdInstance]
    result := string("SD Card Already Mounted")
    return  
  sdErrorNumber := Sd[sdInstance].mountPartition(0)
  Pst.str(string(11, 13, "After mount attempt.")) 
  if sdErrorNumber
    sdFlag := Header#NOT_FOUND_SD
    result := 1
    Pst.str(string(11, 13, "Error Mounting SD Card #"))
    Pst.dec(sdErrorNumber)
    
    if sdErrorNumber == -1
      Pst.str(string(11, 13, "The SD card was not properly unmounted after its last use."))
      Pst.str(string(11, 13, "Continuing with program."))
      sdFlag := Header#INITIALIZING_SD
      result := 0

  if result <> 1
    sdMountFlag[sdInstance] := 1

PUB UnmountSd(sdInstance)

  if sdMountFlag[sdInstance] == 0
    Pst.str(string(11, 13, "Partition not currently mounted."))
    return
  
  Pst.str(string(11, 13, "Unmounting Partition"))
  sdErrorNumber := Sd[sdInstance].unmountPartition
  Pst.str(string(11, 13, "sdErrorNumber = "))
  Pst.dec(sdErrorNumber)
  'outa[_GreenLedPin]~~
  'outa[_RedLedPin]~
  sdMountFlag[sdInstance] := 0

PUB PauseForInput

  Pst.Str(string(11, 13, "Press any key to continue."))
  result := Pst.CharIn

PRI SafeTx(localCharacter)
'' Debug lock should be set prior to calling this method.

  if (localCharacter > 32 and localCharacter < 127)
    Pst.Char(localCharacter)    
  else
    Pst.Char(60)
    Pst.Char(36) 
    Pst.Hex(localCharacter, 2)
    Pst.Char(62)

PUB PressToPause

  result := Pst.RxCount
  if result
    Pst.str(string(11, 13, "Paused."))
    Pst.RxFlush
    PressToContinue
    
PUB PressToContinue
  
  Pst.str(string(11, 13, "Press to continue."))
  repeat
    result := Pst.RxCount
  until result
  Pst.RxFlush

PUB PressToContinueOrClose(closeCharacter)
'StoreBitmap150416a

  if closeCharacter <> -1
    Pst.str(string(11, 13, "Press ", QUOTE))
    Pst.Char(closeCharacter)
    Pst.str(string(QUOTE, " to close or any other key to continue."))
    result := Pst.CharIn
  else
    result := -1  
  if result == closeCharacter
    Pst.str(string(11, 13, "Closing all files."))
    'Pst.str(string(11, 13, "End of program.")) 
   
    Sd[0].closeFile
   
    UnmountSd(result)
    UnmountSd(Header#DESIGN_AXIS)
    PressToContinue
  else
    result := 0

DAT

bitmapFile      byte "FONT_5X7.DAT", 0

bitmap        byte %11111111   '$00
              byte %11111111   '$00
              byte %11111111   '$00
              byte %11111111   '$00
              byte %11111111   '$00
              byte %00000000   '$00
              byte %00000000   '$00
              byte %00000000   '$00

              byte %11111111   '$01
              byte %11111100   '$01
              byte %11111000   '$01
              byte %11100000   '$01
              byte %11000000   '$01
              byte %10000000   '$01
              byte %00000000   '$01
              byte %00000000   '$01
              
              byte %11111111   '$02
              byte %10100101   '$02
              byte %10011001   '$02
              byte %10100101   '$02
              byte %11111111   '$02
              byte %00000000   '$02
              byte %00000000   '$02
              byte %00000000   '$02
              
              byte %00000001   '$03
              byte %00000111   '$03
              byte %00001111   '$03
              byte %00111111   '$03
              byte %11111111   '$03
              byte %00000000   '$03
              byte %00000000   '$03
              byte %00000000   '$03
              
              byte %10000001   '$04
              byte %01000010   '$04
              byte %00100100   '$04
              byte %00011000   '$04
              byte %00011000   '$04
              byte %00000000   '$04
              byte %00000000   '$04
              byte %00000000   '$04
              
              byte %00011000   '$05
              byte %00011000   '$05
              byte %00011000   '$05
              byte %00011000   '$05
              byte %00011000   '$05
              byte %00000000   '$05
              byte %00000000   '$05
              byte %00000000   '$05
              
              byte %00000000   '$06
              byte %00000000   '$06
              byte %11111111   '$06
              byte %00000000   '$06
              byte %00000000   '$06
              byte %00000000   '$06
              byte %00000000   '$06
              byte %00000000   '$06
              
              byte %11111111   '$07
              byte %10000001   '$07
              byte %10000001   '$07
              byte %10000001   '$07
              byte %11111111   '$07
              byte %00000000   '$07
              byte %00000000   '$07
              byte %00000000   '$07
              
              byte %10101010   '$08
              byte %01010101   '$08
              byte %10101010   '$08
              byte %01010101   '$08
              byte %10101010   '$08
              byte %00000000   '$08
              byte %00000000   '$08
              byte %00000000   '$08
              
              byte %10101010   '$09
              byte %01010101   '$09
              byte %10101010   '$09
              byte %01010101   '$09
              byte %10101010   '$09
              byte %00000000   '$09
              byte %00000000   '$09
              byte %00000000   '$09
              
              byte %10101010   '$0A
              byte %01010101   '$0A
              byte %10101010   '$0A
              byte %01010101   '$0A
              byte %10101010   '$0A
              byte %00000000   '$0A
              byte %00000000   '$0A
              byte %00000000   '$0A
              
              byte %10101010   '$0B
              byte %01010101   '$0B
              byte %10101010   '$0B
              byte %01010101   '$0B
              byte %10101010   '$0B
              byte %00000000   '$0B
              byte %00000000   '$0B
              byte %00000000   '$0B
              
              byte %10101010   '$0C
              byte %01010101   '$0C
              byte %10101010   '$0C
              byte %01010101   '$0C
              byte %10101010   '$0C
              byte %00000000   '$0C
              byte %00000000   '$0C
              byte %00000000   '$0C
              
              byte %10101010   '$0D
              byte %01010101   '$0D
              byte %10101010   '$0D
              byte %01010101   '$0D
              byte %10101010   '$0D
              byte %00000000   '$0D
              byte %00000000   '$0D
              byte %00000000   '$0D
              
              byte %10101010   '$0E
              byte %01010101   '$0E
              byte %10101010   '$0E
              byte %01010101   '$0E
              byte %10101010   '$0E
              byte %00000000   '$0E
              byte %00000000   '$0E
              byte %00000000   '$0E
              
              byte %10101010   '$0F
              byte %01010101   '$0F
              byte %10101010   '$0F
              byte %01010101   '$0F
              byte %10101010   '$0F
              byte %00000000   '$0F
              byte %00000000   '$0F
              byte %00000000   '$0F
              
              byte %11111111   '$10
              byte %11111111   '$10
              byte %11111111   '$10
              byte %11111111   '$10
              byte %11111111   '$10
              byte %00000000   '$10
              byte %00000000   '$10
              byte %00000000   '$10
              
              byte %01111110   '$11
              byte %10111101   '$11
              byte %11011011   '$11
              byte %11100111   '$11
              byte %11100111   '$11
              byte %00000000   '$11
              byte %00000000   '$11
              byte %00000000   '$11
              
              byte %11000011   '$12
              byte %11000011   '$12
              byte %11000011   '$12
              byte %11000011   '$12
              byte %11000011   '$12
              byte %00000000   '$12
              byte %00000000   '$12
              byte %00000000   '$12
              
              byte %11111111   '$13
              byte %00000000   '$13
              byte %00000000   '$13
              byte %00000000   '$13
              byte %11111111   '$13
              byte %00000000   '$13
              byte %00000000   '$13
              byte %00000000   '$13
              
              byte %11111111   '$14
              byte %11100111   '$14
              byte %10011001   '$14
              byte %11100111   '$14
              byte %11111111   '$14
              byte %00000000   '$14
              byte %00000000   '$14
              byte %00000000   '$14
              
              byte %11111111   '$15
              byte %11111111   '$15
              byte %10000001   '$15
              byte %10000001   '$15
              byte %11111111   '$15
              byte %00000000   '$15
              byte %00000000   '$15
              byte %00000000   '$15
              
              byte %11111111   '$16
              byte %10000001   '$16
              byte %10000001   '$16
              byte %11111111   '$16
              byte %11111111   '$16
              byte %00000000   '$16
              byte %00000000   '$16
              byte %00000000   '$16
              
              byte %11111111   '$17
              byte %10000001   '$17
              byte %10000001   '$17
              byte %10000001   '$17
              byte %11111111   '$17
              byte %00000000   '$17
              byte %00000000   '$17
              byte %00000000   '$17
              
              byte %11111111   '$18
              byte %10000001   '$18
              byte %10000001   '$18
              byte %10000001   '$18
              byte %11111111   '$18
              byte %00000000   '$18
              byte %00000000   '$18
              byte %00000000   '$18
              
              byte %11111111   '$19
              byte %10000001   '$19
              byte %10000001   '$19
              byte %10000001   '$19
              byte %11111111   '$19
              byte %00000000   '$19
              byte %00000000   '$19
              byte %00000000   '$19
              
              byte %11111111   '$1A
              byte %10000001   '$1A
              byte %10000001   '$1A
              byte %10000001   '$1A
              byte %11111111   '$1A
              byte %00000000   '$1A
              byte %00000000   '$1A
              byte %00000000   '$1A
              
              byte %11111111   '$1B
              byte %10000001   '$1B
              byte %10000001   '$1B
              byte %10000001   '$1B
              byte %11111111   '$1B
              byte %00000000   '$1B
              byte %00000000   '$1B
              byte %00000000   '$1B
              
              byte %11111111   '$1C
              byte %10000001   '$1C
              byte %10000001   '$1C
              byte %10000001   '$1C
              byte %11111111   '$1C
              byte %00000000   '$1C
              byte %00000000   '$1C
              byte %00000000   '$1C
              
              byte %11111111   '$1D
              byte %10000001   '$1D
              byte %10000001   '$1D
              byte %10000001   '$1D
              byte %11111111   '$1D
              byte %00000000   '$1D
              byte %00000000   '$1D
              byte %00000000   '$1D
              
              byte %11111111   '$1E
              byte %10000001   '$1E
              byte %10000001   '$1E
              byte %10000001   '$1E
              byte %11111111   '$1E
              byte %00000000   '$1E
              byte %00000000   '$1E
              byte %00000000   '$1E
              
              byte %11111111   '$1F
              byte %10000001   '$1F
              byte %10000001   '$1F
              byte %10000001   '$1F
              byte %11111111   '$1F
              byte %00000000   '$1F
              byte %00000000   '$1F
              byte %00000000   '$1F
              
              byte %00000000   '$20
              byte %00000000   '$20
              byte %00000000   '$20
              byte %00000000   '$20
              byte %00000000   '$20
              byte %00000000   '$20
              byte %00000000   '$20
              byte %00000000   '$20
              
              byte %01011111   '$21
              byte %00000000   '$21
              byte %00000000   '$21
              byte %00000000   '$21
              byte %00000000   '$21
              byte %00000000   '$21
              byte %00000000   '$21
              byte %00000000   '$21
              
              byte %00000011   '$22
              byte %00000101   '$22
              byte %00000000   '$22
              byte %00000011   '$22
              byte %00000101   '$22
              byte %00000000   '$22
              byte %00000000   '$22
              byte %00000000   '$22
              
              byte %00010100   '$23
              byte %00111110   '$23
              byte %00010100   '$23
              byte %00111110   '$23
              byte %00010100   '$23
              byte %00000000   '$23
              byte %00000000   '$23
              byte %00000000   '$23
              
              byte %00100100   '$24
              byte %00101010   '$24
              byte %01111111   '$24
              byte %00101010   '$24
              byte %00010010   '$24
              byte %00000000   '$24
              byte %00000000   '$24
              byte %00000000   '$24
              
              byte %01100011   '$25
              byte %00010000   '$25
              byte %00001000   '$25
              byte %00000100   '$25
              byte %01100011   '$25
              byte %00000000   '$25
              byte %00000000   '$25
              byte %00000000   '$25
              
              byte %00110110   '$26
              byte %01001001   '$26
              byte %01010110   '$26
              byte %00100000   '$26
              byte %01010000   '$26
              byte %00000000   '$26
              byte %00000000   '$26
              byte %00000000   '$26
              
              byte %00000000   '$27
              byte %00000000   '$27
              byte %00000101   '$27
              byte %00000011   '$27
              byte %00000000   '$27
              byte %00000000   '$27
              byte %00000000   '$27
              byte %00000000   '$27
              
              byte %00000000   '$28
              byte %00000000   '$28
              byte %00011100   '$28
              byte %00100010   '$28
              byte %01000001   '$28
              byte %00000000   '$28
              byte %00000000   '$28
              byte %00000000   '$28
              
              byte %01000001   '$29
              byte %00100010   '$29
              byte %00011100   '$29
              byte %00000000   '$29
              byte %00000000   '$29
              byte %00000000   '$29
              byte %00000000   '$29
              byte %00000000   '$29
              
              byte %00100100   '$2A
              byte %00011000   '$2A
              byte %01111110   '$2A
              byte %00011000   '$2A
              byte %00100100   '$2A
              byte %00000000   '$2A
              byte %00000000   '$2A
              byte %00000000   '$2A
              
              byte %00001000   '$2B
              byte %00001000   '$2B
              byte %00111110   '$2B
              byte %00001000   '$2B
              byte %00001000   '$2B
              byte %00000000   '$2B
              byte %00000000   '$2B
              byte %00000000   '$2B
              
              byte %10100000   '$2C
              byte %01100000   '$2C
              byte %00000000   '$2C
              byte %00000000   '$2C
              byte %00000000   '$2C
              byte %00000000   '$2C
              byte %00000000   '$2C
              byte %00000000   '$2C
              
              byte %00001000   '$2D
              byte %00001000   '$2D
              byte %00001000   '$2D
              byte %00001000   '$2D
              byte %00001000   '$2D
              byte %00000000   '$2D
              byte %00000000   '$2D
              byte %00000000   '$2D
              
              byte %01100000   '$2E
              byte %01100000   '$2E
              byte %00000000   '$2E
              byte %00000000   '$2E
              byte %00000000   '$2E
              byte %00000000   '$2E
              byte %00000000   '$2E
              byte %00000000   '$2E
              
              byte %01100000   '$2F
              byte %00010000   '$2F
              byte %00001000   '$2F
              byte %00000100   '$2F
              byte %00000011   '$2F
              byte %00000000   '$2F
              byte %00000000   '$2F
              byte %00000000   '$2F
              
              byte %00111110   '$30
              byte %01010001   '$30
              byte %01001001   '$30
              byte %01000101   '$30
              byte %00111110   '$30
              byte %00000000   '$30
              byte %00000000   '$30
              byte %00000000   '$30
              
              byte %00000000   '$31
              byte %01000010   '$31
              byte %01111111   '$31
              byte %01000000   '$31
              byte %00000000   '$31
              byte %00000000   '$31
              byte %00000000   '$31
              byte %00000000   '$31
              
              byte %01100010   '$32
              byte %01010001   '$32
              byte %01010001   '$32
              byte %01001001   '$32
              byte %01000110   '$32
              byte %00000000   '$32
              byte %00000000   '$32
              byte %00000000   '$32
              
              byte %00100010   '$33
              byte %01001001   '$33
              byte %01001001   '$33
              byte %01001001   '$33
              byte %00110110   '$33
              byte %00000000   '$33
              byte %00000000   '$33
              byte %00000000   '$33
              
              byte %00011000   '$34
              byte %00010100   '$34
              byte %00010010   '$34
              byte %01111111   '$34
              byte %00010000   '$34
              byte %00000000   '$34
              byte %00000000   '$34
              byte %00000000   '$34
              
              byte %00100111   '$35
              byte %01000101   '$35
              byte %01000101   '$35
              byte %01000101   '$35
              byte %00111001   '$35
              byte %00000000   '$35
              byte %00000000   '$35
              byte %00000000   '$35
              
              byte %00111100   '$36
              byte %01001010   '$36
              byte %01001001   '$36
              byte %01001001   '$36
              byte %00110000   '$36
              byte %00000000   '$36
              byte %00000000   '$36
              byte %00000000   '$36
              
              byte %00000001   '$37
              byte %01110001   '$37
              byte %00001001   '$37
              byte %00000101   '$37
              byte %00000011   '$37
              byte %00000000   '$37
              byte %00000000   '$37
              byte %00000000   '$37
              
              byte %00110110   '$38
              byte %01001001   '$38
              byte %01001001   '$38
              byte %01001001   '$38
              byte %00110110   '$38
              byte %00000000   '$38
              byte %00000000   '$38
              byte %00000000   '$38
              
              byte %00000110   '$39
              byte %01001001   '$39
              byte %01001001   '$39
              byte %00101001   '$39
              byte %00011110   '$39
              byte %00000000   '$39
              byte %00000000   '$39
              byte %00000000   '$39
              
              byte %00110110   '$3A
              byte %00110110   '$3A
              byte %00000000   '$3A
              byte %00000000   '$3A
              byte %00000000   '$3A
              byte %00000000   '$3A
              byte %00000000   '$3A
              byte %00000000   '$3A
              
              byte %10110110   '$3B
              byte %01110110   '$3B
              byte %00000000   '$3B
              byte %00000000   '$3B
              byte %00000000   '$3B
              byte %00000000   '$3B
              byte %00000000   '$3B
              byte %00000000   '$3B
              
              byte %00000000   '$3C
              byte %00001000   '$3C
              byte %00010100   '$3C
              byte %00100010   '$3C
              byte %01000001   '$3C
              byte %00000000   '$3C
              byte %00000000   '$3C
              byte %00000000   '$3C
              
              byte %00010100   '$3D
              byte %00010100   '$3D
              byte %00010100   '$3D
              byte %00010100   '$3D
              byte %00010100   '$3D
              byte %00000000   '$3D
              byte %00000000   '$3D
              byte %00000000   '$3D
              
              byte %01000001   '$3E
              byte %00100010   '$3E
              byte %00010100   '$3E
              byte %00001000   '$3E
              byte %00000000   '$3E
              byte %00000000   '$3E
              byte %00000000   '$3E
              byte %00000000   '$3E
              
              byte %00000010   '$3F
              byte %00000001   '$3F
              byte %01010001   '$3F
              byte %00001001   '$3F
              byte %00000110   '$3F
              byte %00000000   '$3F
              byte %00000000   '$3F
              byte %00000000   '$3F
              
              byte %00111110   '$40
              byte %01000001   '$40
              byte %01011101   '$40
              byte %01010001   '$40
              byte %01001110   '$40
              byte %00000000   '$40
              byte %00000000   '$40
              byte %00000000   '$40
              
              byte %01111100   '$41
              byte %00010010   '$41
              byte %00010001   '$41
              byte %00010010   '$41
              byte %01111100   '$41
              byte %00000000   '$41
              byte %00000000   '$41
              byte %00000000   '$41
              
              byte %01111111   '$42
              byte %01001001   '$42
              byte %01001001   '$42
              byte %01001001   '$42
              byte %00110110   '$42
              byte %00000000   '$42
              byte %00000000   '$42
              byte %00000000   '$42
              
              byte %00011100   '$43
              byte %00100010   '$43
              byte %01000001   '$43
              byte %01000001   '$43
              byte %00100010   '$43
              byte %00000000   '$43
              byte %00000000   '$43
              byte %00000000   '$43
              
              byte %01111111   '$44
              byte %01000001   '$44
              byte %01000001   '$44
              byte %00100010   '$44
              byte %00011100   '$44
              byte %00000000   '$44
              byte %00000000   '$44
              byte %00000000   '$44
              
              byte %01111111   '$45
              byte %01001001   '$45
              byte %01001001   '$45
              byte %01001001   '$45
              byte %01000001   '$45
              byte %00000000   '$45
              byte %00000000   '$45
              byte %00000000   '$45
              
              byte %01111111   '$46
              byte %00001001   '$46
              byte %00001001   '$46
              byte %00001001   '$46
              byte %00000001   '$46
              byte %00000000   '$46
              byte %00000000   '$46
              byte %00000000   '$46
              
              byte %00111110   '$47
              byte %01000001   '$47
              byte %01000001   '$47
              byte %01010001   '$47
              byte %00110010   '$47
              byte %00000000   '$47
              byte %00000000   '$47
              byte %00000000   '$47
              
              byte %01111111   '$48
              byte %00001000   '$48
              byte %00001000   '$48
              byte %00001000   '$48
              byte %01111111   '$48
              byte %00000000   '$48
              byte %00000000   '$48
              byte %00000000   '$48
              
              byte %01000001   '$49
              byte %01000001   '$49
              byte %01111111   '$49
              byte %01000001   '$49
              byte %01000001   '$49
              byte %00000000   '$49
              byte %00000000   '$49
              byte %00000000   '$49
              
              byte %00100000   '$4A
              byte %01000000   '$4A
              byte %01000000   '$4A
              byte %01000000   '$4A
              byte %00111111   '$4A
              byte %00000000   '$4A
              byte %00000000   '$4A
              byte %00000000   '$4A
              
              byte %01111111   '$4B
              byte %00001000   '$4B
              byte %00010100   '$4B
              byte %00100010   '$4B
              byte %01000001   '$4B
              byte %00000000   '$4B
              byte %00000000   '$4B
              byte %00000000   '$4B
              
              byte %01111111   '$4C
              byte %01000000   '$4C
              byte %01000000   '$4C
              byte %01000000   '$4C
              byte %01000000   '$4C
              byte %00000000   '$4C
              byte %00000000   '$4C
              byte %00000000   '$4C
              
              byte %01111111   '$4D
              byte %00000010   '$4D
              byte %00001100   '$4D
              byte %00000010   '$4D
              byte %01111111   '$4D
              byte %00000000   '$4D
              byte %00000000   '$4D
              byte %00000000   '$4D
              
              byte %01111111   '$4E
              byte %00000100   '$4E
              byte %00001000   '$4E
              byte %00010000   '$4E
              byte %01111111   '$4E
              byte %00000000   '$4E
              byte %00000000   '$4E
              byte %00000000   '$4E
              
              byte %00111110   '$4F
              byte %01000001   '$4F
              byte %01000001   '$4F
              byte %01000001   '$4F
              byte %00111110   '$4F
              byte %00000000   '$4F
              byte %00000000   '$4F
              byte %00000000   '$4F
              
              byte %01111111   '$50
              byte %00001001   '$50
              byte %00001001   '$50
              byte %00001001   '$50
              byte %00000110   '$50
              byte %00000000   '$50
              byte %00000000   '$50
              byte %00000000   '$50
              
              byte %00111110   '$51
              byte %01000001   '$51
              byte %01010001   '$51
              byte %00100001   '$51
              byte %01011110   '$51
              byte %00000000   '$51
              byte %00000000   '$51
              byte %00000000   '$51
              
              byte %01111111   '$52
              byte %00001001   '$52
              byte %00011001   '$52
              byte %00101001   '$52
              byte %01000110   '$52
              byte %00000000   '$52
              byte %00000000   '$52
              byte %00000000   '$52
              
              byte %00100110   '$53
              byte %01001001   '$53
              byte %01001001   '$53
              byte %01001001   '$53
              byte %00110010   '$53
              byte %00000000   '$53
              byte %00000000   '$53
              byte %00000000   '$53
              
              byte %00000001   '$54
              byte %00000001   '$54
              byte %01111111   '$54
              byte %00000001   '$54
              byte %00000001   '$54
              byte %00000000   '$54
              byte %00000000   '$54
              byte %00000000   '$54
              
              byte %00111111   '$55
              byte %01000000   '$55
              byte %01000000   '$55
              byte %01000000   '$55
              byte %00111111   '$55
              byte %00000000   '$55
              byte %00000000   '$55
              byte %00000000   '$55
              
              byte %00000111   '$56
              byte %00011000   '$56
              byte %01100000   '$56
              byte %00011000   '$56
              byte %00000111   '$56
              byte %00000000   '$56
              byte %00000000   '$56
              byte %00000000   '$56
              
              byte %00111111   '$57
              byte %01000000   '$57
              byte %00111000   '$57
              byte %01000000   '$57
              byte %00111111   '$57
              byte %00000000   '$57
              byte %00000000   '$57
              byte %00000000   '$57
              
              byte %01100011   '$58
              byte %00010100   '$58
              byte %00001000   '$58
              byte %00010100   '$58
              byte %01100011   '$58
              byte %00000000   '$58
              byte %00000000   '$58
              byte %00000000   '$58
              
              byte %00000011   '$59
              byte %00000100   '$59
              byte %01111000   '$59
              byte %00000100   '$59
              byte %00000011   '$59
              byte %00000000   '$59
              byte %00000000   '$59
              byte %00000000   '$59
              
              byte %01100001   '$5A
              byte %01010001   '$5A
              byte %01001001   '$5A
              byte %01000101   '$5A
              byte %01000011   '$5A
              byte %00000000   '$5A
              byte %00000000   '$5A
              byte %00000000   '$5A
              
              byte %01111111   '$5B
              byte %01111111   '$5B
              byte %01000001   '$5B
              byte %01000001   '$5B
              byte %01000001   '$5B
              byte %00000000   '$5B
              byte %00000000   '$5B
              byte %00000000   '$5B
              
              byte %00000011   '$5C
              byte %00000100   '$5C
              byte %00001000   '$5C
              byte %00010000   '$5C
              byte %01100000   '$5C
              byte %00000000   '$5C
              byte %00000000   '$5C
              byte %00000000   '$5C
              
              byte %01000001   '$5D
              byte %01000001   '$5D
              byte %01000001   '$5D
              byte %01111111   '$5D
              byte %01111111   '$5D
              byte %00000000   '$5D
              byte %00000000   '$5D
              byte %00000000   '$5D
              
              byte %00010000   '$5E
              byte %00001000   '$5E
              byte %00000100   '$5E
              byte %00001000   '$5E
              byte %00010000   '$5E
              byte %00000000   '$5E
              byte %00000000   '$5E
              byte %00000000   '$5E
              
              byte %10000000   '$5F
              byte %10000000   '$5F
              byte %10000000   '$5F
              byte %10000000   '$5F
              byte %10000000   '$5F
              byte %00000000   '$5F
              byte %00000000   '$5F
              byte %00000000   '$5F
              
              byte %00000000   '$60
              byte %00000000   '$60
              byte %00000110   '$60
              byte %00000101   '$60
              byte %00000000   '$60
              byte %00000000   '$60
              byte %00000000   '$60
              byte %00000000   '$60
              
              byte %00100000   '$61
              byte %01010100   '$61
              byte %01010100   '$61
              byte %01010100   '$61
              byte %01111000   '$61
              byte %00000000   '$61
              byte %00000000   '$61
              byte %00000000   '$61
              
              byte %01111111   '$62
              byte %01000100   '$62
              byte %01000100   '$62
              byte %01000100   '$62
              byte %00111000   '$62
              byte %00000000   '$62
              byte %00000000   '$62
              byte %00000000   '$62
              
              byte %00111000   '$63
              byte %01000100   '$63
              byte %01000100   '$63
              byte %01000100   '$63
              byte %01000100   '$63
              byte %00000000   '$63
              byte %00000000   '$63
              byte %00000000   '$63
              
              byte %00111000   '$64
              byte %01000100   '$64
              byte %01000100   '$64
              byte %01000100   '$64
              byte %01111111   '$64
              byte %00000000   '$64
              byte %00000000   '$64
              byte %00000000   '$64
              
              byte %00111000   '$65
              byte %01010100   '$65
              byte %01010100   '$65
              byte %01010100   '$65
              byte %01011000   '$65
              byte %00000000   '$65
              byte %00000000   '$65
              byte %00000000   '$65
              
              byte %00001000   '$66
              byte %01111110   '$66
              byte %00001001   '$66
              byte %00001001   '$66
              byte %00000010   '$66
              byte %00000000   '$66
              byte %00000000   '$66
              byte %00000000   '$66
              
              byte %00011000   '$67
              byte %10100100   '$67
              byte %10100100   '$67
              byte %10100100   '$67
              byte %01111000   '$67
              byte %00000000   '$67
              byte %00000000   '$67
              byte %00000000   '$67
              
              byte %01111111   '$68
              byte %00000100   '$68
              byte %00000100   '$68
              byte %00000100   '$68
              byte %01111000   '$68
              byte %00000000   '$68
              byte %00000000   '$68
              byte %00000000   '$68
              
              byte %00000000   '$69
              byte %01000100   '$69
              byte %01111101   '$69
              byte %01000000   '$69
              byte %00000000   '$69
              byte %00000000   '$69
              byte %00000000   '$69
              byte %00000000   '$69
              
              byte %01000000   '$6A
              byte %10000000   '$6A
              byte %10000100   '$6A
              byte %01111101   '$6A
              byte %00000000   '$6A
              byte %00000000   '$6A
              byte %00000000   '$6A
              byte %00000000   '$6A
              
              byte %01101111   '$6B
              byte %00010000   '$6B
              byte %00010000   '$6B
              byte %00101000   '$6B
              byte %01000100   '$6B
              byte %00000000   '$6B
              byte %00000000   '$6B
              byte %00000000   '$6B
              
              byte %00000000   '$6C
              byte %01000001   '$6C
              byte %01111111   '$6C
              byte %01000000   '$6C
              byte %00000000   '$6C
              byte %00000000   '$6C
              byte %00000000   '$6C
              byte %00000000   '$6C
              
              byte %01111100   '$6D
              byte %00000100   '$6D
              byte %00111000   '$6D
              byte %00000100   '$6D
              byte %01111100   '$6D
              byte %00000000   '$6D
              byte %00000000   '$6D
              byte %00000000   '$6D
              
              byte %01111100   '$6E
              byte %00000100   '$6E
              byte %00000100   '$6E
              byte %00000100   '$6E
              byte %01111000   '$6E
              byte %00000000   '$6E
              byte %00000000   '$6E
              byte %00000000   '$6E
              
              byte %00111000   '$6F
              byte %01000100   '$6F
              byte %01000100   '$6F
              byte %01000100   '$6F
              byte %00111000   '$6F
              byte %00000000   '$6F
              byte %00000000   '$6F
              byte %00000000   '$6F
              
              byte %11111100   '$70
              byte %00100100   '$70
              byte %00100100   '$70
              byte %00100100   '$70
              byte %00011000   '$70
              byte %00000000   '$70
              byte %00000000   '$70
              byte %00000000   '$70
              
              byte %00011000   '$71
              byte %00100100   '$71
              byte %00100100   '$71
              byte %00100100   '$71
              byte %11111100   '$71
              byte %00000000   '$71
              byte %00000000   '$71
              byte %00000000   '$71
              
              byte %01111100   '$72
              byte %00001000   '$72
              byte %00000100   '$72
              byte %00000100   '$72
              byte %00000100   '$72
              byte %00000000   '$72
              byte %00000000   '$72
              byte %00000000   '$72
              
              byte %01001000   '$73
              byte %01010100   '$73
              byte %01010100   '$73
              byte %01010100   '$73
              byte %00100100   '$73
              byte %00000000   '$73
              byte %00000000   '$73
              byte %00000000   '$73
              
              byte %00000100   '$74
              byte %00111111   '$74
              byte %01000100   '$74
              byte %01000100   '$74
              byte %00100000   '$74
              byte %00000000   '$74
              byte %00000000   '$74
              byte %00000000   '$74
              
              byte %00111100   '$75
              byte %01000000   '$75
              byte %01000000   '$75
              byte %00100000   '$75
              byte %01111100   '$75
              byte %00000000   '$75
              byte %00000000   '$75
              byte %00000000   '$75
              
              byte %00011100   '$76
              byte %00100000   '$76
              byte %01000000   '$76
              byte %00100000   '$76
              byte %00011100   '$76
              byte %00000000   '$76
              byte %00000000   '$76
              byte %00000000   '$76
              
              byte %01111100   '$77
              byte %01000000   '$77
              byte %00110000   '$77
              byte %01000000   '$77
              byte %01111100   '$77
              byte %00000000   '$77
              byte %00000000   '$77
              byte %00000000   '$77
              
              byte %01000100   '$78
              byte %00101000   '$78
              byte %00010000   '$78
              byte %00101000   '$78
              byte %01000100   '$78
              byte %00000000   '$78
              byte %00000000   '$78
              byte %00000000   '$78
              
              byte %00011100   '$79
              byte %10100000   '$79
              byte %10100000   '$79
              byte %10100000   '$79
              byte %01111100   '$79
              byte %00000000   '$79
              byte %00000000   '$79
              byte %00000000   '$79
              
              byte %01000100   '$7A
              byte %01100100   '$7A
              byte %01010100   '$7A
              byte %01001100   '$7A
              byte %01000100   '$7A
              byte %00000000   '$7A
              byte %00000000   '$7A
              byte %00000000   '$7A
              
              byte %00001000   '$7B
              byte %00111110   '$7B
              byte %01110111   '$7B
              byte %01000001   '$7B
              byte %01000001   '$7B
              byte %00000000   '$7B
              byte %00000000   '$7B
              byte %00000000   '$7B
              
              byte %00000000   '$7C
              byte %00000000   '$7C
              byte %11111111   '$7C
              byte %00000000   '$7C
              byte %00000000   '$7C
              byte %00000000   '$7C
              byte %00000000   '$7C
              byte %00000000   '$7C
              
              byte %01000001   '$7D
              byte %01000001   '$7D
              byte %01110111   '$7D
              byte %00111110   '$7D
              byte %00001000   '$7D
              byte %00000000   '$7D
              byte %00000000   '$7D
              byte %00000000   '$7D
              
              byte %00000100   '$7E
              byte %00000010   '$7E
              byte %00000110   '$7E
              byte %00000100   '$7E
              byte %00000010   '$7E
              byte %00000000   '$7E
              byte %00000000   '$7E
              byte %00000000   '$7E
              
              byte %11111111   '$7F
              byte %11111111   '$7F
              byte %11111111   '$7F
              byte %11111111   '$7F
              byte %11111111   '$7F
              byte %00000000   '$7F
              byte %00000000   '$7F
              byte %00000000   '$7F                                                                                                                                                                                            
afterData     byte 255
                                                                                                                                                                       