DAT programName         byte "StoreMotor", 0
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

  fileName := @sdFileName          '' Change these two lines to match names of data
  bitmapPtr := @entry
  
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

sdFileName              byte "MOTORCNC.DAT", 0

'bitmap
                  
DAT                     org
'------------------------------------------------------------------------------
entry                   or      dira, stepMask
maxDelayCog             andn    outa, stepMask

minDelayCog             mov     mailboxAddr, par

                        'mov     byteCount, #4    
delayChangeCog          add     mailboxAddr, #4   ' ** convert to loop
accelIntervalCog        mov     maxDelayAddr, mailboxAddr
accelIntervalsCog       add     maxDelayAddr, #4
doubleAccel             mov     minDelayAddr, maxDelayAddr
accelStepsF             add     minDelayAddr, #4
accelStepsS             mov     delayChangeAddr, minDelayAddr
decelStepsF             add     delayChangeAddr, #4
decelStepsS             mov     accelIntervalAddr, delayChangeAddr
fullStepsF              add     accelIntervalAddr, #4
fullStepsS              mov     accelIntervalsAddr, accelIntervalAddr
fastPhase               add     accelIntervalsAddr, #4                                      
slowPhase               wrlong  con111, debugLocationClueF
                       
' Pass through only on start up.                        
'------------------------------------------------------------------------------
mainPasmLoop            wrlong  zero, par  ' used to indicate command complete
                        
smallLoop               rdlong  commandCog, par wz 
              if_z      jmp     #smallLoop
                        add     commandCog, #jumpTable
                       
                        jmp     commandCog
jumpTable               jmp     #smallLoop
                        
                        jmp     #driveOne
                        jmp     #driveTwo
                        jmp     #driveThree
                        jmp     #newParameters
                        
'#0, IDLE_MOTOR, SINGLE_MOTOR, DUAL_MOTOR, TRIPLE_MOTOR, NEW_PARAMETERS_MOTOR

'------------------------------------------------------------------------------
{{
      C[i] = C[i-1] - ((2*C[i])/(4*i+1))
          
}}
'------------------------------------------------------------------------------
'------------------------------------------------------------------------------
DAT driveOne            rdlong  resultPtr, mailboxAddr                        
                        mov     bufferAddress, resultPtr
                        wrlong  con222, debugLocationClueF
                        add     bufferAddress, #4
                        rdlong  fastMask, bufferAddress             
                        add     bufferAddress, #4
                        mov     fastTotal, zero
                        mov     delayTotal, zero
                        'rdlong  slowMask, bufferAddress              
                        'wrlong  bufferAddress, debugDelayTotal
                        rdlong  fastDistance, bufferAddress             
                        'add     bufferAddress, #4
                        'rdlong  slowDistance, bufferAddress             
                        mov     activeDelay, maxDelayCog
                        wrlong  maxDelayCog, debugMaxDelay
                        mov     activeChange, delayChangeCog
                        wrlong  activeDelay, debugActiveDelay
                        
                                'cmpsub if d > s write c 
                                'sub    if d < s write c 
                                'cmp    if d < s write c
                                'cmps   if d < s write c signed
                        mov     fullStepsF, fastDistance        
                        cmp     fullStepsF, doubleAccel wc
              if_nc     jmp     #setFullSpeedSingleSteps              
              if_c      jmp     #setLowSpeedSingleSteps

continueSingleSetup     sub     fullStepsF, accelStepsF
                        sub     fullStepsF, decelStepsF
                        add     fullStepsF, #1
                        add     accelStepsF, #1
                        add     decelStepsF, #1
' Add one to fullStepsF other acceleration steps to allow the use of djnz later.
                                         
                        'mov     stepDelay, activeHalfDelay
                       
                        mov     nextAccelTime, cnt
                        mov     nextStepTime, nextAccelTime
                        mov     nextHalfStepTime, nextAccelTime
                        sub     nextHalfStepTime, halfMaxDelayCog
                        add     nextAccelTime, accelIntervalCog
                        
accelLoopSingle         djnz    accelStepsF, #accelSingleBody
                        wrlong  con777, debugLocationClue
                        jmp     #fullSpeedSizeCheck
