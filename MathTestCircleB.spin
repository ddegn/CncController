DAT programName         byte "MathTestCircle", 0
CON
{  Design Execute
  This sub program reads the design file from the SD card and executes the instructions.

  ******* Private Notes *******
 
  Change name from "DESIGNIN" to "EXECUTE_."
  Change name from "MathTest" to "MathTestCircle"
}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq
  MS_001   = CLK_FREQ / 1_000
  US_001   = CLK_FREQ / 1_000_000

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
  Cnc : "CncCommonMethods"
  'Motor : "MotorControl"
   
PUB Setup

  Pst.Start(115_200)
 
  repeat
    result := Pst.RxCount
    Pst.str(string(11, 13, "Press any key to continue starting program."))
    waitcnt(clkfreq / 2 + cnt)
  until result
  Pst.RxFlush

  TestMath 'TestLoop

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

PUB StartFine(fractionGuess)

  result := (fractionGuess + (fractionGuess >> 1)) >> 1
  
PUB NextGuess(fractionGuess, previousGuess)

  result := (fractionGuess + previousGuess) >> 1
  
PUB DecPoint(value, decimalPlaces) | localBuffer[4]

  result := Format.FDec(@localBuffer, value, 6, decimalPlaces)
  byte[result] := 0
  Pst.str(@localBuffer)
  
CON

  SCALED_MULTIPLIER = 1000
  MAX_DELAY = MS_001 * 20
  MIN_DELAY = Header#MIN_DELAY
  ACCELERATION_INTERVAL = MS_001 * 100
  DELAY_CHANGE = MS_001 
  X_AXIS = Header#X_AXIS
  Y_AXIS = Header#Y_AXIS
  SCALED_TAU = round(2.0 * pi * float(SCALED_MULTIPLIER))
  SCALED_TAU_OVER_8 = round(pi * float(SCALED_MULTIPLIER) / 4.0)
  SCALED_TAU_OVER_4 = round(pi * float(SCALED_MULTIPLIER) / 2.0)
  SCALED_TAU_OVER_2 = round(pi * float(SCALED_MULTIPLIER))
  SCALED_ROOT_2 = round(^^2.0 * float(SCALED_MULTIPLIER))
  
DAT

pauseInterval           long 40
minDelay                long 80_000, 0-0 'US_001 * 1_000
maxDelay                long 1_600_000, 3_200_000 'US_001 * 20_000

timeToA                 long 219

VAR
  long axisDelay[2], previousDelay[2], delayTotal[2], {
} axisDeltaDelay[2], xIndex, yIndex, radius, xSquared, ySquared, {
} rSquared, fastAxis, slowAxis, motorIndex, previousY, {
} xAtNextY, nextY, nextYSquared, fastStepsPerSlow, now, lastStep[2]
  long accelSteps[2], fullSpeedSteps[2], decelSteps[2]
  long accelPhase, lastAccel[2], activeAccel[2]
  long stepState[2]
  
