DAT programName         byte "StoreFreeDesign", 0
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

  Header : "HeaderCnc150415a"
  Pst : "Parallax Serial TerminalDat"
  Format : "StrFmt"
  Sd[1]: "SdSmall150327a" 
  Spi : "StepperSpi150416a"  
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
        
  OpenOutputFileW(0, fileName)
  Sd.writeData(bitmapPtr, bitmapSize)
  Sd.closeFile
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

bitmapFile      byte "FREEDESI.DAT", 0

bitmap                  byte %00000000   'freeDesign032
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign033           byte %10111111
                        byte %10111111
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign034           byte %00000111
                        byte %00000000
                        byte %00000111
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign035           byte %00001010
                        byte %00011111
                        byte %00001010
                        byte %00011111
                        byte %00001010
                        byte %00000000
                        byte %00000000
                        byte %00000000




freeDesign036           byte %01001100
                        byte %11011111
                        byte %01111010
                        byte %00110010
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign037           byte %00000110
                        byte %00001001
                        byte %11100111
                        byte %00010001
                        byte %00001001
                        byte %01100111
                        byte %10010000
                        byte %01100000

freeDesign038           byte %01100000
                        byte %11110110
                        byte %10001111
                        byte %10001001
                        byte %01100001
                        byte %11110011
                        byte %10010000
                        byte %00000000

freeDesign039           byte %00000111
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign040           byte %00111100
                        byte %01111110
                        byte %10000001
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign041           byte %10000001
                        byte %01111110
                        byte %00111100
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign042           byte %00101000
                        byte %00010000
                        byte %01111100
                        byte %00010000
                        byte %00101000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign043           byte %00010000
                        byte %00010000
                        byte %01111100
                        byte %00010000
                        byte %00010000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign044           byte %10100000
                        byte %01100000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign045           byte %00001000
                        byte %00001000
                        byte %00001000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign046           byte %11000000
                        byte %11000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign047           byte %11000000
                        byte %00110000
                        byte %00001100
                        byte %00000011
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign048           byte %01111110
                        byte %11111111
                        byte %10001001
                        byte %10010001
                        byte %11111111
                        byte %01111110
                        byte %00000000
                        byte %00000000

freeDesign049           byte %00000010
                        byte %11111111
                        byte %11111111
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign050           byte %11000010
                        byte %11100001
                        byte %10110001
                        byte %10011111
                        byte %10001110
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign051           byte %10000010
                        byte %10001001
                        byte %10001001
                        byte %11111111
                        byte %01110110
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign052           byte %00110000
                        byte %00101100
                        byte %00100000
                        byte %11111111
                        byte %11111111
                        byte %00100000
                        byte %00000000
                        byte %00000000

freeDesign053           byte %10001111
                        byte %10001111
                        byte %10001001
                        byte %11111001
                        byte %01110001
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign054           byte %01111100
                        byte %11111110
                        byte %10001001
                        byte %10001001
                        byte %11111001
                        byte %01110000
                        byte %00000000
                        byte %00000000

freeDesign055           byte %00000001
                        byte %11000001
                        byte %11110001
                        byte %00111101
                        byte %00001111
                        byte %00000011
                        byte %00000000
                        byte %00000000




freeDesign056           byte %01110110
                        byte %11111111
                        byte %10001001
                        byte %10001001
                        byte %11111111
                        byte %01110110
                        byte %00000000
                        byte %00000000

freeDesign057           byte %00001110
                        byte %10011111
                        byte %10010001
                        byte %11010001
                        byte %01111111
                        byte %00111110
                        byte %00000000
                        byte %00000000

freeDesign058           byte %01101100
                        byte %01101100
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign059           byte %10101100
                        byte %01101100
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign060           byte %00011000
                        byte %00111100
                        byte %01100110
                        byte %01000010
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign061           byte %00010100
                        byte %00010100
                        byte %00010100
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign062           byte %01000010
                        byte %01100110
                        byte %00111100
                        byte %00011000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign063           byte %00000011
                        byte %00000011
                        byte %10110001
                        byte %10011001
                        byte %00001111
                        byte %00000110
                        byte %00000000
                        byte %00000000

freeDesign064           byte %00111100
                        byte %01000010
                        byte %10111001
                        byte %10100101
                        byte %10100101
                        byte %10111101
                        byte %10100001
                        byte %00111110