' exit acceleration loop                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
                        
accelSingleBody         call    #stepFastHigh
'                                                
firstPartOfStepA        mov     scratchTime, nextHalfStepTime
                        sub     scratchTime, cnt wc
                        'cmp     nextHalfStepTime, cnt wc  ' ** use waitcnt instead?
                        wrlong  scratchTime, debugScratchTime111
                        'mov     nextHalfStepTimeS, cnt
                        'wrlong  nextHalfStepTimeS, debugScratchTime
                        wrlong  con111, debugLocationClue
              if_nc     jmp     #firstPartOfStepA
              
                        andn    outa, fastMask
                        
secondPartOfStepA       mov     scratchTime, nextStepTime
                        sub     scratchTime, cnt wc
                        'cmp     nextStepTime, cnt wc
                        wrlong  scratchTime, debugScratchTime111
                        wrlong  con222, debugLocationClue
              if_nc     jmp     #secondPartOfStepA
                        wrlong  con771, debugLocationClue
                        mov     scratchTime, nextAccelTime
                        sub     scratchTime, cnt wc
                        'cmp     nextAccelTime, cnt wc ' check if acceleration time
                        wrlong  scratchTime, debugScratchTime
              if_nc     jmp     #accelLoopSingle

decreaseDelay           sub     activeDelay, activeChange
                        mov     nextHalfStepTime, nextStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     nextHalfStepTime, scratchTime
                        wrlong  activeDelay, debugActiveDelay
                        add     nextAccelTime, accelIntervalCog
                        jmp     #accelLoopSingle
                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
' begin full speed
fullSpeedSizeCheck      mov     lastAccelDelay, activeDelay
                        'mov     lastAccelHalfDelay, activeHalfDelay
                        wrlong  con999, debugLocationClue
                        wrlong  fullStepsF, debugFullStepsF
                        'jmp     #$
' Remember last acceleration delay so the decel delays calculate correctly.
                                                                                                        
                        tjz     shortFlag, #fullSpeedLoopEnter 'shortCenter
' We want to know if we should use minDelayCog or the last computed delay.

' The code below is used is full speed is reached in the acceleration section.                        
                        mov     activeDelay, minDelayCog
                        mov     nextHalfStepTime, nextStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     nextHalfStepTime, scratchTime
                        
fullSpeedLoopEnter      wrlong  con554, debugLocationClueF
                        wrlong  activeDelay, debugActiveDelay
fullSpeedLoop           djnz    fullStepsF, #fullSpeedSingleBody ' awkward code
' We previously added one to fullStepsF so this fist djnz doesn't mess out the step count.
                        wrlong  con556, debugLocationClueF
                        jmp     #decelSingleEnter
' exit full speed loop
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


fullSpeedSingleBody     call    #stepFastHigh
                        wrlong  con557, debugLocationClueF
firstPartOfStepFull     mov     scratchTime, nextHalfStepTime
                        sub     scratchTime, cnt wc
                        'cmp     nextHalfStepTime, cnt wc  ' ** use waitcnt instead?
                        wrlong  con338, debugLocationClue
              if_nc     jmp     #firstPartOfStepFull
              
                        andn    outa, fastMask
                        wrlong  con558, debugLocationClueF
secondPartOfStepFull    mov     scratchTime, nextStepTime
                        sub     scratchTime, cnt wc
                        'cmp     nextStepTime, cnt wc
                        wrlong  con448, debugLocationClue
              if_nc     jmp     #secondPartOfStepFull
                        wrlong  con888, debugLocationClue
                        jmp     #fullSpeedLoop
                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
' decelerate

decelSingleEnter        wrlong  con772, debugLocationClueF
                        mov     activeDelay, lastAccelDelay
                        'debugFullStepsF
                        'jmp     #$
''**************************************************************                       
                        'mov     activeHalfDelay, lastAccelHalfDelay
                        mov     nextAccelTime, nextStepTime ' ** not sure about timing
                        'mov     nextAccelTime, nextStepTime ' ** not sure about timing
                        add     nextAccelTime, accelIntervalCog
