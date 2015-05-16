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

CON

  SCALED_MULTIPLIER = 10_000
  SCALED_DECIMAL_PLACES = 4
  
  X_AXIS = 0
  Y_AXIS = 1
  SCALED_TAU = round(2.0 * pi * float(SCALED_MULTIPLIER))
  SCALED_TAU_OVER_8 = round(pi * float(SCALED_MULTIPLIER) / 4.0)
  SCALED_TAU_OVER_4 = round(pi * float(SCALED_MULTIPLIER) / 2.0)
  SCALED_TAU_OVER_2 = round(pi * float(SCALED_MULTIPLIER))
  SCALED_ROOT_2 = round(^^2.0 * float(SCALED_MULTIPLIER))

  PIECES_IN_CIRCLE = 8

  ' accelPhase enumeration
  #0, ACCEL_PHASE, FULL_SPEED_PHASE, DECEL_PHASE
  
  QUOTE = 34

VAR

  long xIndex, yIndex, xSquared, ySquared
  long rSquared, previousY
  long fastAtNextSlow, nextSlow, nextSlowSquared
  long fastStepsPerSlow
  long fullSpeedSteps, decelSteps
  long lastAccel, activeAccel[2]
  long lastAccelCnt
  long previousCnt, newCnt, differenceCnt
  'long missedHalfCountFast, missedHalfCountSlow
  'long pLastHalfStepFast, pLastHalfStepSlow
  'long pLastStepFast, pLastStepSlow
  
DAT