freeDesign065           byte %11100000
                        byte %00111000
                        byte %00100111
                        byte %00111111
                        byte %11111100
                        byte %11100000
                        byte %00000000
                        byte %00000000




freeDesign066           byte %11111111
                        byte %11111111
                        byte %10001001
                        byte %10001001
                        byte %11111111
                        byte %01110110
                        byte %00000000
                        byte %00000000

freeDesign067           byte %01111110
                        byte %11111111
                        byte %10000001
                        byte %10000001
                        byte %01000011
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign068           byte %11111111
                        byte %11111111
                        byte %10000001
                        byte %10000001
                        byte %11111111
                        byte %01111110
                        byte %00000000
                        byte %00000000

freeDesign069           byte %11111111
                        byte %11111111
                        byte %10001001
                        byte %10001001
                        byte %10000001
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign070           byte %11111111
                        byte %11111111
                        byte %00001001
                        byte %00001001
                        byte %00000001
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign071           byte %01111110
                        byte %11111111
                        byte %10000001
                        byte %10010001
                        byte %01110001
                        byte %11110011
                        byte %00000000
                        byte %00000000

freeDesign072           byte %11111111
                        byte %11111111
                        byte %00001000
                        byte %00001000
                        byte %11111111
                        byte %11111111
                        byte %00000000
                        byte %00000000

freeDesign073           byte %00000000
                        byte %00000000
                        byte %11111111
                        byte %11111111
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign074           byte %01000000
                        byte %10000000
                        byte %10000000
                        byte %11111111
                        byte %01111111
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign075           byte %11111111
                        byte %11111111
                        byte %00001000
                        byte %00111100
                        byte %11110010
                        byte %11000001
                        byte %00000000
                        byte %00000000




freeDesign076           byte %11111111
                        byte %11111111
                        byte %10000000
                        byte %10000000
                        byte %10000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign077           byte %11111111
                        byte %00001111
                        byte %00111100
                        byte %00110000
                        byte %00001100
                        byte %11111111
                        byte %11111111
                        byte %00000000

freeDesign078           byte %11111111
                        byte %00001111
                        byte %00111100
                        byte %11110000
                        byte %11111111
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign079           byte %01111110
                        byte %11111111
                        byte %10000001
                        byte %10000001
                        byte %11111111
                        byte %01111110
                        byte %00000000
                        byte %00000000

freeDesign080           byte %11111111
                        byte %11111111
                        byte %00010001
                        byte %00010001
                        byte %00011111
                        byte %00001110
                        byte %00000000
                        byte %00000000

freeDesign081           byte %00111110
                        byte %01111111
                        byte %01000001
                        byte %01000001
                        byte %11111111
                        byte %10111110
                        byte %10000000
                        byte %00000000

freeDesign082           byte %11111111
                        byte %11111111
                        byte %00010001
                        byte %00010001
                        byte %11111111
                        byte %11101110
                        byte %00000000
                        byte %00000000

freeDesign083           byte %11000110
                        byte %10001111
                        byte %10011101
                        byte %11111001
                        byte %01110011
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign084           byte %00000001
                        byte %00000001
                        byte %11111111
                        byte %11111111
                        byte %00000001
                        byte %00000001
                        byte %00000000
                        byte %00000000

freeDesign085           byte %01111111
                        byte %11111111
                        byte %10000000
                        byte %10000000
                        byte %11111111
                        byte %01111111
                        byte %00000000
                        byte %00000000




freeDesign086           byte %00000011
                        byte %00011111
                        byte %11111100
                        byte %11100000
                        byte %00011100
                        byte %00000011
                        byte %00000000
                        byte %00000000

freeDesign087           byte %00000011
                        byte %00011111
                        byte %11111100
                        byte %11100000
                        byte %00011100
                        byte %00011000
                        byte %11100000
                        byte %11111111

freeDesign088           byte %11000011
                        byte %00101111
                        byte %00111100
                        byte %11110100
                        byte %11000011
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign089           byte %00000011
                        byte %00001111
                        byte %11111100
                        byte %11110000
                        byte %00001100
                        byte %00000011
                        byte %00000000
                        byte %00000000

freeDesign090           byte %11000001
                        byte %11110001
                        byte %10111101
                        byte %10001111
                        byte %10000011
                        byte %00000000
                        byte %00000000
                        byte %00000000




