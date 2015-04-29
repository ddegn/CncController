DAT programName         byte "EXECUTE_", 0
CON
{  Design Execute
  This sub program reads the design file from the SD card and executes the instructions.

  ******* Private Notes *******
 
  Change name from "DESIGNIN" to "EXECUTE_."
 
}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq
  MS_001   = CLK_FREQ / 1_000
  US_001   = CLK_FREQ / 1_000_000

  SCALED_MULTIPLIER = 1000

  QUOTE = 34

  'executeState enumeration
  #0, INIT_EXECUTE, SELECT_TO_EXECUTE, ACTIVE_EXECUTE, RETURN_FROM_EXECUTE
            
VAR

  'long stack[64]
  'long qq
  'long commandSpi
  'long debugSpi[16]
  'long shiftRegisterOutput, shiftRegisterInput ' read only from Spin
  'long adcData[8]

  'long lastRefreshTime, refreshInterval
  'long sdErrorNumber, sdErrorString, sdTryCount
  'long filePosition[Header#NUMBER_OF_AXES]
  'long globalMultiplier
  'long timer
  'long topX, topY, topZ
  long oledPtr[Header#MAX_OLED_DATA_LINES]
  long adcPtr, buttonMask
  long configPtr', filePosition[4]
  long globalMultiplier, fileNamePtr
  long fileIdNumber[Header#MAX_DATA_FILES]
  long dataFileCounter, highlightedFile
  
  byte debugLock, spiLock
  'byte tstr[32]

  'byte sdMountFlag[Header#NUMBER_OF_SD_INSTANCES]
  byte endFlag
  'byte configData[Header#CONFIG_SIZE]
  byte sdFlag, highlightedLine
  byte commentIndex, newCommentFlag
  byte codeType, codeValue, expectedChar
  byte sdProgramName[Header#MAX_NAME_SIZE + 1]
  byte downFlag, activeFile
  
DAT

designFileIndex         long -1
lowerZAmount            long Header#DEFAULT_Z_DISTANCE

'microStepMultiplier     long 1
'machineState            byte Header#INIT_STATE
stepPin                 byte Header#STEP_X_PIN, Header#STEP_Y_PIN, Header#STEP_Z_PIN
directionPin            byte Header#DIR_X_PIN, Header#DIR_Y_PIN, Header#DIR_Z_PIN
units                   byte Header#MILLIMETER_UNIT 
delimiter               byte 13, 10, ",", 9, 0
executeState            byte INIT_EXECUTE

programState            byte Header#FRESH_PROGRAM
microsteps              byte Header#DEFAULT_MICROSTEPS
machineState            byte Header#DEFAULT_MACHINE_STATE
previousProgram         byte Header#INIT_MAIN
homedFlag               byte Header#UNKNOWN_POSITION, 0[3]                          
positionX               long 0 '$80_00_00_00
positionY               long 0 '$80_00_00_00
positionZ               long 0 '$80_00_00_00
 
OBJ

  Header : "HeaderCnc"
  Pst : "Parallax Serial TerminalDat"
  Format : "StrFmt"
  'Sd[1]: "SdSmall" 
  'Cnc : "CncCommonMethods"
  'Motor : "MotorControl"
   
PUB Setup

  Pst.Start(115_200)
 
  repeat
    result := Pst.RxCount
    Pst.str(string(11, 13, "Press any key to continue starting program."))
    waitcnt(clkfreq / 2 + cnt)
  until result
  Pst.RxFlush

  TestMath

PUB PressToContinue
  
  Pst.str(string(11, 13, "Press to continue."))
  repeat
    result := Pst.RxCount
  until result
  Pst.RxFlush

PUB TtaMethod(N, X, localD)   ' return X*N/D where all numbers and result are positive =<2^31
  return (N / localD * X) + (binNormal(N//localD, localD, 31) ** (X*2))

PUB BinNormal (y, x, b) : f                  ' calculate f = y/x * 2^b
' b is number of bits
' enter with y,x: {x > y, x < 2^31, y <= 2^31}
' exit with f: f/(2^b) =<  y/x =< (f+1) / (2^b)
' that is, f / 2^b is the closest appoximation to the original fraction for that b.
  repeat b
    y <<= 1
    f <<= 1
    if y => x    '
      y -= x
      f++
  if y << 1 => x    ' Round off. In some cases better without.
      f++

PUB TestMath | localIndex, localDelay[2], previousDelay[2], motorIndex, delayTotal[2], {
} finishedFlag[2], difference

''C[i] = C[i-1] - ((2*C[i])/(4*i+1))
  minDelay[1] := TtaMethod(minDelay[0], maxDelay[1], maxDelay[0])
  delayTotal[0] := localDelay[0] := maxDelay[0]
  delayTotal[1] := localDelay[1] := maxDelay[1]
  Pst.str(string(11, 13, "delay[0][0] = "))
  {Pst.Dec(maxDelay / US_001)
  Pst.str(string(" us = "))}
  Pst.Dec(localDelay[0])
  'Pst.str(string(" ticks"))
  Pst.str(string(11, 13, "delay[1][0] = "))
  Pst.Dec(localDelay[1])
  longfill(@finishedFlag, 0, 2)
     
  localIndex := 1
  
  repeat
    repeat motorIndex from 0 to 1
      if finishedFlag[motorIndex]
        next
      previousDelay[motorIndex] := localDelay[motorIndex]
      if motorIndex
        difference := TtaMethod(2 * localDelay[motorIndex], maxDelay[1], {
        } maxDelay[0] * ((4 * localIndex) + 1))
      else
        difference := (2 * localDelay[motorIndex]) / ((4 * localIndex) + 1)
      localDelay[motorIndex] -= difference
      delayTotal[motorIndex] += localDelay[motorIndex]
      Pst.str(string(11, 13, "delay["))
      Pst.Dec(motorIndex)
      Pst.str(string("]["))
      Pst.Dec(localIndex)
      Pst.str(string("] = "))
      Pst.Dec(localDelay[motorIndex])
      Pst.str(string(", difference = "))
      Pst.Dec(difference)
      Pst.str(string(", fraction of previous = "))
      result := TtaMethod(localDelay[0], maxDelay[0], previousDelay[0])
      Pst.Dec(result)
      Pst.str(string(" / "))
      Pst.Dec(maxDelay[motorIndex])
      Pst.str(string(", total = "))
      Pst.Dec(delayTotal[motorIndex])
      if localDelay[motorIndex] =< minDelay[motorIndex]
        Pst.str(string(11, 13, "minDelay["))
        Pst.Dec(motorIndex)
        Pst.str(string("] reached in "))
        Pst.Dec(localIndex)
        Pst.str(string(" steps, minDelay = "))
        Pst.Dec(minDelay[motorIndex])
        finishedFlag[motorIndex] := 1
        PressToContinue
    Pst.str(string(11, 13, "total[1]/total[0] * 1000 = "))
    Pst.Dec(TtaMethod(delayTotal[1], 1000, delayTotal[0]))  
    ifnot localIndex // pauseInterval
      PressToContinue
    
    localIndex++  
  until finishedFlag[0] and finishedFlag[1] 'localDelay[0] > minDelay[0] or localDelay[1] > minDelay[1]

  Pst.str(string(11, 13, 11, 13, "Program Over"))
  repeat
  
DAT

pauseInterval           long 40
minDelay                long 80_000, 0-0 'US_001 * 1_000
maxDelay                long 1_600_000, 3_200_000 'US_001 * 20_000