globalIterations        long 8
defaultDelayChange      long -20 * MS_001 / 10
minDelay                long 100 * MS_001 / 10
maxDelay                long 250 * MS_001 / 10
delayFast               long 250 * MS_001 / 10
delaySlow               long 0-0
delayChangeFast         long -20 * MS_001 / 10
delayChangeSlow         long 0-0 
lastHalfStepFast        long 0-0  
lastHalfStepSlow        long 0-0
lastStepFast            long 0-0
'lastStepSlow            long 0-0
stepStateFast           long 0-0  
stepStateSlow           long 0-0
'defaultDeltaDelay       long 20 * MS_001, 0-0
timesToA                long 132
accelerationInterval    long 300 * MS_001   
radius                  long 400
startOctant             long 0
'distance                long 8
'centerX                 long 0
'centerY                 long 400
'stepsToTakeX            long 0-0
'stepsToTakeY            long 0-0
directionX              long 1[2], -1[4], 1[2]
directionY              long 1[4], -1[4]
previousDirectionX      long 0-0
previousDirectionY      long 0-0
fastAxisByOctant        long 0, 1[2], 0[2], 1[2], 0
slowAxisByOctant        long 1, 0[2], 1[2], 0[2], 1
otherAxis               long 1, 0
presentFast             long 0-0
presentSlow             long 0-0
presentDirectionX       long 0-0
presentDirectionY       long 0-0
accelPhase              long ACCEL_PHASE
activeOctant            long 0-0
toTakeFullSpeedTrigger  long 0-0
toTakeDecelTrigger      long 0-0
accelAxis               long 0-0
decelAxis               long 0-0
stepPinX                long Header#STEP_X_PIN
stepPinY                long Header#STEP_Y_PIN
dirPinX                 long Header#DIR_X_PIN     
dirPinY                 long Header#DIR_Y_PIN
stepPinFast             long 0-0
stepPinSlow             long 0-0
dirPinFast              long 0-0
dirPinSlow              long 0-0
octantSizeX             long 0-0[8]
octantSizeY             long 0-0[8]
fullSpeedOctant         long 0-0
decelOctant             long 0-0
endOctant               long 0-0
fastCount               long 0
spiralScale             long 1000
debugFlag               long 0
'spiralR                 long  1,  2,  3,  5,  8, 13, 21,  34
'startX                  long  0,  2,  0, -5,  0, 13,  0, -34
'startY                  long -1,  0,  3,  0, -8,  0, 21,   0
'directionX              long  1, -1, -1,  1,  1, -1, -1,   1
'directionY              long  1,  1, -1, -1,  1,  1, -1,  -1
' motion in ccw direction to center
  '' Which eight of the circle does the move start? (Piece of Eight)
  '' 4) Cx>0, Cy<0        \4|3/  3) Cx<0, Cy<0
  '' 5) Cx>R/root2, Cy<0  5\|/2  2) Cx<-R/root2, Cy<0
  ''                     ---*---
  '' 6) Cx>R/root2, Cy>0  6/|\1  1) Cx<-R/root2, Cy>0
  '' 7) Cx>0, Cy>0        /7|0\  0) Cx<0, Cy>0

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

  Cnc.Start
  waitcnt(clkfreq * 2 + cnt) 
  'Pst.Clear
  
  dira[Header#STEP_X_PIN] := 1           
  dira[Header#DIR_X_PIN] := 1           
  dira[Header#STEP_Y_PIN] := 1           
  dira[Header#DIR_Y_PIN] := 1           
  
  InitSteppers(0, 1)
  Pst.Clear

  {Pst.Str(string(11, 13, "Drive X one revolution."))
  repeat 3200
    waitcnt(clkfreq / 200 + cnt)
    outa[Header#STEP_X_PIN] := 1
    waitcnt(clkfreq / 200 + cnt)
    outa[Header#STEP_X_PIN] := 0   }
 
    
  timesToA := ComputeAccelIntervals(maxDelay, minDelay, ||defaultDelayChange, accelerationInterval)
  
  MainLoop

PRI InitSteppers(firstAxis, lastAxis)

  repeat result from firstAxis to lastAxis
    Cnc.ResetDrv8711(result)
    Pst.Str(string(11, 13, "Reset axis #"))
    Pst.Dec(result)   
    Pst.Char(".")

    Pst.Str(string(11, 13, "Reading registers prior to setup."))
    Cnc.ShowRegisters(result)
    
    Cnc.SetupDvr8711(result, Header#DEFAULT_DRIVE_DRV8711, Header#DEFAULT_MICROSTEP_CODE_DRV8711, {
    } Header#DEFAULT_DECAY_MODE_DRV8711, Header#DEFAULT_GATE_SPEED_DRV8711, {
    } Header#DEFAULT_GATE_DRIVE_DRV8711, Header#DEFAULT_DEADTIME_DRV8711)
    Pst.Str(string(11, 13, "Setup finished axis #"))
    Pst.Dec(result)   
    Pst.Char(".")
    Cnc.PressToContinue
    Pst.Str(string(11, 13, "Reading registers."))
    Cnc.ShowRegisters(result)

PUB MainLoop

  'ExecuteSpiral
  repeat
    Pst.Home
    Pst.Str(string(11, 13, "spiralScale = "))
    Pst.Dec(spiralScale)
    Pst.str(string(11, 13, "startOctant = "))
    Pst.Dec(startOctant)
    Pst.str(string(", globalIterations = "))
    Pst.Dec(globalIterations)
    Pst.Str(string(11, 13, "acceleration steps = "))
    Pst.Dec(timesToA)
    Pst.Str(string(11, 13, "Debug O"))
      if debugFlag
        Pst.Str(string("n"))
      else
        Pst.Str(string("ff"))
    Pst.Str(string(11, 13, "Machine waiting for input."))
    
    Pst.Str(string(11, 13, "Press ", QUOTE, "s", QUOTE, " to change Spiral scaler.")) 
    'Pst.Str(string(11, 13, "Press ", QUOTE, "x", QUOTE, " to change center's X coordinate."))
    'Pst.Str(string(11, 13, "Press ", QUOTE, "y", QUOTE, " to change center's Y coordinate."))
    'Pst.Str(string(11, 13, "Press ", QUOTE, "s", QUOTE, " to change Start octant. (0 bottom center and ccw from there.)"))
    Pst.Str(string(11, 13, "Press ", QUOTE, "d", QUOTE, " to toggle Debug flag."))
    Pst.Str(string(11, 13, "Press ", QUOTE, "i", QUOTE, " to change number of Iterations in the spiral."))
    Pst.Str(string(11, 13, "Press ", QUOTE, "e", QUOTE, " Execute spiral with current parameters."))
    Pst.Char(11)
    Pst.Char(13)
    Pst.ClearBelow
    result := Pst.RxCount
  
    CheckMenu(result)
    
PUB CheckMenu(tempValue) 

  if tempValue
    tempValue := Pst.CharIn
  else
    return
      
  case tempValue
    "s", "S":
      Pst.Str(string(11, 13, "Enter new radius scale."))
      spiralScale := Pst.DecIn
    "d", "D":
      !debugFlag
      Pst.Str(string(11, 13, "Debug O"))
      if debugFlag
        Pst.Str(string("n"))
      else
        Pst.Str(string("ff"))
      
    ' 
    '  Pst.Str(string(11, 13, "Enter new start octant."))
      'startOctant := Pst.DecIn
    "i", "I": 
      Pst.Str(string(11, 13, "Enter number of iterations."))
      globalIterations := Pst.DecIn
    "e", "E": 
      Pst.Str(string(11, 13, "Executing Spiral"))
      ExecuteSpiral
    other:
      Pst.Str(string(11, 13, "Not a valid entry.")) 
 
PUB FindSize(interation, sizeMinus2, sizeMinus1) : size

  size := sizeMinus2 + sizeMinus1

PUB FindStartX(iteration, size)

  case iteration // 4
    0, 2:
      result := 0
    1:
      result := size
    3:
      result := -size

PUB FindStartY(iteration, size)

  case iteration // 4
    0:
      result := -size
    1, 3:
      result := 0
    2:
      result := size

PUB FindDirectionX(iteration)

  case iteration // 4
    0, 3:
      result := 1
    1, 2:
      result := -1
  
PUB FindDirectionY(iteration)

  case iteration // 4
    0, 1:
      result := 1
    2, 3:
      result := -1

PUB ExecuteSpiral | radiusOverRoot2, iteration, oldestLength, oldLength, newRadius, {
} activeOctants, scaledDistance, now, maxIterationIndex, approachingZeroAxis, localAxis
'' The circle is divided into 8 "pieces" or pieces of eight.
'' For now the start of the circle needs to begin at a piece
'' boundry.
'' y = ^^((r * r) - (x * x))
''
  
  accelPhase := ACCEL_PHASE

  '------------------
  ' set values so first call to "ComputeNextSlow" will produce desired results

  
  'stepsToTakeX[presentSlow]++
 

  
  '---------------------
 

  delayFast := maxDelay 
  fastCount := 0
  activeOctant := 0
  delayChangeFast := defaultDelayChange
  Pst.str(string(11, 13, "max delay = "))
  Pst.Dec(delayFast / MS_001)
  Pst.str(string(" ms, min delay = "))
  Pst.Dec(minDelay / MS_001)
  Pst.str(string(" ms, delay change = "))
  Pst.Dec(delayChangeFast / MS_001)
  Pst.str(string(" ms, accel interval = "))
  Pst.Dec(accelerationInterval / MS_001)
  Pst.str(string(" ms, timesToA = "))
  Pst.Dec(timesToA) 

  'Cnc.PressToContinue
  oldestLength := 0
  oldLength := 1
  
  fastCount := 0 ' used to accelerate
  Pst.str(string(11, 13, "----------------------------"))
  Pst.str(string(11, 13, "Accelerate Phase"))
  maxIterationIndex := globalIterations - 1
  
  repeat iteration from 0 to maxIterationIndex

    newRadius := FindSize(iteration, oldestLength, oldLength)
    oldestLength := oldLength
    oldLength := newRadius
    
    xIndex := FindStartX(iteration, newRadius)
    yIndex := FindStartY(iteration, newRadius)
    presentDirectionX := FindDirectionX(iteration)
    presentDirectionY := FindDirectionY(iteration)
    xIndex *= spiralScale
    yIndex *= spiralScale
    radius := ||newRadius * spiralScale 
    rSquared := radius * radius

    if debugFlag
      Pst.Str(string(11, 13, "radius = "))
      Pst.Dec(radius)
      Pst.str(string(11, 13, "xIndex = "))
      Pst.Dec(xIndex)  
      Pst.str(string(", yIndex"))
      Pst.Dec(yIndex)   
    
     
    radiusOverRoot2 := radius * SCALED_MULTIPLIER / SCALED_ROOT_2
    'Pst.Str(string(11, 13, "radiusOverRoot2 = "))
    'Pst.Dec(radiusOverRoot2)
  
    if xIndex == 0
      presentFast := X_AXIS
      presentSlow := Y_AXIS
      approachingZeroAxis := Y_AXIS    
      stepPinFast := stepPinX
      stepPinSlow := stepPinY 
      dirPinFast := dirPinX
      dirPinSlow := dirPinY
    else
      presentFast := Y_AXIS
      presentSlow := X_AXIS
      approachingZeroAxis := X_AXIS
      stepPinFast := stepPinY
      stepPinSlow := stepPinX 
      dirPinFast := dirPinY
      dirPinSlow := dirPinX

    repeat localAxis from 0 to 1   
      if presentDirectionX[localAxis] == 1
        outa[dirPinX[localAxis]] := 1
      else
        outa[dirPinX[localAxis]] := 0

    {Pst.Str(string(11, 13, "Drive fast one revolution."))
    repeat 3200
      waitcnt(clkfreq / 200 + cnt)
      outa[stepPinFast] := 1
      waitcnt(clkfreq / 200 + cnt)
      outa[stepPinFast] := 0 }
          
    now := cnt
    lastStepFast := now
    lastHalfStepFast := now
    lastHalfStepFast -= delayFast / 2   
    lastAccelCnt := now
    nextSlow := xIndex[presentSlow] 
    ComputeNextSlow  ' set slow delays

    if debugFlag
      Pst.str(string(11, 13, "cnt = "))
      Pst.Dec(cnt / MS_001)
      Pst.str(string(11, 13, "delayFast = "))
      Pst.Dec(delayFast / MS_001)
      Pst.str(string(11, 13, "delaySlow = "))
      Pst.Dec(delaySlow / MS_001)
      Pst.str(string(11, 13, "delayChangeFast = "))
      Pst.Dec(delayChangeFast / MS_001)
      Pst.str(string(11, 13, "delayChangeSlow = "))
      Pst.Dec(delayChangeSlow / MS_001)
      Pst.str(string(11, 13, "lastHalfStepFast = "))
      Pst.Dec(lastHalfStepFast / MS_001)
      Pst.str(string(11, 13, "cnt at next fast half = "))
      Pst.Dec((lastHalfStepFast + delayFast) / MS_001)
      Pst.str(string(11, 13, "cnt at next fast step = "))
      Pst.Dec((lastStepFast + delayFast) / MS_001) 
    
    repeat
      
      now := cnt
      if now - lastHalfStepFast > delayFast
        {Pst.str(string(11, 13, "n-Hf= "))
        Pst.Dec((now - lastHalfStepFast) / MS_001)}
        NextHalfFast
      if now - lastHalfStepSlow > delaySlow
        {Pst.str(string(11, 13, "n-Hs= "))
        Pst.Dec((now - lastHalfStepSlow) / MS_001)
        Pst.str(string(11, 13, "dS= "))
        Pst.Dec(delaySlow / MS_001) }
        NextHalfSlow
      if now - lastStepFast > delayFast
        {Pst.str(string(11, 13, "n-f= "))
        Pst.Dec((now - lastStepFast) / MS_001)} 
        NextFastStep
       
      if now - lastAccelCnt > accelerationInterval
        {Pst.str(string(11, 13, "n-a= "))
        Pst.Dec((now - lastAccelCnt) / MS_001)}
        lastAccelCnt += accelerationInterval  
        AdjustSpeed
    'while xIndex < yIndex
    while xIndex[approachingZeroAxis]
  
  Pst.str(string(11, 13, "x = "))
  Pst.Dec(xIndex)
  Pst.str(string(", y = "))
  Pst.Dec(yIndex)
  Pst.str(string(11, 13, "radius = "))
  Pst.Dec(radius)
  Pst.str(string(11, 13, "Done! Execution Over"))
  Cnc.PressToContinue

' motion in ccw direction to center
  '' Which eight of the circle does the move start? (Piece of Eight)
  '' 4) Cx>0, Cy<0        \4|3/  3) Cx<0, Cy<0
  '' 5) Cx>R/root2, Cy<0  5\|/2  2) Cx<-R/root2, Cy<0
  ''                     ---*---
  '' 6) Cx>R/root2, Cy>0  6/|\1  1) Cx<-R/root2, Cy>0
  '' 7) Cx>0, Cy>0        /7|0\  0) Cx<0, Cy>0