freeDesign091           byte %11111111
                        byte %11111111
                        byte %10000001
                        byte %10000001
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign092           byte %00000010
                        byte %00001110
                        byte %00111100
                        byte %01110000
                        byte %01000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign093           byte %10000001
                        byte %10000001
                        byte %11111111
                        byte %11111111
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign094           byte %00010000
                        byte %00001000
                        byte %00000100
                        byte %00001000
                        byte %00010000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign095           byte %10000000
                        byte %10000000
                        byte %10000000
                        byte %10000000
                        byte %10000000
                        byte %10000000
                        byte %10000000
                        byte %10000000




freeDesign096           byte %00000100
                        byte %00001100
                        byte %00011000
                        byte %00010000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign097           byte %00110000
                        byte %01111010
                        byte %01001010
                        byte %01001010
                        byte %01111110
                        byte %01111100
                        byte %00000000
                        byte %00000000

freeDesign098           byte %01111111
                        byte %01111111
                        byte %01000100
                        byte %01000100
                        byte %01111100
                        byte %00111000
                        byte %00000000
                        byte %00000000

freeDesign099           byte %00111100
                        byte %01111110
                        byte %01000010
                        byte %01000010
                        byte %00100110
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign100           byte %00111000
                        byte %01111100
                        byte %01000100
                        byte %01000100
                        byte %01111111
                        byte %01111111
                        byte %00000000
                        byte %00000000

freeDesign101           byte %00111100
                        byte %01111110
                        byte %01010010
                        byte %01001010
                        byte %01001110
                        byte %00100100
                        byte %00000000
                        byte %00000000

freeDesign102           byte %00000100
                        byte %01111110
                        byte %01111111
                        byte %00000101
                        byte %00000001
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign103           byte %00011110
                        byte %10111110
                        byte %10100010
                        byte %10100010
                        byte %11111110
                        byte %01111110
                        byte %00000010
                        byte %00000000

freeDesign104           byte %01111111
                        byte %01111111
                        byte %00001000
                        byte %00000100
                        byte %01111100
                        byte %01111000
                        byte %00000000
                        byte %00000000

freeDesign105           byte %01111101
                        byte %01111101
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000




freeDesign106           byte %10000000
                        byte %11111101
                        byte %01111101
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign107           byte %01111111
                        byte %01111111
                        byte %00010000
                        byte %00111000
                        byte %01100100
                        byte %01000010
                        byte %00000000
                        byte %00000000

freeDesign108           byte %01111111
                        byte %01111111
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign109           byte %01111110
                        byte %01111110
                        byte %00000100
                        byte %01111110
                        byte %01111100
                        byte %00000100
                        byte %01111110
                        byte %01111100

freeDesign110           byte %01111110
                        byte %01111110
                        byte %00000100
                        byte %00000010
                        byte %01111110
                        byte %01111100
                        byte %00000000
                        byte %00000000




freeDesign111           byte %00111100
                        byte %01111110
                        byte %01000010
                        byte %01000010
                        byte %01111110
                        byte %00111100
                        byte %00000000
                        byte %00000000

freeDesign112           byte %11111110
                        byte %11111110
                        byte %00100010
                        byte %00100010
                        byte %00111110
                        byte %00011100
                        byte %00000000
                        byte %00000000

freeDesign113           byte %00011100
                        byte %00111110
                        byte %00100010
                        byte %00100010
                        byte %11111110
                        byte %11111110
                        byte %00000000
                        byte %00000000

freeDesign114           byte %01111110
                        byte %01111110
                        byte %00000100
                        byte %00000110
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign115           byte %01001100
                        byte %01011110
                        byte %01111010
                        byte %00110010
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000




freeDesign116           byte %00000100
                        byte %11111111
                        byte %11111111
                        byte %00000100
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign117           byte %00111110
                        byte %01111110
                        byte %01000000
                        byte %01000000
                        byte %01111110
                        byte %00111110
                        byte %00000000
                        byte %00000000

freeDesign118           byte %00000110
                        byte %00011110
                        byte %01111000
                        byte %01100000
                        byte %00011110
                        byte %00000110
                        byte %00000000
                        byte %00000000

