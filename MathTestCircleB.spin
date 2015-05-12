DAT programName         byte "MathTestCircleB", 0
CON
{
  By Duane Degn
  11 May 2015 
  This program tests an algorithm for generating appropriate delays to stepper motors.
  The resulting motion should produce an eighth of a circle.

}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq
  MS_001   = CLK_FREQ / 1_000
  US_001   = CLK_FREQ / 1_000_000

CON

  SCALED_MULTIPLIER = 1000
  X_AXIS = 0
  Y_AXIS = 1
  
VAR
  long axisDelay[2], xIndex, yIndex, radius, xSquared, ySquared
  long rSquared, fastAxis, slowAxis, previousY
  long xAtNextY, nextY, nextYSquared
  long fastStepsPerSlow, now, lastStep[2]
  long fullSpeedSteps[2], decelSteps[2]
  long accelPhase, lastAccel[2], activeAccel[2]
  long stepState[2], otherAxis[2], lastHalfStep[2], lastAccelCnt
  
OBJ

  Pst : "Parallax Serial TerminalDat"
  Format : "StrFmt"
   
PUB Setup

  Pst.Start(115_200)
 
  repeat
    result := Pst.RxCount
    Pst.str(string(11, 13, "Press any key to continue starting program."))
    waitcnt(clkfreq / 2 + cnt)
  until result
  Pst.RxFlush

  TestMath 

PUB TestMath
'' y = ^^((r * r) - (x * x))
'' This method only works for 1/8 of a circle.
  
  fastAxis := X_AXIS
  slowAxis := Y_AXIS
  otherAxis[fastAxis] := slowAxis
  otherAxis[slowAxis] := fastAxis
  
  axisDelay[fastAxis] := maxDelay
  axisDeltaDelay[fastAxis] := -defaultDeltaDelay
     
  radius := 400 
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
    
DAT

minDelay                long 100 * MS_001, 0-0
maxDelay                long 250 * MS_001, 0-0 
axisDeltaDelay          long 20 * MS_001, 0-0
defaultDeltaDelay       long 20 * MS_001, 0-0
timesToA                long 132
accelerationInterval    long 300 * MS_001   