' Use last acceleration delay so the decel delays calculate correctly.
                                                                                                        
                        
decelLoopSingle         djnz    decelStepsF, #decelSingleBody

                        jmp     #finishSingleMove
' exit deceleration loop                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
 
decelSingleBody         call    #stepFastHigh

firstPartOfStepD        mov     scratchTime, nextHalfStepTime
                        sub     scratchTime, cnt wc
                        'cmp     nextHalfStepTime, cnt wc  ' ** use waitcnt instead?
                        wrlong  con555, debugLocationClue
              if_nc     jmp     #firstPartOfStepD
              
                        andn    outa, fastMask
                        
secondPartOfStepD       mov     scratchTime, nextStepTime
                        sub     scratchTime, cnt wc
                        'cmp     nextStepTime, cnt wc
                        wrlong  con666, debugLocationClue
              if_nc     jmp     #secondPartOfStepD

                        wrlong  con999, debugLocationClue
              
                        mov     scratchTime, nextAccelTime
                        sub     scratchTime, cnt wc
                        'cmp     nextAccelTime, cnt wc ' check if acceleration time
              if_nc     jmp     #decelLoopSingle'cceleration

increaseDelay           add     activeDelay, activeChange
                        mov     nextHalfStepTime, nextStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     nextHalfStepTime, scratchTime
                        wrlong  activeDelay, debugActiveDelay
                        add     nextAccelTime, accelIntervalCog
                        jmp     #decelLoopSingle
                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

finishSingleMove        wrlong  con999, debugLocationClueF
                        jmp     #mainPasmLoop

'------------------------------------------------------------------------------
setFullSpeedSingleSteps mov     accelStepsF, accelIntervalsCog
                        mov     decelStepsF, accelIntervalsCog
                        'mov     fullStepsF, fastDistance
                        mov     shortFlag, zero
                        wrlong  con333, debugLocationClueF
                        jmp     #continueSingleSetup
'------------------------------------------------------------------------------
setLowSpeedSingleSteps  mov     accelStepsF, fastDistance
                        shr     accelStepsF, #1
                        mov     decelStepsF, accelStepsF
                        mov     shortFlag, #1
                        wrlong  con444, debugLocationClueF
                        jmp     #continueSingleSetup 
'------------------------------------------------------------------------------
accelerateSingle
accelerateSingle_ret    ret

'------------------------------------------------------------------------------
setupNextStep

'------------------------------------------------------------------------------
DAT stepFastHigh        or      outa, fastMask
                        add     nextHalfStepTime, activeDelay 'activeHalfDelay
                        wrlong  nextHalfStepTime, debugNextHalfTime
                        add     delayTotal, activeDelay
                        wrlong  delayTotal, debugDelayTotal
                        wrlong  fullStepsF, debugFullSpeedSteps
                        wrlong  accelStepsF, debugAccelSteps
                        wrlong  decelStepsF, debugDecelSteps
                                
                        add     nextStepTime, activeDelay
                        wrlong  nextStepTime, debugNextStepTime
                        
                        add     fastTotal, #1
                        wrlong  fastTotal, debugFastTotal 'totalFromPasmFastPtr
stepFastHigh_ret        ret
'------------------------------------------------------------------------------
stepSlowHigh            or      outa, slowMask
                        add     nextHalfStepTimeS, activeDelayS
                        add     delayTotalS, activeDelayS
                        wrlong  delayTotalS, debugFullStepsF
                        add     nextStepTimeS, activeDelayS
                        add     slowTotal, #1
                        wrlong  slowTotal, debugSlowTotal 'totalFromPasmFastPtr