freeDesign119           byte %00011110
                        byte %01111110
                        byte %01100000
                        byte %00011110
                        byte %01111110
                        byte %01100000
                        byte %00011110
                        byte %00011110

freeDesign120           byte %01000110
                        byte %01101110
                        byte %00011100
                        byte %00111000
                        byte %01110110
                        byte %01100010
                        byte %00000000
                        byte %00000000

freeDesign121           byte %00000110
                        byte %10011110
                        byte %10111000
                        byte %11100000
                        byte %00011110
                        byte %00000110
                        byte %00000000
                        byte %00000000

freeDesign122           byte %01100010
                        byte %01111010
                        byte %01011110
                        byte %01000110
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign123           byte %00011000
                        byte %01111110
                        byte %11100111
                        byte %10000001
                        byte %10000001
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign124           byte %11111111
                        byte %11111111
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

freeDesign125           byte %10000001
                        byte %10000001
                        byte %11100111
                        byte %01111110
                        byte %00011000
                        byte %00000000
                        byte %00000000
                        byte %00000000




freeDesign126           byte %00001000
                        byte %00000100
                        byte %00000100
                        byte %00001100
                        byte %00011000
                        byte %00010000
                        byte %00010000
                        byte %00001000                                                                                                                                                                                             
afterData     byte 255

ASCII_0508_032          byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_033          byte %00000000
                        byte %00000000
                        byte %01011111
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_034          byte %00000000
                        byte %00000111
                        byte %00000000
                        byte %00000111
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_035          byte %00010100
                        byte %01111111
                        byte %00010100
                        byte %01111111
                        byte %00010100
                        byte %00000000
                        byte %00000000
                        byte %00000000


ASCII_0508_036          byte %00100100
                        byte %00101110
                        byte %01111011
                        byte %00101010
                        byte %00010010
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_037          byte %00100011
                        byte %00010011
                        byte %00001000
                        byte %01100100
                        byte %01100010
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_038          byte %00110110
                        byte %01001001
                        byte %01010110
                        byte %00100000
                        byte %01010000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_039          byte %00000000
                        byte %00000100
                        byte %00000011
                        byte %00000001
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_040          byte %00000000
                        byte %00011100
                        byte %00100010
                        byte %01000001
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_041          byte %00000000
                        byte %01000001
                        byte %00100010
                        byte %00011100
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_042          byte %00100010
                        byte %00010100
                        byte %01111111
                        byte %00010100
                        byte %00100010
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_043          byte %00001000
                        byte %00001000
                        byte %01111111
                        byte %00001000
                        byte %00001000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_044          byte %01000000
                        byte %00110000
                        byte %00010000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_045          byte %00001000
                        byte %00001000
                        byte %00001000
                        byte %00001000
                        byte %00001000
                        byte %00000000
                        byte %00000000
                        byte %00000000




ASCII_0508_046          byte %00000000
                        byte %01100000
                        byte %01100000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_047          byte %00100000
                        byte %00010000
                        byte %00001000
                        byte %00000100
                        byte %00000010
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_048          byte %00111110
                        byte %01010001
                        byte %01001001
                        byte %01000101
                        byte %00111110
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_049          byte %00000000
                        byte %01000010
                        byte %01111111
                        byte %01000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_050          byte %01100010
                        byte %01010001
                        byte %01001001
                        byte %01001001
                        byte %01000110
                        byte %00000000
                        byte %00000000
                        byte %00000000




ASCII_0508_051          byte %00100001
                        byte %01000001
                        byte %01001001
                        byte %01001101
                        byte %00110011
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_052          byte %00011000
                        byte %00010100
                        byte %00010010
                        byte %01111111
                        byte %00010000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_053          byte %00100111
                        byte %01000101
                        byte %01000101
                        byte %01000101
                        byte %00111001
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_054          byte %00111100
                        byte %01001010
                        byte %01001001
                        byte %01001001
                        byte %00110001
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_055          byte %00000001
                        byte %01110001
                        byte %00001001
                        byte %00000101
                        byte %00000011
                        byte %00000000
                        byte %00000000
                        byte %00000000




