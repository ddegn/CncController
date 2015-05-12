DAT programName         byte "MathTestCircle", 0
CON
{  
  This program tests an algorithm for generating appropriate delays to stepper motors.
  The resulting motion should produce an eighth of a circle.

}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq
  MS_001   = CLK_FREQ / 1_000
  US_001   = CLK_FREQ / 1_000_000

OBJ

  'Header : "HeaderCnc"
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

CON

  SCALED_MULTIPLIER = 1000
  X_AXIS = 0
  Y_AXIS = 1
  SCALED_TAU = round(2.0 * pi * float(SCALED_MULTIPLIER))
  SCALED_TAU_OVER_8 = round(pi * float(SCALED_MULTIPLIER) / 4.0)
  SCALED_TAU_OVER_4 = round(pi * float(SCALED_MULTIPLIER) / 2.0)
  SCALED_TAU_OVER_2 = round(pi * float(SCALED_MULTIPLIER))
  SCALED_ROOT_2 = round(^^2.0 * float(SCALED_MULTIPLIER))
  
DAT

minDelay                long 100 * MS_001, 0-0
maxDelay                long 250 * MS_001, 0-0 
axisDeltaDelay          long 20 * MS_001, 0-0
defaultDeltaDelay       long 20 * MS_001, 0-0
timesToA                long 132
accelerationInterval    long 300 * MS_001   

VAR
  long axisDelay[2], { 
} xIndex, yIndex, radius, xSquared, ySquared, {
} rSquared, fastAxis, slowAxis, previousY, { 
} xAtNextY, nextY, nextYSquared, fastStepsPerSlow, now, lastStep[2]
 
  long fullSpeedSteps[2], decelSteps[2]
  long accelPhase, lastAccel[2], activeAccel[2]
  long stepState[2], otherAxis[2], lastHalfStep[2], lastAccelCnt
  
PUB TestMath
'' There's a problem here with when the fast and slow axes switch.
'' y = ^^((r * r) - (x * x))
''
  
  fastAxis := X_AXIS
  slowAxis := Y_AXIS
  otherAxis[fastAxis] := slowAxis
  otherAxis[slowAxis] := fastAxis
  
  axisDelay[fastAxis] := maxDelay
  axisDeltaDelay[fastAxis] := -defaultDeltaDelay
     
  radius := 400 '1600
  rSquared := radius * radius

  decelSteps[fastAxis] := radius ' total steps (reached at end of decel phase)
  
  timesToA := ComputeAccelIntervals(axisDelay[fastAxis], minDelay, {
  } defaultDeltaDelay, accelerationInterval) '(reached at end of accel phase)

  fullSpeedSteps[fastAxis] := radius - timesToA
  ' all but final decel (reached at end of full speed phase)
  
  xIndex := 0
  xSquared := xIndex * xIndex
  nextY := radius
  
  ComputeNextY

  Pst.str(string(11, 13, "max delay = "))
  Pst.Dec(axisDelay[fastAxis] / MS_001)
  Pst.str(string(" ms, min delay = "))
  Pst.Dec(minDelay / MS_001)
  Pst.str(string(" ms, delay change = "))
  Pst.Dec(axisDeltaDelay / MS_001)
  Pst.str(string(" ms, accel interval = "))
  Pst.Dec(accelerationInterval / MS_001)
  Pst.str(string(" ms, timesToA = "))
  Pst.Dec(timesToA)
     
  Pst.str(string(11, 13, "----------------------------"))

  Pst.str(string(11, 13, "Accelerate Phase"))
   
  now := cnt
  lastHalfStep[0] := lastHalfStep[1] := lastStep[0] := lastStep[1] := now
  lastHalfStep[fastAxis] -= axisDelay[fastAxis] / 2
  lastHalfStep[slowAxis] -= axisDelay[slowAxis] / 2
  lastAccelCnt := now
  repeat
    
    now := cnt
    if now - lastHalfStep[fastAxis] > axisDelay[fastAxis]
      'Pst.str(string(11, 13, "n-Hf= "))
      'Pst.Dec((now - lastHalfStep[fastAxis]) / MS_001)
      
      ComputeNextHalfStep(fastAxis)
    if now - lastHalfStep[slowAxis] > axisDelay[slowAxis]
      Pst.str(string(11, 13, "n-Hs= "))
      Pst.Dec((now - lastHalfStep[slowAxis]) / MS_001)
      ComputeNextHalfStep(slowAxis)
    if now - lastStep[fastAxis] > axisDelay[fastAxis]
      'Pst.str(string(11, 13, "n-f= "))
      'Pst.Dec((now - lastStep[fastAxis]) / MS_001)
      ComputeNextFullStep(fastAxis)
     
    if now - lastAccelCnt > accelerationInterval
      'Pst.str(string(11, 13, "n-a= "))
      'Pst.Dec((now - lastAccelCnt) / MS_001)
      lastAccelCnt += accelerationInterval
      AdjustSpeed
  while xIndex < yIndex

  Pst.str(string(11, 13, "x = "))
  Pst.Dec(xIndex)
  Pst.str(string(", y = "))
  Pst.Dec(yIndex)
  Pst.str(string(11, 13, "Done! Program Over"))
  repeat