stepSlowHigh_ret        ret
'------------------------------------------------------------------------------
'------------------------------------------------------------------------------
DAT driveTwo            rdlong  resultPtr, mailboxAddr                        
                        mov     bufferAddress, resultPtr
                        'wrlong  con222, debugLocationClueF
                        add     bufferAddress, #4
                        rdlong  fastMask, bufferAddress             
                        add     bufferAddress, #4
                        mov     fastTotal, zero
                        rdlong  slowMask, bufferAddress              
                        mov     delayTotal, zero
                        add     bufferAddress, #4
                        'wrlong  bufferAddress, debugDelayTotal
                        rdlong  fastDistance, bufferAddress             
                        add     bufferAddress, #4
                        rdlong  slowDistance, bufferAddress ' is this used?            
                        add     bufferAddress, #4
                        rdlong  activeDelayS, bufferAddress 
                        add     bufferAddress, #4
                        rdlong  minDelayCogS, bufferAddress 
                        add     bufferAddress, #4
                        rdlong  delayChangeCogS, bufferAddress ' is this accurate enough?

                        mov     activeDelay, maxDelayCog
                        wrlong  maxDelayCog, debugMaxDelay
                        wrlong  activeDelay, debugActiveDelay
                                'cmpsub if d > s write c 
                                'sub    if d < s write c 
                                'cmp    if d < s write c
                                'cmps   if d < s write c signed
                       {longAxis, shortAxis, longDistance, shortDistance) | {
} maxDelayS, minDelayS, delayChangeS }
                        mov     fullStepsF, fastDistance        
                        cmp     fullStepsF, doubleAccel wc
              if_nc     jmp     #setFullSpeedDualSteps                
              if_c      jmp     #setLowSpeedDualSteps

continueDualSetup       sub     fullStepsF, accelStepsF
                        sub     fullStepsF, decelStepsF
                        add     fullStepsF, #1
                        add     accelStepsF, #1
                        add     decelStepsF, #1
                        mov     accelStage, #3

                        wrlong  delayTotal, debugDelayTotal
                        wrlong  fullStepsF, debugFullSpeedSteps
                        wrlong  accelStepsF, debugAccelSteps
                        wrlong  accelStage, debugAccelStage

                        mov     fastTotal, zero
                        mov     slowTotal, zero
                        mov     delayTotal, zero
                        mov     delayTotalS, zero
                        mov     fastPhase, zero
                        mov     slowPhase, zero
                                                              
setupAccel              neg     activeChange, delayChangeCog  ' add a negative number to accel
                        neg     activeChangeS, delayChangeCogS 
                        mov     stepCountdown, accelStepsF
                        wrlong  stepCountdown, debugStepCountdown

                        wrlong  activeChange, debugActiveChange
                        wrlong  activeChangeS, debugActiveChangeS
                        