PUB NextHalfFast

  if stepStateFast
    'missedHalfCountFast++
    {'150514b 
    if localAxis
      Pst.Char("Y")
    else
      Pst.Char("X")} '150514b
    {Pst.str(string(11, 13, "NextHalfFast, stepStateFast = "))
    Pst.Dec(stepStateFast)
    
    Pst.str(string(11, 13, "cnt = "))
    Pst.Dec(cnt / MS_001)
    Pst.Str(string(" ms"))
    Pst.str(string(11, 13, "lastHalfStepFast = "))
    Pst.Dec(lastHalfStepFast / MS_001)
    Pst.Str(string(" ms"))
    Pst.str(string(11, 13, "difference = "))
    Pst.Dec((cnt - lastHalfStepFast) / MS_001)
    Pst.Str(string(" ms "))  
    Pst.str(string(11, 13, "lastStepFast = "))
    Pst.Dec(lastStepFast / MS_001)
    Pst.Str(string(" ms"))  
    Pst.str(string(11, 13, "difference = "))
    Pst.Dec((cnt - lastStepFast) / MS_001)
    Pst.Str(string(" ms "))  }
    return

  'lastHalfStepFast += delayFast[localAxis]
  'pLastHalfStepFast := lastHalfStepFast
  lastHalfStepFast := cnt

  '150514b if localAxis == presentSlow
    '150514b Pst.str(string(11, 13, "Slow Half"))
  if 0 'xIndex == 382
    Pst.str(string(11, 13, "Slow Half Step"))
    Pst.str(string(11, 13, "lastHalfStepFast = "))
    Pst.Dec(lastHalfStepFast / MS_001)
    Pst.Str(string(" ms"))  
    Pst.str(string(11, 13, "cnt = "))
    Pst.Dec(cnt / MS_001)
    Pst.Str(string(" ms"))  
    Pst.str(string(11, 13, "difference = "))
    Pst.Dec((cnt - lastHalfStepFast) / MS_001)
    Pst.Str(string(" ms (this should be a small value)"))
    Pst.str(string(11, 13, "cnt at next half step = "))
    Pst.Dec((lastHalfStepFast + delayFast) / MS_001)
    Pst.Str(string(" ms"))
    Pst.str(string(11, 13, "cnt at next full step = "))
    Pst.Dec((lastStepFast + delayFast) / MS_001)
    Pst.Str(string(" ms")) 
    
 
  outa[stepPinFast] := 1
  stepStateFast := 1
  if debugFlag
    Pst.Str(string(", fast "))  
    Pst.Dec(stepPinFast)
    Pst.Str(string(" high "))  
  