PUB ComputeNextHalfStep(localAxis)

  if stepState[localAxis]
    Pst.str(string(11, 13, "ComputeNextHalfStep, stepState[", 7))
    Pst.Dec(localAxis)
    Pst.Str(string("] = "))
    Pst.Dec(stepState[localAxis])
    return
  if localAxis == slowAxis
    Pst.str(string(11, 13, "Slow Axis Half Step", 7))

  lastHalfStep[localAxis] += axisDelay[localAxis]
  {Pst.str(string(11, 13, "lastHalfStep["))
  Pst.Dec(localAxis)
  Pst.Str(string("] = "))
  Pst.Dec(lastHalfStep[localAxis] / MS_001)
  Pst.Str(string(" ms"))  }
      
  'outa[stepPin[localAxis] := 1
  stepState[localAxis] := 1
  
PUB ComputeNextFullStep(localAxis)

  {Pst.str(string(11, 13, "ComputeNextFullStep("))
  Pst.Dec(localAxis)
  Pst.Str(string(")"))  }
  ifnot stepState[localAxis]
    Pst.str(string(11, 13, "ComputeNextFullStep, stepState[", 7))
    Pst.Dec(localAxis)
    Pst.Str(string("] = "))
    Pst.Dec(stepState[localAxis])
    return             ' get half step first
  lastStep[localAxis] += axisDelay[localAxis]
  xIndex[localAxis]++
  'outa[stepPin[localAxis] := 0
  stepState[localAxis] := 0
  if xIndex == radius / 2
    Pst.str(string(11, 13, "Half Radius! *************************"))
  elseif xIndex == yIndex
    Pst.str(string(11, 13, "***********************************************************************"))
    Pst.str(string(11, 13, "X Equals Y ************************************************************"))
    Pst.str(string(11, 13, "***********************************************************************"))
    'Cnc.PressToContinue
  elseif xIndex == 283
    Pst.str(string(11, 13, "***********************************************************************"))
    Pst.str(string(11, 13, "X Equals 283 **********************************************************"))
    Pst.str(string(11, 13, "***********************************************************************"))
    'Cnc.PressToContinue
  if xIndex[localAxis] == xAtNextY
    ifnot stepState[otherAxis[localAxis]]
      Pst.str(string(7, 11, 13, "Error! Slow axis in wrong stepState!", 7))
      Pst.str(string(11, 13, "lastHalfStep[otherAxis[localAxis]] = "))
      Pst.Dec(lastHalfStep[otherAxis[localAxis]] / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "lastHalfStep[otherAxis[localAxis]] = "))
      Pst.Dec(lastHalfStep[otherAxis[localAxis]] / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "next half step should be = "))
      Pst.Dec((lastHalfStep[otherAxis[localAxis]] + axisDelay[otherAxis[localAxis]]) / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "cnt = "))
      Pst.Dec(cnt / MS_001)
      Pst.Str(string(" ms"))
      repeat

    'outa[stepPin[otherAxis[localAxis]]
    stepState[otherAxis[localAxis]] := 0
    ComputeNextY
    if xIndex == yIndex
      Pst.str(string(11, 13, "X Equals Y *************************"))

  if accelPhase == 0
    if xIndex[localAxis] > timesToA
      Pst.str(string(11, 13, "Full Speed Phase ********************"))
      accelPhase++
      lastAccel[localAxis] := axisDelay[localAxis]
      axisDelay[localAxis] := minDelay
      'lastHalfStep[localAxis] := lastAccel[localAxis] - (minDelay / 2)
      lastHalfStep[localAxis] := now - (minDelay / 2)
      '' Compute slow halfStep too?  No not yet.
      axisDeltaDelay[localAxis] := 0
      axisDeltaDelay[otherAxis[localAxis]] := 0
  elseif accelPhase == 1
    if xIndex[localAxis] > fullSpeedSteps[localAxis]
      Pst.str(string(11, 13, "Decelerate Phase"))
      accelPhase++
      axisDelay[localAxis] := lastAccel[localAxis]
      axisDeltaDelay[localAxis] := defaultDeltaDelay
      lastHalfStep[localAxis] := now - (axisDelay[localAxis] / 2)
  elseif accelPhase == 2
    if xIndex[localAxis] > decelSteps[localAxis]
      Pst.str(string(11, 13, "Done! Program Over"))
      repeat
      
  Pst.str(string(11, 13, "x = "))
  Pst.Dec(xIndex)
  Pst.str(string(", y = "))
  Pst.Dec(yIndex)
  