' Add one to fullStepsF other acceleration steps to allow the use of djnz later.
                                         
                        'mov     stepDelay, activeHalfDelay
                       
                        mov     nextAccelTime, cnt
                        mov     nextStepTime, nextAccelTime
                        mov     nextHalfStepTime, nextAccelTime
                        sub     nextHalfStepTime, halfMaxDelayCog

                        mov     nextStepTimeS, nextAccelTime
                        mov     nextHalfStepTimeS, nextAccelTime
                        mov     scratchTime, activeDelayS
                        shr     scratchTime, #1
                        sub     nextHalfStepTimeS, scratchTime

                        add     nextAccelTime, accelIntervalCog
                      
                        
{dualLoop                djnz    stepCountdown, #dualBody
                        wrlong  con777, debugLocationClue
                        djnz    accelStage, #nextStage
                        jmp     #finalDual
nextStage               cmp     accelStage, #2 wz
              if_z      jmp     #setupFullSpeedDual '"setupFullSpeedDual" returns to dualLoop 
                        jmp     #setupDecelDual } 'accelStage equals one
                                '"setupDecelDual" returns to dualLoop
' exit acceleration loop                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
                        
'accelDualBody           call    #stepFastHigh
'                                                
dualLoop                mov     scratchTime, nextHalfStepTime
                        sub     scratchTime, cnt wc
                        wrlong  scratchTime, debugScratchTime111
                        wrlong  con111, debugLocationClue
              if_c      jmp     #stepFastLow2
continueDualLoop        mov     scratchTime, nextHalfStepTimeS
                        sub     scratchTime, cnt wc
              if_c      call    #stepSlowLow2
                        mov     scratchTime, nextStepTimeS
                        sub     scratchTime, cnt wc
              if_c      call    #stepSlowHigh2
                        mov     scratchTime, nextStepTime
                        sub     scratchTime, cnt wc
              if_c      call    #stepFastHigh2
              
checkForAcceleration    mov     scratchTime, nextAccelTime
                        sub     scratchTime, cnt wc
              if_nc     jmp     #dualLoop
              
                        add     nextAccelTime, accelIntervalCog
                        tjz     activeChange, #dualLoop ' optional
                        adds    activeDelay, activeChange ' activeChange may be zero, positive or negative
                        mov     nextHalfStepTime, nextStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     nextHalfStepTime, scratchTime

adjustSlowDelay         adds    activeDelayS, activeChangeS
                        mov     nextHalfStepTimeS, nextStepTimeS
                        mov     scratchTime, activeDelayS
                        shr     scratchTime, #1
                        sub     nextHalfStepTimeS, scratchTime

                        wrlong  activeDelay, debugActiveDelay
                        jmp     #dualLoop


' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

finalDual               call    #stepSlowLow2  ' Finish slow step too
                        wrlong  con1M, debug1MD
                        wrlong  con2M, debug2MD
                        wrlong  con3M, debug3MD
                        wrlong  con4M, debug4MD
                        wrlong  con999, debugLocationClueF
                        jmp     #mainPasmLoop

'------------------------------------------------------------------------------
setFullSpeedDualSteps   mov     accelStepsF, accelIntervalsCog
                        mov     decelStepsF, accelIntervalsCog
                        'mov     fullStepsF, fastDistance
                        mov     shortFlag, zero
                        wrlong  con333, debugLocationClueF
                        jmp     #continueDualSetup
'------------------------------------------------------------------------------
setLowSpeedDualSteps    mov     accelStepsF, fastDistance
                        shr     accelStepsF, #1
                        mov     decelStepsF, accelStepsF
                        mov     shortFlag, #1
                        wrlong  con444, debugLocationClueF
                        jmp     #continueDualSetup

'------------------------------------------------------------------------------
fullSpeedStageDual      mov     activeChange, zero
                        mov     activeChangeS, zero
                        mov     stepCountdown, fullStepsF
                        mov     lastAccelDelay, activeDelay 
                        mov     lastAccelDelayS, activeDelayS
                        wrlong  activeDelay, debugActiveDelay
                        wrlong  activeChange, debugActiveChange
                        wrlong  activeChangeS, debugActiveChangeS
                        wrlong  con1M, debug1MA
                        wrlong  con2M, debug2MA
                        wrlong  con3M, debug3MA
                        wrlong  con4M, debug4MA
                        
                        tjnz    shortFlag, #continueDualLoop ' present delays okay
                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
' setup full speed with full acceleration intervals, adjust delays for max speed

                        mov     activeDelay, minDelayCog 
                        mov     nextHalfStepTime, nextStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     nextHalfStepTime, scratchTime
                        
                        mov     activeDelayS, minDelayCogS
                        mov     nextHalfStepTimeS, nextStepTimeS
                        mov     scratchTime, activeDelayS
                        shr     scratchTime, #1
                        sub     nextHalfStepTimeS, scratchTime
                        jmp     #continueDualLoop 

'------------------------------------------------------------------------------
decelStageDual          mov     activeChange, delayChangeCog
                        mov     activeChangeS, delayChangeCogS
                        mov     stepCountdown, decelStepsF
                        wrlong  activeChange, debugActiveChange
                        wrlong  activeChangeS, debugActiveChangeS
                        wrlong  con1M, debug1MF
                        wrlong  con2M, debug2MF
                        wrlong  con3M, debug3MF
                        wrlong  con4M, debug4MF
                         
                        tjnz    shortFlag, #continueDualLoop  ' present delays okay
                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
' setup deceleration from full speed, adjust delays back to last acceleration delays

                        mov     activeDelay, lastAccelDelay 
                        mov     nextHalfStepTime, nextStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     nextHalfStepTime, scratchTime
                        
                        mov     activeDelayS, lastAccelDelayS
                        mov     nextHalfStepTimeS, nextStepTimeS
                        mov     scratchTime, activeDelayS
                        shr     scratchTime, #1
                        sub     nextHalfStepTimeS, scratchTime
                        jmp     #continueDualLoop 
 
'------------------------------------------------------------------------------
DAT 

stepFastHigh2           tjnz    fastPhase, #stepFastHigh2_ret
                        or      outa, fastMask
                        mov     fastPhase, #1
                        add     nextHalfStepTime, activeDelay
                        wrlong  nextHalfStepTime, debugNextHalfTime
                        add     delayTotal, activeDelay
                        
                        add     con4M, #1
                        wrlong  con4M, debug4M 
                        wrlong  accelStage, debugAccelStage
                        wrlong  stepCountdown, debugStepCountdown
                        
stepFastHigh2_ret       ret
'------------------------------------------------------------------------------
stepFastLow2            tjz     fastPhase, #continueDualLoop 
                             
                        andn    outa, fastMask
                        mov     fastPhase, zero
                        wrlong  decelStepsF, debugDecelSteps                          
                        add     nextStepTime, activeDelay
                        wrlong  nextStepTime, debugNextStepTime
                        add     con1M, #1
                        wrlong  con1M, debug1M
                        add     fastTotal, #1
                        wrlong  fastTotal, debugFastTotal 
'stepFastLow2_ret        ret
countdownSteps          djnz    stepCountdown, #continueDualLoop  'stepFastHigh2
                        wrlong  accelStage, debugAccelStage
                        wrlong  stepCountdown, debugStepCountdown
                        wrlong  con777, debugLocationClue
                        djnz    accelStage, #nextStage
                        jmp     #finalDual
nextStage               cmp     accelStage, #2 wz
                        
              if_z      jmp     #fullSpeedStageDual '"fullSpeedStageDual" returns to dualLoop 
                        jmp     #decelStageDual  'accelStage equals one
'------------------------------------------------------------------------------
stepSlowHigh2           tjnz    slowPhase, #stepSlowHigh2_ret
                        or      outa, slowMask
                        mov     slowPhase, #1
                        add     nextHalfStepTimeS, activeDelayS
                        add     con3M, #1
                        wrlong  con3M, debug3M
                        add     delayTotalS, activeDelayS
                        wrlong  delayTotalS, debugDelayTotalS 'debugSlowTotalDelay
stepSlowHigh2_ret       ret                        
'------------------------------------------------------------------------------
stepSlowLow2            tjz     slowPhase, #stepSlowLow2_ret
                        andn    outa, slowMask
                        mov     slowPhase, #0
                        add     nextStepTimeS, activeDelayS
                        add     con2M, #1
                        wrlong  con2M, debug2M
                        add     slowTotal, #1
                        wrlong  slowTotal, debugSlowTotal
stepSlowLow2_ret        ret                        
'------------------------------------------------------------------------------
driveThree              jmp     #mainPasmLoop         
'------------------------------------------------------------------------------
DAT newParameters       rdlong  maxDelayCog, maxDelayAddr 
                        mov     halfMaxDelayCog, maxDelayCog
                        shr     halfMaxDelayCog, #1                    
                        rdlong  minDelayCog, minDelayAddr
                        mov     halfMinDelayCog, minDelayCog
                        shr     halfMinDelayCog, #1                    
                        rdlong  delayChangeCog, delayChangeAddr 
                        'mov     halfDelayChangeCog, delayChangeCog
                        'shr     halfDelayChangeCog, #1
                        'neg     negativeChange, delayChangeCog
                                    
                        rdlong  accelIntervalCog, accelIntervalAddr 
                        rdlong  accelIntervalsCog, accelIntervalsAddr
                        mov     doubleAccel, accelIntervalsCog
                        add     doubleAccel, accelIntervalsCog
                        jmp     #mainPasmLoop        
'------------------------------------------------------------------------------

                              
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
{{
        mathResult (32-bit) := mathA (32-bit) * mathB (32-bit)
        ------------------------------------------

        Break the multiplication of 2 32-bit numbers into 4 multiplications
        of the 4x 16-bit portions:
        mathA * mathB =
              (mathA_hi * mathB_hi) << 32
            + (mathA_hi * mathB_lo) << 16
            + (mathA_lo * mathB_hi) << 16
            + (mathA_lo * mathB_lo) << 0

        Note that the first term can not fit in our result so we ignore it,
        and I can re-combine mathA_hi and mathA_lo:
        mathA * mathB (fit into 32 bits) =
              (mathA * mathB_lo)
            + (mathA_lo * mathB_hi) << 16   
}}
{multiply1      ' setup
                        mov     mathResult, #0      ' Primary accumulator (and final result)
                        mov     tmp1, mathA      ' Both my secondary accumulator,
                        shl     tmp1, #16     ' and the lower 16 bits of mathA.
                        mov     tmp2, mathB      ' This is the upper 16 bits of mathB,
                        shr     tmp2, #16     ' which will sum into my 2nd accumulator.
                        mov     loopCount, #16        ' Instead of 4 instructions 32x, do 6 instructions 16x.          
:loop                   ' mathA_hi_lo * mathB_lo
                        shr     mathB, #1 wc     ' get the low bit of mathB          
              if_c      add     mathResult, mathA      ' (conditionally) sum mathA into my 1st accumulator
                        shl     mathA, #1        ' bit align mathA for the next pass 
                        ' mathA_lo * mathB_hi
                        shl     tmp1, #1 wc   ' get the high bit of mathA_lo, *AND* shift my 2nd accumulator
              if_c      add     tmp1, tmp2    ' (conditionally) add mathB_hi into the 2nd accumulator
                        ' repeat 16x
                        djnz    loopCount, #:loop     ' I can't think of a way to early exit this
                        ' finalize
                        shl     tmp1, #16     ' align my 2nd accumulator
                        add     mathResult, tmp1    ' and add its contribution          
multiply1_ret           ret

'------------------------------------------------------------------------------
multiply                and     mathB, sixteenBits
                        shl     mathA, #16    
                        mov     loopCount, #16
                        shr     mathB, #1 wc            
:loop         if_c      add     mathB, mathA wc
                        ror     mathB, #1 wc
                        djnz    loopCount, #:loop                            
multiply_ret            ret
'------------------------------------------------------------------------------
'' Divide mathA[31..0] by mathB[15..0] (mathB[16] must be 0)
'' on exit, quotient is in the mathA[15..0] and remainder is in mathA[31..16]
divide                  shl     mathB, #15    
                        mov     loopCount, #16
                        shr     mathB, #1 wc            
:loop                   cmpsub  mathA, mathB wc
                        rcl     mathA, #1 wc
                        djnz    loopCount, #:loop
                        mov     mathResult, mathA
                        and     mathResult, sixteenBits
                                               
divide_ret              ret }
'------------------------------------------------------------------------------
zero                    long 0                  '' Constant
'sixteenBits             long %1111_1111_1111_1111
'bufferSize              long OLED_BUFFER_SIZE
                                              
'csMask                  long %10000                  '' Used for Chip Select mask
bufferAddress           long 0                  '' Used for buffer address

DAT ' PASM Variables

negativeOne             long -1
'destinationIncrement    long %10_0000_0000
'destAndSourceIncrement  long %10_0000_0001
'sourceIncrement         long 1
bits165                 long 1 << Header#OVER_TRAVEL_X_POS_165 | {
                           } 1 << Header#OVER_TRAVEL_X_NEG_165 | {
                           } 1 << Header#OVER_TRAVEL_Y_POS_165 | {
                           } 1 << Header#OVER_TRAVEL_Y_NEG_165 | {
                           } 1 << Header#OVER_TRAVEL_Z_POS_165 | {
                           } 1 << Header#OVER_TRAVEL_Z_NEG_165 | {
                           } 1 << Header#STALL_DRV8711_X_165 | {
                           } 1 << Header#FAULT_DRV8711_X_165 | {
                           } 1 << Header#STALL_DRV8711_Y_165 | {
                           } 1 << Header#FAULT_DRV8711_Y_165 | {
                           } 1 << Header#STALL_DRV8711_Z_165 | {
                           } 1 << Header#FAULT_DRV8711_Z_165