PUB NextHalfSlow

  if stepStateSlow
    'missedHalfCountSlow++
    {Pst.str(string(11, 13, "NextHalfSlow, stepStateSlow = ", 7))
    Pst.Dec(stepStateSlow)
    Pst.str(string(11, 13, "cnt = "))
    Pst.Dec(cnt / MS_001)
    Pst.Str(string(" ms"))
    Pst.str(string(11, 13, "lastHalfStepSlow = "))
    Pst.Dec(lastHalfStepSlow / MS_001)
    Pst.Str(string(" ms"))
    Pst.str(string(11, 13, "difference = "))
    Pst.Dec((cnt - lastHalfStepSlow) / MS_001)
    Pst.Str(string(" ms "))  
    Pst.str(string(11, 13, "lastStepFast = "))
    Pst.Dec(lastStepFast / MS_001)
    Pst.Str(string(" ms"))  
    Pst.str(string(11, 13, "difference = "))
    Pst.Dec((cnt - lastStepFast) / MS_001)
    Pst.Str(string(" ms "))} 
    return
  'lastHalfStepSlow += delaySlow
  'pLastHalfStepSlow := lastHalfSlow
  lastHalfStepSlow := cnt
  
  outa[stepPinSlow] := 1
  stepStateSlow := 1
  if debugFlag
    Pst.Str(string(", slow "))  
    Pst.Dec(stepPinSlow)
    Pst.Str(string(" high "))
  
