DAT programName         byte "ViewSmallBeanie", 0
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

bitmapFile      byte "BEANIE_0.DAT", 0

bitmap        byte $04, $0E, $0E, $0E, $0E, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $04, $04, $04, $F4
              byte $F4, $04, $04, $04, $82, $06, $06, $06, $06, $06, $06, $07, $0F, $0E, $0E, $04
              byte $00, $00, $00, $80, $E0, $F0, $F8, $1C, $0E, $02, $01, $00, $00, $F8, $FF, $FF
              byte $FF, $FF, $FC, $00, $00, $01, $03, $06, $1C, $F8, $F0, $E0, $80, $00, $00, $00
              byte $00, $00, $7C, $5F, $9F, $9F, $80, $88, $88, $88, $08, $08, $0E, $0F, $0F, $0F
              byte $0F, $0F, $0F, $0F, $08, $08, $88, $88, $88, $80, $9F, $9F, $5F, $7C, $00, $00
              byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01
              byte $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00                                                                                                                                                                                      
afterData     byte 255
                                                                                                                                                                       