twelveBits              long $F_FF
bitDelay                long 80
con111                  long 111
con222                  long 222
con333                  long 333
con338                  long 338
con444                  long 444
con448                  long 448
con554                  long 554
con555                  long 555
con556                  long 556
con557                  long 557
con558                  long 558
con559                  long 559
con666                  long 666
con771                  long 771
con772                  long 772
con777                  long 777
con888                  long 888
con999                  long 999
con1M                   long 1_000_000
con2M                   long 2_000_000
con3M                   long 3_000_000
con4M                   long 4_000_000
                                           

stepMask                long 1 << Header#STEP_X_PIN | 1 << Header#STEP_Y_PIN | 1 << Header#STEP_Z_PIN
    
testBufferPtr           long 0-0
address165              long 0-0
debugActiveDelayS       long 0-0
debugActiveDelay        long 0-0
debugDelayTotalS        long 0-0
debugDelayTotal         long 0-0   
debugFullStepsF         long 0-0
debugAddress5           long 0-0
debugMaxDelay           long 0-0
debugAddress7           long 0-0
debugNextHalfTime       long 0-0
debugAddress9           long 0-0
debugFastTotal          long 0-0
debugSlowTotal          long 0-0
debugScratchTime111     long 0-0
debugScratchTime        long 0-0
debugLocationClue       long 0-0
debugLocationClueF      long 0-0
debugAccelSteps         long 0-0
debugDecelSteps         long 0-0
debugFullSpeedSteps     long 0-0
debugNextStepTime       long 0-0
debugAccelStage         long 0-0
debugStepCountdown      long 0-0 '21
debug1M                 long 0-0 
debug2M                 long 0-0 
debug3M                 long 0-0 
debug4M                 long 0-0
debug1MA                long 0-0 
debug2MA                long 0-0 
debug3MA                long 0-0 
debug4MA                long 0-0  
debug1MF                long 0-0 '30
debug2MF                long 0-0 
debug3MF                long 0-0 
debug4MF                long 0-0  
debug1MD                long 0-0 
debug2MD                long 0-0 
debug3MD                long 0-0 
debug4MD                long 0-0  
debugActiveChange       long 0-0 
debugAddressR           long 0-0 '39
debugActiveChangeS      long 0-0