ASCII_0508_056          byte %00110110
                        byte %01001001
                        byte %01001001
                        byte %01001001
                        byte %00110110
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_057          byte %01000110
                        byte %01001001
                        byte %01001001
                        byte %00101001
                        byte %00011110
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_058          byte %00000000
                        byte %00110110
                        byte %00110110
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_059          byte %01000000
                        byte %00110110
                        byte %00110110
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_060          byte %00001000
                        byte %00010100
                        byte %00100010
                        byte %01000001
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_061          byte %00010100
                        byte %00010100
                        byte %00010100
                        byte %00010100
                        byte %00010100
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_062          byte %00000000
                        byte %01000001
                        byte %00100010
                        byte %00010100
                        byte %00001000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_063          byte %00000010
                        byte %00000001
                        byte %01011001
                        byte %00000101
                        byte %00000010
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_064          byte %00111110
                        byte %01000001
                        byte %01011101
                        byte %01010101
                        byte %01011110
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_065          byte %01111100
                        byte %00010010
                        byte %00010001
                        byte %00010010
                        byte %01111100
                        byte %00000000
                        byte %00000000
                        byte %00000000




ASCII_0508_066          byte %01111111
                        byte %01001001
                        byte %01001001
                        byte %01001001
                        byte %00110110
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_067          byte %00111110
                        byte %01000001
                        byte %01000001
                        byte %01000001
                        byte %00100010
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_068          byte %01111111
                        byte %01000001
                        byte %01000001
                        byte %01000001
                        byte %00111110
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_069          byte %01111111
                        byte %01001001
                        byte %01001001
                        byte %01001001
                        byte %01000001
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_070          byte %01111111
                        byte %00001001
                        byte %00001001
                        byte %00001001
                        byte %00000001
                        byte %00000000
                        byte %00000000
                        byte %00000000




ASCII_0508_071          byte %00111110
                        byte %01000001
                        byte %01010001
                        byte %01010001
                        byte %01110010
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_072          byte %01111111
                        byte %00001000
                        byte %00001000
                        byte %00001000
                        byte %01111111
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_073          byte %00000000
                        byte %01000001
                        byte %01111111
                        byte %01000001
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_074          byte %00100000
                        byte %01000000
                        byte %01000001
                        byte %00111111
                        byte %00000001
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_075          byte %01111111
                        byte %00001000
                        byte %00010100
                        byte %00100010
                        byte %01000001
                        byte %00000000
                        byte %00000000
                        byte %00000000




ASCII_0508_076          byte %01111111
                        byte %01000000
                        byte %01000000
                        byte %01000000
                        byte %01000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_077          byte %01111111
                        byte %00000010
                        byte %00001100
                        byte %00000010
                        byte %01111111
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_078          byte %01111111
                        byte %00000100
                        byte %00001000
                        byte %00010000
                        byte %01111111
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_079          byte %00111110
                        byte %01000001
                        byte %01000001
                        byte %01000001
                        byte %00111110
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_080          byte %01111111
                        byte %00001001
                        byte %00001001
                        byte %00001001
                        byte %00000110
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        
ASCII_0508_081          byte %00111110
                        byte %01000001
                        byte %01010001
                        byte %00100001
                        byte %01011110
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_082          byte %01111111
                        byte %00001001
                        byte %00011001
                        byte %00101001
                        byte %01000110
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_083          byte %00100110
                        byte %01001001
                        byte %01001001
                        byte %01001001
                        byte %00110010
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_084          byte %00000001
                        byte %00000001
                        byte %01111111
                        byte %00000001
                        byte %00000001
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_085          byte %00111111
                        byte %01000000
                        byte %01000000
                        byte %01000000
                        byte %00111111
                        byte %00000000
                        byte %00000000
                        byte %00000000




ASCII_0508_086          byte %00011111
                        byte %00100000
                        byte %01000000
                        byte %00100000
                        byte %00011111
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_087          byte %01111111
                        byte %00100000
                        byte %00011000
                        byte %00100000
                        byte %01111111
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_088          byte %01100011
                        byte %00010100
                        byte %00001000
                        byte %00010100
                        byte %01100011
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_089          byte %00000011
                        byte %00000100
                        byte %01111000
                        byte %00000100
                        byte %00000011
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_090          byte %01100001
                        byte %01010001
                        byte %01001001
                        byte %01000101
                        byte %01000011
                        byte %00000000
                        byte %00000000
                        byte %00000000