PUB NextFastStep

  {Pst.str(string(11, 13, "NextFastStep"))
  }
  ifnot stepStateFast
    {Pst.str(string(11, 13, "NextFastStep, stepStateFast = ", 7))
    Pst.Dec(stepStateFast)
    Pst.str(string(11, 13, "cnt = "))
    Pst.Dec(cnt / MS_001)
    Pst.Str(string(" ms"))
    Pst.str(string(11, 13, "lastHalfStepFast = "))
    Pst.Dec(lastHalfStepFast / MS_001)
    Pst.Str(string(" ms"))
    Pst.str(string(11, 13, "difference = "))
    Pst.Dec((cnt - lastHalfStepFast) / MS_001)
    Pst.Str(string(" ms "))  
    Pst.str(string(11, 13, "lastStepFast = "))
    Pst.Dec(lastStepFast / MS_001)
    Pst.Str(string(" ms"))  
    Pst.str(string(11, 13, "difference = "))
    Pst.Dec((cnt - lastStepFast) / MS_001)
    Pst.Str(string(" ms "))   }
    return             ' get half step first

  {Pst.str(string(11, 13, "lastStepFast was = "))
  Pst.Dec(lastStepFast / MS_001)
  Pst.Str(string(" ms")) }
  
  'lastStepFast += delayFast
  'pLastStepFast := lastStepFastFast
  lastStepFast := cnt
  
  {Pst.str(string(11, 13, "lastStepFast  is = "))
  Pst.Dec(lastStepFast / MS_001)
  Pst.Str(string(" ms")) }   

  if 0 'xIndex > 62
    Pst.str(string(11, 13, "lastStepFast = "))
    Pst.Dec(lastStepFast / MS_001)
    Pst.Str(string(" ms"))  
    Pst.str(string(11, 13, "cnt = "))
    Pst.Dec(cnt / MS_001)
    Pst.Str(string(" ms"))
    Pst.str(string(11, 13, "difference full = "))
    Pst.Dec((cnt - lastStepFast) / MS_001)
    Pst.Str(string(" ms (this should be a small value)"))
  
  xIndex[presentFast] += presentDirectionX[presentFast]
  'stepsToTakeX[localAxis]--
    
  ifnot xIndex[presentFast]  
    AdvanceOctant
   
    '150514a Pst.str(@astriskLine)
    {'150514c 
    Pst.str(string(11, 13))
    if localAxis
      Pst.Char("Y")
    else
      Pst.Char("X")
    Pst.str(string(" Equals 0")) }'150514c  
    '150514a Pst.str(@astriskLine)
  if ||xIndex[presentFast] == radius  ' this shouldn't happen
    Pst.str(@astriskLine)
    Pst.str(string(11, 13))
    if presentFast
      Pst.Char("Y")
    else
      Pst.Char("X")
    Pst.str(string(" = "))
    Pst.Dec(xIndex[presentFast])  
    CatastrophicError(@fastAtRadiusError)
  fastCount++    
  case accelPhase
    ACCEL_PHASE:
      if fastCount => timesToA  
        'Pst.str(string(11, 13, "Full Speed Phase ********************"))
        accelPhase := FULL_SPEED_PHASE
        lastAccel := delayFast
        delayFast := minDelay
        lastHalfStepFast := lastStepFast - (delayFast / 2)
        delayChangeFast := 0
        delayChangeSlow := 0

  
  
  outa[stepPinFast] := 0
  stepStateFast := 0
  if debugFlag
    Pst.Str(string(", fast "))  
    Pst.Dec(stepPinFast)
    Pst.Str(string(" low "))
  
  if xIndex[presentFast] == fastAtNextSlow
  
    ifnot stepStateSlow
      Pst.str(string(7, 11, 13, "stepStateSlow was = 0, now = 1", 7))
      outa[stepPinSlow] := 1
      stepStateSlow := 1
      Pst.Str(string(", bad timing slow "))  
      Pst.Dec(stepPinSlow)
      Pst.Str(string(" high "))
      'if missedHalfCount[otherAxis[localAxis]] == 0
        'Pst.str(string(7, 11, 13, "missedHalfCount equals zero", 7))
      {Pst.str(string(7, 11, 13, "Error! Slow axis in wrong stepState!", 7))
      Pst.str(string(11, 13, "lastHalfStep[otherAxis[localAxis]] was = "))
      Pst.Dec(result / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "lastHalfStep[otherAxis[localAxis]]  is = "))
      Pst.Dec(lastHalfStep[otherAxis[localAxis]] / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "time since lastHalfStep[slow] = "))
      Pst.Dec((cnt - result) / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "there should have been a half step = "))
      Pst.Dec((cnt - (result + delayFast[otherAxis[localAxis]])) / MS_001)
      Pst.Str(string(" ms ago (is this positive?)"))
      Pst.str(string(11, 13, "next half step should be = "))
      Pst.Dec((lastHalfStep[otherAxis[localAxis]] + delayFast[otherAxis[localAxis]]) / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "cnt = "))
      Pst.Dec(cnt / MS_001)
      Pst.Str(string(" ms")) }
      'repeat
    'missedHalfCount[otherAxis[localAxis]] := 0

    if debugFlag
      Pst.Str(string(", slow "))  
      Pst.Dec(stepPinSlow)
      Pst.Str(string(" low ", 11, 13))
    outa[stepPinSlow] := 0
    stepStateSlow := 0
  
    'outa[stepPinX[otherAxis[localAxis]]] := 0
    'stepState[otherAxis[localAxis]] := 0
    'stepsToTakeX[otherAxis[localAxis]]--
    ComputeNextSlow
    '150514d if xIndex == yIndex
    '150514d   Pst.str(string(11, 13, "X Equals Y *************************"))
      

  {'150514d}
  {'150514e
  previousCnt := newCnt
  newCnt := cnt
  differenceCnt := newCnt - previousCnt }
  if debugFlag
    Pst.str(string(11, 13, "x = "))
    Pst.Dec(xIndex)
    Pst.str(string(", y = "))
    Pst.Dec(yIndex)   
  {Pst.str(string(11, 13, "missedHalfCount = "))
  Pst.Dec(missedHalfCount[0])
  Pst.str(string(", and "))
  Pst.Dec(missedHalfCount[1]) 
  Pst.str(string(11, 13, "cnt = "))
  DecPoint(newCnt / MS_001, 3)
  Pst.Str(string(" s, difference = "))
  Pst.Dec(differenceCnt / MS_001)
  Pst.Str(string(" ms"))   } '150514e
  {if differenceCnt > constant(100 * MS_001)
    Pst.str(string(11, 13, "fastAtNextSlow = "))
    Pst.Dec(fastAtNextSlow)
    Pst.str(string(11, 13, "pLastHalfStep = "))
    Pst.Dec(pLastHalfStep[0] / MS_001)
    Pst.str(string(", and "))
    Pst.Dec(pLastHalfStep[1] / MS_001)
    Pst.str(string(11, 13, "lastHalfStepFast = "))
    Pst.Dec(lastHalfStepFast / MS_001)
    Pst.str(string(", and Slow = "))
    Pst.Dec(lastHalfStepSlow / MS_001)
    Pst.str(string(11, 13, "pLastStepFast = "))
    Pst.Dec(pLastStepFast / MS_001)
   
    Pst.str(string(11, 13, "lastStepFast = "))
    Pst.Dec(lastStepFast / MS_001)   }
   

   {}'150514d 
  {if xIndex > 300
    Pst.str(string(11, 13, "Why? "))
    repeat }
PUB ComputeNextSlow | previousSlow

  '150513a Pst.str(string(11, 13, "ComputeNextSlow"))

  'presentFast := presentFast[startOctant]
  'presentSlow := slowAxisByOctant[startOctant]
  'presentDirectionX
  previousSlow := xIndex[presentSlow]
  xIndex[presentSlow] := nextSlow    ' both xIndex and yIndex should be equal now at swap

  
  'stepsToTakeX[presentSlow]--
  ifnot xIndex[presentSlow]
    CatastrophicError(string("Slow Axis Equals Zero")) 

  '150515a if ||xIndex[presentSlow] == ||radius  '150515a only reverse when changing radius
    '150513a Pst.str(string(11, 13, "Slow Axis Equals Radius"))
    '-presentDirectionX[presentSlow] ' slow direction is reversed
    'SetDirection(presentSlow, presentDirectionX[presentSlow])
    '150515a ReverseDirection(presentSlow)
  

  if ||xIndex[presentSlow] == ||xIndex[presentFast] or ||previousSlow == ||xIndex[presentFast]
    AdvanceOctant
    '150514a Pst.str(@astriskLine)
    {Pst.str(string(11, 13, "before SwapSpeeds, nextSlow (old) = "))
    Pst.Dec(nextSlow)
    Pst.str(string(11, 13, "transition okay? fastAtNextSlow (old) = "))
    Pst.Dec(fastAtNextSlow)
    Pst.str(string(11, 13, "xIndex[presentSlow] (new) = "))
    Pst.Dec(xIndex[presentSlow])
    Pst.str(string(11, 13, "xIndex[presentFast] = "))
    Pst.Dec(xIndex[presentFast])
    Pst.str(string(11, 13, "presentSlow = "))
    Pst.Dec(presentSlow)
    Pst.str(string(11, 13, "previousSlow = "))
    Pst.Dec(previousSlow) 
    result := 1  }
    SwapSpeeds
    'repeat

  ' use post swap values to calculate nextSlow
  nextSlow := -radius #> xIndex[presentSlow] + presentDirectionX[presentSlow] <# radius
  nextSlowSquared := nextSlow * nextSlow
  fastAtNextSlow := ^^(rSquared - nextSlowSquared)
  
  if ||fastAtNextSlow > radius 
    Pst.str(@astriskLine)
    Pst.str(string(11, 13, "fastAtNextSlow = "))
    Pst.Dec(fastAtNextSlow)
    Pst.str(string(11, 13, "nextSlowSquared = "))
    Pst.Dec(nextSlowSquared)
    Pst.str(string(11, 13, "nextSlow = "))
    Pst.Dec(nextSlow)
    Pst.str(string(11, 13, "xIndex[presentSlow] = "))
    Pst.Dec(xIndex[presentSlow])
    Pst.str(string(11, 13, "presentDirectionX[presentSlow] = "))
    Pst.Dec(presentDirectionX[presentSlow])
    CatastrophicError(string("fastAtNextSlow too large"))
    
  {if result
    Pst.str(string(7, 11, 13, "after SwapSpeeds, nextSlow (new) = "))
    Pst.Dec(nextSlow)
    Pst.str(string(11, 13, "fastAtNextSlow (new) = "))
    Pst.Dec(fastAtNextSlow) }

   
  case activeOctant
    1, 4, 6, 7:
      -fastAtNextSlow
      {'150514a Pst.str(string(11, 13, "negate fastAtNextSlow"))
      if result
        Pst.str(string(11, 13, "fastAtNextSlow (negated) = "))
        Pst.Dec(fastAtNextSlow) } '150514a 
             
  fastStepsPerSlow := ||(fastAtNextSlow - xIndex[presentFast])
  delaySlow := delayFast * fastStepsPerSlow
  delayChangeSlow := delayChangeFast * fastStepsPerSlow
  lastHalfStepSlow := cnt - (delaySlow / 2)

  '150514a Pst.str(string(11, 13, "fastStepsPerSlow = "))
  '150514a Pst.Dec(fastStepsPerSlow)
  if ||fastStepsPerSlow > radius / 2
    Pst.str(string(7, 11, 13, "fastStepsPerSlow = "))
    Pst.Dec(fastStepsPerSlow)
    Pst.str(string(7, 11, 13, "fastAtNextSlow = "))
    Pst.Dec(fastAtNextSlow)
    Pst.str(string(11, 13, "xIndex[presentFast] = "))
    Pst.Dec(xIndex[presentFast])
    CatastrophicError(string("||fastStepsPerSlow > radius / 2"))
     
  {if xIndex[presentSlow] == xIndex[presentFast] or previousSlow == xIndex[presentFast]
    AdvanceOctant
    Pst.str(string(7, 11, 13, "before SwapSpeeds, nextSlow = "))
    Pst.Dec(nextSlow)
    Pst.str(string(11, 13, "transition okay? fastAtNextSlow = "))
    Pst.Dec(fastAtNextSlow)
    SwapSpeeds
  }
  {'150513a   
  Pst.str(string(11, 13, "delayFast = "))
  Pst.Dec(delayFast / MS_001)
  Pst.Str(string(" ms"))
  Pst.str(string(11, 13, "delayChangeFast = "))
  Pst.Dec(delayChangeFast / MS_001)
  Pst.Str(string(" ms"))

  Pst.str(string(11, 13, "**** = "))
  Pst.Dec(**** / MS_001)
  Pst.Str(string(" ms"))
  Pst.str(string(11, 13, "delayChangeSlow = "))
  Pst.Dec(delayChangeSlow / MS_001)
  Pst.Str(string(" ms"))

  Pst.str(string(11, 13, "nextSlow = "))
  Pst.Dec(nextSlow)
  Pst.str(string(11, 13, "fastAtNextSlow = "))
  Pst.Dec(fastAtNextSlow)
  Pst.str(string(11, 13, "fastStepsPerSlow = "))
  Pst.Dec(fastStepsPerSlow)
  }'150513a 
  {'150513a case xIndex
    61, 62, 63, 67, 68, 69:
      Pst.str(string(11, 13, "lastHalfStepSlow = "))
      Pst.Dec(lastHalfStepSlow / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "time since lastHalfStep[slow] = "))
      Pst.Dec((cnt - lastHalfStepSlow) / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "next half step should be = "))
      Pst.Dec((lastHalfStepSlow + ****) / MS_001)
      Pst.Str(string(" ms"))

      Pst.str(string(11, 13, "next fast full step should be = "))
      Pst.Dec((lastStepFast + delayFast) / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "fastAtNextSlow fast full step should be = "))
      Pst.Dec((lastStepFast + (delayFast * fastStepsPerSlow)) / MS_001)
      Pst.Str(string(" ms"))
      Pst.str(string(11, 13, "cnt = "))
      Pst.Dec(cnt / MS_001)
      Pst.Str(string(" ms"))    }'150513a 
    