PUB TestMath
'' There's a problem here with when the fast and slow axes switch.
'' y = ^^((r * r) - (x * x))
''
  
  fastAxis := Header#X_AXIS
  slowAxis := Header#Y_AXIS
  axisDelay[fastAxis] := MAX_DELAY
  axisDeltaDelay[fastAxis] := -DELAY_CHANGE
     
  radius := 1600
  rSquared := radius * radius

  'radius * SCALED_MULTIPLIER / SCALED_ROOT_2
  decelSteps[fastAxis] := radius ' total steps (reached at end of decel phase)
  
  accelSteps[fastAxis] := ComputeAccelIntervals(axisDelay[fastAxis], MIN_DELAY, {
  } DELAY_CHANGE, ACCELERATION_INTERVAL) '(reached at end of accel phase)

  fullSpeedSteps[fastAxis] := radius - accelSteps[fastAxis]
  ' all but final decel (reached at end of full speed phase)
  
  xIndex := 0
  xSquared := xIndex * xIndex
  yIndex := radius
  nextY := yIndex - 1
  nextYSquared := nextY * nextY
  xAtNextY := ^^(rSquared - nextYSquared)
  fastStepsPerSlow := ||(xAtNextY - xIndex)
  axisDelay[slowAxis] := axisDelay[fastAxis] * fastStepsPerSlow
  axisDeltaDelay[slowAxis] := axisDeltaDelay[fastAxis] * fastStepsPerSlow

  Pst.str(string(11, 13, "max delay = "))
  Pst.Dec(axisDelay[fastAxis])
  Pst.str(string(", min delay = "))
  Pst.Dec(MIN_DELAY)
  Pst.str(string(", delay change = "))
  Pst.Dec(DELAY_CHANGE)
  Pst.str(string(", accel interval = "))
  Pst.Dec(ACCELERATION_INTERVAL)
  Pst.str(string(", accelSteps = "))
  Pst.Dec(accelSteps[fastAxis])
     
  Pst.str(string(11, 13, "----------------------------"))

  Pst.str(string(11, 13, "Accelerate Phase"))
   
  now := cnt
  lastStep[0] := lastStep[1] := now
  lastHalfStep[fastAxis] -= axisDelay[fastAxis] / 2
  lastHalfStep[slowAxis] -= axisDelay[slowAxis] / 2
  
  repeat
    repeat
      now := cnt
      if now - lastHalfStep[fastAxis] > axisDelay[fastAxis]
        ComputeNextHalfStep(fastAxis)
      if now - lastHalfStep[slowAxis] > axisDelay[slowAxis]
        ComputeNextFastStep(slowAxis)
      if now - lastStep[fastAxis] > axisDelay[fastAxis]
        ComputeNextFastStep(fastAxis)
      if now - lastStep[slowAxis] > axisDelay[slowAxis]
        ComputeNextSlowStep
      if now - lastStep[slowAxis] > axisDelay[slowAxis]
        AdjustSpeed    
        
  repeat 'xIndex from 0 to 11
    xIndex++
    xSquared := xIndex * xIndex
    ySquared := rSquared - xSquared
    yIndex := ^^ySquared
    Pst.str(string(11, 13, "x = "))
    Pst.Dec(xIndex)
    Pst.str(string(", x^2 = "))
    Pst.Dec(xSquared)
    Pst.str(string(", y = "))
    Pst.Dec(yIndex)
    
  while xSquared < ySquared

  Pst.str(string(11, 13, "----------------------------"))
  
  repeat 'yIndex from 0 to 8
    yIndex--
    ySquared := yIndex * yIndex
    xSquared := rSquared - ySquared
    xIndex := ^^xSquared
    Pst.str(string(11, 13, "x = "))
    Pst.Dec(xIndex)
    Pst.str(string(", x^2 = "))
    Pst.Dec(xSquared)
    Pst.str(string(", y = "))
    Pst.Dec(yIndex)
  while yIndex > 0

  Pst.str(string(11, 13, "----------------------------"))
  
  repeat
  
PUB ComputeNextHalfStep(localAxis)

  if stepState[localAxis]
    return
  lastHalfStep[localAxis] += axisDelay[localAxis] 
  'outa[stepPin[localAxis] := 1
  stepState[localAxis] := 1
  