stepDelay               res 1
'wait                    res 1
'adcRequest              res 1
'activeAdcPtr            res 1
resultPtr               res 1
'inputData               res 1
'outputData              res 1

'temp                    res 1
'readErrors              res 1
                    
'loopCount               res 1
'debugPtrCog             res 1
{mathA                   res 1
mathB                   res 1
mathResult              res 1
tmp1                    res 1 
tmp2                    res 1}
fastMask                res 1
slowMask                res 1
mailboxAddr             res 1
maxDelayAddr            res 1   
minDelayAddr            res 1   
delayChangeAddr         res 1   
accelIntervalAddr       res 1   
accelIntervalsAddr      res 1   


halfMaxDelayCog         res 1
halfMinDelayCog         res 1
'halfDelayChangeCog      res 1
'activeHalfDelay         res 1
activeDelay             res 1
'activeHalfChange        res 1
activeChange            res 1
'activeHalfDelayS        res 1
activeDelayS            res 1
'activeHalfChangeS       res 1
activeChangeS           res 1
commandCog              res 1
'dataOutToShred          res 1
shiftRegisterInput      res 1
'shiftOutputChange       res 1
'dataValue               res 1
'dataOut                 res 1
'byteCount               res 1
'lastAccelTime           res 1
fastTotal               res 1
slowTotal               res 1
delayTotal              res 1
delayTotalS             res 1
fastDistance            res 1
slowDistance            res 1
nextAccelTime           res 1
'nextAccelTimeS          res 1
nextStepTime            res 1
nextStepTimeS           res 1
nextHalfStepTime        res 1
nextHalfStepTimeS       res 1
lastAccelDelay          res 1
lastAccelDelayS         res 1
'lastAccelHalfDelay      res 1
'lastAccelHalfDelayS     res 1
shortFlag               res 1
minHalfDelayCog         res 1
minHalfDelayCogS        res 1
scratchTime             res 1
minDelayCogS            res 1
accelStage              res 1
'negativeChange          res 1
delayChangeCogS         res 1
stepCountdown           res 1
                       
                        fit                                                                                                                                                                                       
afterData     byte 255

                                                                                                                                                              