PUB SwapSpeeds
 
  SwapLongs(@presentFast, @presentSlow)
  SwapLongs(@stepPinFast, @stepPinSlow)
  SwapLongs(@dirPinFast, @dirPinSlow)
  
PUB SwapLongs(longAPtr, longBPtr)

  result := long[longAPtr]
  long[longAPtr] := long[longBPtr]
  long[longBPtr] := result
       
  
  
  {Pst.str(string(7, 11, 13, "SwapSpeeds, new fast = "))
  Pst.Dec(presentFast)
    
  repeat result from 0 to 1
    Pst.str(string(11, 13, "delayFast["))
    Pst.Dec(result)
    Pst.Str(string("] = "))
    Pst.Dec(delayFast[result] / MS_001)
    Pst.Str(string(" ms"))

    Pst.str(string(11, 13, "delayChangeFast["))
    Pst.Dec(result)
    Pst.Str(string("] = "))
    Pst.Dec(delayChangeFast[result] / MS_001)
    Pst.Str(string(" ms"))  }

  
PUB AdvanceOctant

  activeOctant++
  activeOctant &= 7
  '150514c Pst.str(string(11, 13, "activeOctant = "))
  '150514c Pst.Dec(activeOctant)
  '150514a Pst.str(@astriskLine)
  