PUB ComputeNextFullStep(localAxis)

  ifnot stepState[localAxis]
    return
  lastStep[localAxis] += axisDelay[localAxis]
  xIndex[localAxis]++
  'outa[stepPin[localAxis] := 0
  stepState[localAxis] := 0

  if xIndex[Header#X_AXIS] == xAtNextY
    ifnot stepState[localAxis]
      Pst.str(string(7, 11, 13, "Error! Slow axis in wrong stepState!", 7))
      Pst.str(string(11, 13, "lastHalfStep[localAxis] = "))
      Pst.Dec(lastHalfStep[localAxis])
      repeat
      
  {if localAxis == slowAxis
    ComputeNextSlowStep(localAxis)
    return }
    
  if accelPhase == 0
    if xIndex[localAxis] > accelSteps[localAxis]
      Pst.str(string(11, 13, "Full Speed Phase"))
      accelPhase++
      lastAccel[localAxis] := axisDelay[localAxis]
      axisDelay[localAxis] := MIN_DELAY
      lastHalfStep[localAxis] := lastAccel[localAxis] - (MIN_DELAY / 2)
      '' Compute slow halfStep too?
      axisDeltaDelay[localAxis] := 0
  elseif accelPhase == 1
    if xIndex[localAxis] > fullSpeedSteps[localAxis]
      Pst.str(string(11, 13, "Decelerate Phase"))
      accelPhase++
      axisDelay[localAxis] := lastAccel[localAxis]
      axisDeltaDelay[localAxis] := DELAY_CHANGE 
  elseif accelPhase == 2
    if xIndex[localAxis] > decelSteps[localAxis]
      Pst.str(string(11, 13, "Done! Program Over"))
      repeat
PUB ComputeNextSlowStep

  lastStep[slowAxis] += axisDelay[slowAxis]
  xIndex[slowAxis] ++

  
      
      axisDelay[localAxis] := MIN_DELAY
      axisDeltaDelay[localAxis] := 0
      
PUB AdjustSpeed

  axisDelay[fastAxis] += axisDeltaDelay[fastAxis]
  axisDelay[slowAxis] += axisDeltaDelay[slowAxis]

PRI ComputeAccelIntervals(localMax, localMin, localChange, localAccelInterval) | nextAccel, {
} nextStep

  {{Pst.Str(string(11, 13, "ComputeAccelIntervals("))
  Pst.Dec(localMax)
  Pst.Str(string(", "))
  Pst.Dec(localMin)
  Pst.Str(string(", "))
  Pst.Dec(localChange)
  Pst.Str(string(", "))
  Pst.Dec(localAccelInterval)
  Pst.Str(string("), accelIntervals = "))
  Pst.Dec(accelIntervals) }}
  
  longfill(@nextAccel, 0, 2)

  repeat while localMax > localMin
    nextAccel += localAccelInterval
    {{Pst.Str(string(11, 13, "localMax = "))
    Pst.Dec(localMax)
    Pst.Str(string(", Min = "))
    Pst.Dec(localMin)}}
    
    repeat while nextStep < nextAccel
      result++
      nextStep += localMax
      {{Pst.Str(string(", intervals = "))
      Pst.Dec(result)
      Pst.Str(string(", nextStep = "))
      Pst.Dec(nextStep)}}
    localMax -= localChange  
  
  ''Pst.Str(string(11, 13, "accelIntervals = "))
  ''Pst.Dec(result)
      
    'ifnot sineIndex // $200 '32
      'Cnc.PressToContinue
 
      
    
   
   { iFactor[motorIndex] := nNum[motorIndex] / nDenom[motorIndex]
    Pst.str(string(11, 13, "delay["))
    Pst.Dec(motorIndex)
    Pst.str(string("][0] = "))
    Pst.Dec(axisDelay[motorIndex])
    Pst.str(string(11, 13, "minDelay["))
    Pst.Dec(motorIndex)
    Pst.str(string("] = "))
    Pst.Dec(minDelay[motorIndex])
    Pst.str(string(11, 13, "maxDelay["))
    Pst.Dec(motorIndex)
    Pst.str(string("] = "))
    Pst.Dec(maxDelay[motorIndex])
    Pst.str(string(11, 13, "nNum["))
    Pst.Dec(motorIndex)
    Pst.str(string("] = "))
    Pst.Dec(nNum[motorIndex])
    Pst.str(string(11, 13, "nDenom["))
    Pst.Dec(motorIndex)
    Pst.str(string("] = "))
    Pst.Dec(nDenom[motorIndex])
    Pst.str(string(11, 13, "iFactor["))
    Pst.Dec(motorIndex)
    Pst.str(string("] = "))
    Pst.Dec(iFactor[motorIndex])

  longfill(@finishedFlag, 0, 4)
     
  localIndex := 1
  
  repeat
    repeat motorIndex from 0 to 1
      if finishedFlag[motorIndex]
        next
      previousDelay[motorIndex] := axisDelay[motorIndex]
      difference0 := (2 * axisDelay[motorIndex]) / {
      } (TtaMethod(nNum[motorIndex], localIndex, nDenom[motorIndex]) + 1) <# 1
      
      difference1 := (2 * axisDelayI[motorIndex]) / ((iFactor[motorIndex] * localIndex) + 1) <# 1
      axisDelay[motorIndex] -= difference0
      axisDelayI[motorIndex] -= difference1
      delayTotal[motorIndex] += axisDelay[motorIndex]
      delayTotalI[motorIndex] += axisDelayI[motorIndex]
      Pst.str(string(11, 13, "delay["))
      Pst.Dec(motorIndex)
      Pst.str(string("]["))
      Pst.Dec(localIndex)
      Pst.str(string("] = "))
      Pst.Dec(axisDelay[motorIndex])
      Pst.str(string(", difference0 = "))
      Pst.Dec(difference0)
      Pst.str(string(", delayI = "))
      Pst.Dec(axisDelayI[motorIndex])
      Pst.str(string(", difference1 = "))
      Pst.Dec(difference1)
      'result := TtaMethod(axisDelay[0], maxDelay[0], previousDelay[0])
      {Pst.Dec(result)
      Pst.str(string(" / "))
      Pst.Dec(maxDelay[motorIndex])
      Pst.str(string(", total = "))
      Pst.Dec(delayTotal[motorIndex]) }
      if axisDelay[motorIndex] =< minDelay[motorIndex] and finishedFlag[motorIndex] == 0
        Pst.str(string(11, 13, "I minDelay["))
        Pst.Dec(motorIndex)
        Pst.str(string("] reached in "))
        Pst.Dec(localIndex)
        Pst.str(string(" steps, minDelay = "))
        Pst.Dec(minDelay[motorIndex])
        finalTotal[motorIndex] := delayTotal[motorIndex]
        finalStepsI[motorIndex] := localIndex 
        finishedFlag[motorIndex] := 1
        PressToContinue
      if axisDelayI[motorIndex] =< minDelay[motorIndex] and finishedFlagI[motorIndex] == 0
        Pst.str(string(11, 13, "  minDelay["))
        Pst.Dec(motorIndex)
        Pst.str(string("] reached in "))
        Pst.Dec(localIndex)
        Pst.str(string(" steps, minDelay = "))
        Pst.Dec(minDelay[motorIndex])
        finalTotalI[motorIndex] := delayTotalI[motorIndex]
        finalSteps[motorIndex] := localIndex
        finishedFlagI[motorIndex] := 1
        PressToContinue

    'Pst.str(string(11, 13, "total[1]/total[0] * 1000 = "))
    'Pst.Dec(TtaMethod(delayTotal[1], 1000, delayTotal[0]))  
    ifnot localIndex // pauseInterval
      PressToContinue
    
    localIndex++  
  until finishedFlag[0] and finishedFlag[1] and finishedFlagI[0] and finishedFlagI[1]

  repeat motorIndex from 0 to 1
    Pst.str(string(11, 13, "maxDelay["))
    Pst.Dec(motorIndex)
    Pst.str(string("] = "))
    Pst.Dec(maxDelay[motorIndex])
    Pst.str(string(", minDelay = "))
    Pst.Dec(minDelay[motorIndex])

    Pst.str(string(11, 13, "finalTotal = "))
    Pst.Dec(finalTotal[motorIndex])
    Pst.str(string(", finalTotalI = "))
    Pst.Dec(finalTotalI[motorIndex])
    Pst.str(string(11, 13, "finalSteps["))
    Pst.Dec(motorIndex)
    Pst.str(string("] = "))
    Pst.Dec(finalSteps[motorIndex])
    Pst.str(string(", finalStepsI = "))
    Pst.Dec(finalStepsI[motorIndex])

    Pst.str(string(11, 13, "nNum["))
    Pst.Dec(motorIndex)
    Pst.str(string("] = "))
    Pst.Dec(nNum[motorIndex])
    Pst.str(string(", nDenom = "))
    Pst.Dec(nDenom[motorIndex])
    Pst.str(string(", iFactor = "))
    Pst.Dec(iFactor[motorIndex])     }
 