PUB ComputeNextY

  Pst.str(string(11, 13, "ComputeNextY"))
  
  yIndex := nextY
  nextY := yIndex - 1
  nextYSquared := nextY * nextY
  xAtNextY := ^^(rSquared - nextYSquared)
  fastStepsPerSlow := ||(xAtNextY - xIndex)
  axisDelay[slowAxis] := axisDelay[fastAxis] * fastStepsPerSlow
  axisDeltaDelay[slowAxis] := axisDeltaDelay[fastAxis] * fastStepsPerSlow
  lastHalfStep[slowAxis] := now - (axisDelay[slowAxis] / 2)
  
  Pst.str(string(11, 13, "axisDelay[slowAxis] = "))
  Pst.Dec(axisDelay[slowAxis] / MS_001)
  Pst.Str(string(" ms"))
  Pst.str(string(11, 13, "axisDeltaDelay[slowAxis] = "))
  Pst.Dec(axisDeltaDelay[slowAxis] / MS_001)
  Pst.Str(string(" ms"))

  Pst.str(string(11, 13, "nextY = "))
  Pst.Dec(nextY)
  Pst.str(string(11, 13, "xAtNextY = "))
  Pst.Dec(xAtNextY)

PUB AdjustSpeed

  axisDelay[fastAxis] += axisDeltaDelay[fastAxis]
  axisDelay[slowAxis] += axisDeltaDelay[slowAxis]
  {Pst.str(string(11, 13, "AdjustSpeed = axisDelay[ "))
  Pst.Dec(fastAxis)
  Pst.Str(string("] = "))
  Pst.Dec(axisDelay[fastAxis] / MS_001)
  Pst.Str(string(" ms, axisDelay[ "))
  Pst.Dec(slowAxis)
  Pst.Str(string("] = "))
  Pst.Dec(axisDelay[slowAxis] / MS_001)
  Pst.Str(string(" ms"))
  Pst.str(string(11, 13, "axisDeltaDelay[ "))
  Pst.Dec(fastAxis)
  Pst.Str(string("] = "))
  Pst.Dec(axisDeltaDelay[fastAxis] / MS_001)
  Pst.Str(string(" ms, axisDeltaDelay[ "))
  Pst.Dec(slowAxis)
  Pst.Str(string("] = "))
  Pst.Dec(axisDeltaDelay[slowAxis] / MS_001)
  Pst.Str(string(" ms"))    }
  
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

PUB TestLoop : difference

  repeat
    TestDifference(++difference)
    startGuesss++
    PressToContinue
    