{'150515a
PUB ReverseDirection(localAxis) ' This will always be the slow axis

  {Pst.str(string(11, 13, "presentDirectionX["))
  Pst.Dec(localAxis)
  Pst.Str(string("] was = "))
  Pst.Dec(presentDirectionX[localAxis]) }
  
  -presentDirectionX[localAxis]
  
 { Pst.str(string(11, 13, "presentDirectionX["))
  Pst.Dec(localAxis)
  Pst.Str(string("]  is = "))
  Pst.Dec(presentDirectionX[localAxis]) }
  
  if presentDirectionX[localAxis] == 1
    outa[dirPinX[localAxis]] := 1
  else
    outa[dirPinX[localAxis]] := 0
 }'150515a    
PUB AdjustSpeed

  delayFast += delayChangeFast
  delaySlow += delayChangeSlow
  {if delayChangeFast
    Pst.str(string(11, 13, "AdjustSpeed = delayFast = "))
    Pst.Dec(delayFast / MS_001)
    Pst.Str(string(" ms, delaySlow = "))
    Pst.Dec(delaySlow / MS_001)
    Pst.Str(string(" ms"))  
  Pst.str(string(11, 13, "delayChangeFast = "))
  Pst.Dec(delayChangeFast / MS_001)
  Pst.Str(string(" ms, delayChangeSlow = "))
  Pst.Dec(delayChangeSlow / MS_001)
  Pst.Str(string(" ms"))    
  Pst.str(string(11, 13, "cnt at next half step (fast)= "))
  Pst.Dec((lastHalfStepFast + delayFast) / MS_001)
  Pst.Str(string(" ms"))
  Pst.str(string(11, 13, "cnt at next full step = "))
  Pst.Dec((lastStepFast + delayFast) / MS_001)
  Pst.Str(string(" ms"))
  Pst.str(string(11, 13, "cnt at next half step (slow)= "))
  Pst.Dec((lastHalfStepSlow + delaySlow) / MS_001)
  Pst.Str(string(" ms"))
 
  Pst.str(string(11, 13, "cnt = "))
  Pst.Dec(cnt / MS_001)
  Pst.Str(string(" ms"))     }
  
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