ASCII_0508_091          byte %01111111
                        byte %01111111
                        byte %01000001
                        byte %01000001
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_092          byte %00000010
                        byte %00000100
                        byte %00001000
                        byte %00010000
                        byte %00100000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_093          byte %00000000
                        byte %01000001
                        byte %01000001
                        byte %01111111
                        byte %01111111
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_094          byte %00000100
                        byte %00000010
                        byte %01111111
                        byte %00000010
                        byte %00000100
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_095          byte %00001000
                        byte %00011100
                        byte %00101010
                        byte %00001000
                        byte %00001000
                        byte %00000000
                        byte %00000000
                        byte %00000000




ASCII_0508_096          byte %00000000
                        byte %00000000
                        byte %00000001
                        byte %00000010
                        byte %00000100
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_097          byte %00100100
                        byte %01010100
                        byte %01010100
                        byte %00111000
                        byte %01000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_098          byte %01111111
                        byte %00101000
                        byte %01000100
                        byte %01000100
                        byte %00111000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_099          byte %00111000
                        byte %01000100
                        byte %01000100
                        byte %01000100
                        byte %00001000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_100          byte %00111000
                        byte %01000100
                        byte %01000100
                        byte %00101000
                        byte %01111111
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_101          byte %00111000
                        byte %01010100
                        byte %01010100
                        byte %01010100
                        byte %00001000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_102          byte %00001000
                        byte %01111110
                        byte %00001001
                        byte %00001001
                        byte %00000010
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_103          byte %10011000
                        byte %10100100
                        byte %10100100
                        byte %10100100
                        byte %01111000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_104          byte %01111111
                        byte %00001000
                        byte %00000100
                        byte %00000100
                        byte %01111000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_105          byte %00000000
                        byte %00000000
                        byte %01111001
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000




ASCII_0508_106          byte %00000000
                        byte %10000000
                        byte %10001000
                        byte %01111001
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_107          byte %01111111
                        byte %00010000
                        byte %00101000
                        byte %01000100
                        byte %01000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_108          byte %00000000
                        byte %01000001
                        byte %01111111
                        byte %01000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_109          byte %01111000
                        byte %00000100
                        byte %01111000
                        byte %00000100
                        byte %01111000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_110          byte %00000100
                        byte %01111000
                        byte %00000100
                        byte %00000100
                        byte %01111000
                        byte %00000000
                        byte %00000000
                        byte %00000000




ASCII_0508_111          byte %00111000
                        byte %01000100
                        byte %01000100
                        byte %01000100
                        byte %00111000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_112          byte %11111100
                        byte %00100100
                        byte %00100100
                        byte %00100100
                        byte %00011000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_113          byte %00011000
                        byte %00100100
                        byte %00100100
                        byte %00100100
                        byte %11111100
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_114          byte %00000100
                        byte %01111000
                        byte %00000100
                        byte %00000100
                        byte %00001000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_115          byte %01001000
                        byte %01010100
                        byte %01010100
                        byte %01010100
                        byte %00100100
                        byte %00000000
                        byte %00000000
                        byte %00000000




ASCII_0508_116          byte %00000100
                        byte %00111111
                        byte %01000100
                        byte %01000100
                        byte %00100100
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_117          byte %00111100
                        byte %01000000
                        byte %01000000
                        byte %00111100
                        byte %01000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_118          byte %00011100
                        byte %00100000
                        byte %01000000
                        byte %00100000
                        byte %00011100
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_119          byte %00111100
                        byte %01000000
                        byte %00111100
                        byte %01000000
                        byte %00111100
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_120          byte %01000100
                        byte %00101000
                        byte %00010000
                        byte %00101000
                        byte %01000100
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_121          byte %10011100
                        byte %10100000
                        byte %10100000
                        byte %10010000
                        byte %01111100
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_122          byte %01000100
                        byte %01100100
                        byte %01010100
                        byte %01001100
                        byte %01000100
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_123          byte %00001000
                        byte %00110110
                        byte %01000001
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_124          byte %00000000
                        byte %00000000
                        byte %01110111
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000
                        byte %00000000

ASCII_0508_125          byte %00000000
                        byte %00000000
                        byte %01000001
                        byte %00110110
                        byte %00001000
                        byte %00000000
                        byte %00000000
                        byte %00000000




ASCII_0508_126          byte %00001000
                        byte %00000100
                        byte %00001000
                        byte %00010000
                        byte %00001000
                        byte %00000000
                        byte %00000000
                        byte %00000000                                                                                                                                                                       