PUB TestDifference(difference) | slowSteps, targetSlowSteps, lowGuess, highGuess, fractionGuess, {
} fineAdjustFlag, previousGuess, tooHigh, tooLow, lowSteps, highSteps, startFlag

  targetSlowSteps := TtaMethod(timeToA, maxDelay[0], maxDelay[1])
  longfill(@lowGuess, startGuesss, 3)
  fineAdjustFlag := 0
  lowSteps := lowGuess := 99999
  
  highSteps := highGuess := 0
  startFlag := 0
  
  repeat
    previousGuess := fractionGuess
    if startFlag
      Pst.str(string(11, 13, "final fractionGuess = "))
      Pst.Dec(fractionGuess)
      Pst.str(string(11, 13, "slowSteps = "))
      Pst.Dec(slowSteps)
      Pst.str(string(", targetSlowSteps = "))
      Pst.Dec(targetSlowSteps)
      Pst.str(string(", fast steps = "))
      Pst.Dec(timeToA)
      Pst.str(string(11, 13, "fineAdjustFlag = "))
      Pst.Dec(fineAdjustFlag)
      Pst.str(string(", tooHigh = "))
      Pst.Dec(tooHigh)
      Pst.str(string(", tooLow = "))
      Pst.Dec(tooLow)
      {Pst.str(string(11, 13, "lowSteps was = "))
      Pst.Dec(lowSteps)
      Pst.str(string(", highSteps was = "))
      Pst.Dec(highSteps)
      Pst.str(string(11, 13, "lowGuess was = "))
      Pst.Dec(lowGuess)
      Pst.str(string(", highGuess was = "))
      Pst.Dec(highGuess) }
      if fractionGuess < lowGuess
        lowGuess := fractionGuess
      if fractionGuess > highGuess
        highGuess := fractionGuess  
      if slowSteps < lowSteps
        lowSteps := slowSteps
      if slowSteps > highSteps
        highSteps := slowSteps  
      Pst.str(string(11, 13, "slowSteps = "))
      Pst.Dec(slowSteps)
      Pst.str(string(11, 13, "targetSlowSteps = "))
      Pst.Dec(targetSlowSteps)
      {Pst.str(string(11, 13, "lowSteps is = "))
      Pst.Dec(lowSteps)
      Pst.str(string(", highSteps is = "))
      Pst.Dec(highSteps)
      Pst.str(string(11, 13, "lowGuess is = "))
      Pst.Dec(lowGuess)
      Pst.str(string(", highGuess is = "))
      Pst.Dec(highGuess)   }
      'PressToContinue
    
   ' slowSteps := TestMath(fractionGuess, difference)
    startFlag := 1
    Pst.str(string(11, 13, "final fractionGuess = "))
    Pst.Dec(fractionGuess)
    Pst.str(string(11, 13, "slowSteps = "))
    Pst.Dec(slowSteps)
    Pst.str(string(", targetSlowSteps = "))
    Pst.Dec(targetSlowSteps)
    Pst.str(string(", fast steps = "))
    Pst.Dec(timeToA)
    Pst.str(string(11, 13, "fineAdjustFlag = "))
    Pst.Dec(fineAdjustFlag)
    Pst.str(string(", tooHigh = "))
    Pst.Dec(tooHigh)
    Pst.str(string(", tooLow = "))
    Pst.Dec(tooLow)
    'PressToContinue
    if fineAdjustFlag
      if slowSteps < targetSlowSteps ' converges too fast need a higher guess
        tooLow := fractionGuess
        fractionGuess := NextGuess(fractionGuess, tooHigh)
        Pst.str(string(11, 13, "fine toolow = "))
        Pst.Dec(tooLow)
      elseif slowSteps > targetSlowSteps ' converges too slowly a lower guess should be used.
        tooHigh := fractionGuess
        fractionGuess := NextGuess(fractionGuess, tooLow)
        Pst.str(string(11, 13, "fine tooHigh = "))
        Pst.Dec(tooHigh)
      else
        quit  
      if fractionGuess == previousGuess
        Pst.str(string(11, 13, 7, "Error, fractionGuess == previousGuess"))
        Pst.str(string(11, 13, "Did not converge with difference = "))
        Pst.Dec(difference)
        Pst.str(string(11, 13, "Try again."))
        return

    elseif slowSteps < targetSlowSteps
      tooLow := fractionGuess
      fractionGuess <<= 1
      Pst.str(string(11, 13, "course toolow = "))
      Pst.Dec(tooLow)      
    elseif slowSteps > targetSlowSteps
      tooHigh := fractionGuess 
      fractionGuess := StartFine(fractionGuess)
      fineAdjustFlag := 1
      Pst.str(string(11, 13, "course tooHigh = "))
      Pst.Dec(tooHigh)
    Pst.str(string(11, 13, "new fractionGuess = "))
    Pst.Dec(fractionGuess)  
  until slowSteps == targetSlowSteps

  Pst.str(string(11, 13, "final fractionGuess = "))
  Pst.Dec(fractionGuess)
  Pst.str(string(11, 13, "slowSteps = "))
  Pst.Dec(slowSteps)
  Pst.str(string(11, 13, "targetSlowSteps = "))
  Pst.Dec(targetSlowSteps)
  Pst.str(string(11, 13, "fast steps = "))
  Pst.Dec(timeToA)
  
  Pst.str(string(11, 13, 11, 13, "Program Over"))
  repeat