PUB DecPoint(value, decimalPlaces) | localBuffer[4]

  result := Format.FDec(@localBuffer, value, decimalPlaces + 4, decimalPlaces)
  byte[result] := 0
  Pst.str(@localBuffer)

PUB CatastrophicError(errorPtr)

  Pst.str(@astriskLine)
  Pst.str(string(7, 11, 13, "Error! ", 7))
  Pst.str(errorPtr)
  Pst.str(string(7, 11, 13, "Done! Program Over", 7))
  repeat

PUB DisplayAxis(localIndex)

  Pst.str(Header.FindString(@axisText, localIndex))
  Pst.str(string("-Axis"))
  
PUB DisplayPhase(localIndex)

  Pst.str(Header.FindString(@phaseText, localIndex))
  Pst.str(string(" phase"))
  
PUB DisplaySpeed(localIndex)

  Pst.str(Header.FindString(@speedText, localIndex))
  
PUB DisplayDirection(localIndex)

  Pst.str(Header.FindString(@directionText, localIndex))
      
{PUB GetStepsFromUnits(localUnits, localValue, localMultiplier)

  Pst.str(string(11, 13, "GetStepsFromUnits("))
  Pst.str(Header.FindString(@unitsText, localUnits))
  Pst.str(string(", "))
  Pst.Dec(localValue)
  Pst.str(string(", "))
  Pst.Dec(localMultiplier)
  Pst.str(string(") result = "))
  
  case localUnits
    Header#STEP_UNIT:
      result := localValue
      return
    Header#TURN_UNIT:
      result := localValue * microsteps
      result /= localMultiplier
    Header#INCH_UNIT:
      result := localValue * microsteps
      result /= localMultiplier
      result *= 254
      result /= 50
    Header#MILLIMETER_UNIT:
      result := localValue * microsteps
      result /= localMultiplier
      result /= 5
      
  result *= microsteps
  
  Pst.Dec(result)
          }
DAT

astriskLine   byte 11, 13, "**************************************************"
              byte "*********************", 0

fastAtRadiusError       byte "||xIndex[localAxis] == radius", 0
accelAxisError          byte "localAxis <> accelAxis", 0
decelAxisError          byte "localAxis <> decelAxis", 0

axisText                byte "X", 0, "Y", 0
speedText               byte "fast", 0, "slow", 0
phaseText               byte "accleration", 0, "full speed", 0, "deceleration", 0
directionText           byte "forward", 0, "reverse", 0