PUB StartFine(fractionGuess)

  result := (fractionGuess + (fractionGuess >> 1)) >> 1
  
PUB NextGuess(fractionGuess, previousGuess)

  result := (fractionGuess + previousGuess) >> 1
  
PUB DecPoint(value, decimalPlaces) | localBuffer[4]

  result := Format.FDec(@localBuffer, value, 6, decimalPlaces)
  byte[result] := 0
  Pst.str(@localBuffer)
  
PUB TestMath | localDelay[2], previousDelay[2], delayTotal[2], {
} localDelayI[2], radius, rSquared, xIndex, xSquared, ySquared, yIndex

'' y = ^^((r * r) - (x * x))
'' 
  radius := 16
  rSquared :=  radius * radius

  xIndex := 0
  'xSquared := 0
  'ySquared := rSquared
  
  Pst.str(string(11, 13, "----------------------------"))

  repeat 'xIndex from 0 to 11
    xSquared := xIndex * xIndex
    ySquared := rSquared - xSquared
    yIndex := ^^ySquared
    Pst.str(string(11, 13, "x = "))
    Pst.Dec(xIndex)
    Pst.str(string(", x^2 = "))
    Pst.Dec(xSquared)
    Pst.str(string(", y = "))
    Pst.Dec(yIndex)
    xIndex++
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
    
    'ifnot sineIndex // $200 '32
      'Cnc.PressToContinue
 
      
    {localDelay[motorIndex] := maxDelay[motorIndex]
    delayTotal[motorIndex] := maxDelay[motorIndex]
    localDelayI[motorIndex] := maxDelay[motorIndex]
    delayTotalI[motorIndex] := localDelayI[motorIndex]   
   
    iFactor[motorIndex] := nNum[motorIndex] / nDenom[motorIndex]
    Pst.str(string(11, 13, "delay["))
    Pst.Dec(motorIndex)
    Pst.str(string("][0] = "))
    Pst.Dec(localDelay[motorIndex])
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
      previousDelay[motorIndex] := localDelay[motorIndex]
      difference0 := (2 * localDelay[motorIndex]) / {
      } (TtaMethod(nNum[motorIndex], localIndex, nDenom[motorIndex]) + 1) <# 1
      
      difference1 := (2 * localDelayI[motorIndex]) / ((iFactor[motorIndex] * localIndex) + 1) <# 1
      localDelay[motorIndex] -= difference0
      localDelayI[motorIndex] -= difference1
      delayTotal[motorIndex] += localDelay[motorIndex]
      delayTotalI[motorIndex] += localDelayI[motorIndex]
      Pst.str(string(11, 13, "delay["))
      Pst.Dec(motorIndex)
      Pst.str(string("]["))
      Pst.Dec(localIndex)
      Pst.str(string("] = "))
      Pst.Dec(localDelay[motorIndex])
      Pst.str(string(", difference0 = "))
      Pst.Dec(difference0)
      Pst.str(string(", delayI = "))
      Pst.Dec(localDelayI[motorIndex])
      Pst.str(string(", difference1 = "))
      Pst.Dec(difference1)
      'result := TtaMethod(localDelay[0], maxDelay[0], previousDelay[0])
      {Pst.Dec(result)
      Pst.str(string(" / "))
      Pst.Dec(maxDelay[motorIndex])
      Pst.str(string(", total = "))
      Pst.Dec(delayTotal[motorIndex]) }
      if localDelay[motorIndex] =< minDelay[motorIndex] and finishedFlag[motorIndex] == 0
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
      if localDelayI[motorIndex] =< minDelay[motorIndex] and finishedFlagI[motorIndex] == 0
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
  repeat
  
DAT

pauseInterval           long 40
minDelay                long 80_000, 0-0 'US_001 * 1_000
maxDelay                long 1_600_000, 3_200_000 'US_001 * 20_000

timeToA                 long 219
startGuesss             long 2 '64