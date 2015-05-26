DAT objectName          byte "MotorControl", 0
CON
{{

  150516b Commented out 24 debug pointer. Freed up 66 long in PASM section.
  18a Comment out single and dual stepper control.
  
}}
CON

  TEST_BUFFER_SIZE = 200
 
DAT

'cog                     long 0
command                 long 0
mailbox                 long 0

maxDelay                long 80_000 * 5 '80_000 * 50
minDelay                long 80_000 '80_000
delayChange             long 800 '8_000
accelInterval           long 40_000 '' *** This might be a problem.
accelIntervals          long 0-0

'address165              long 0-0
debugLastStepTime       long 0-0
debugActiveDelayS       long 0-0
debugActiveDelay        long 0-0
'debugDelayTotalS        long 0-0
'debugDelayTotal         long 0-0   
'debugFullStepsF         long 0-0
rSquaredHub             long 0-0
debugMaxDelay           long 0-0
fastStepsPerSlowHub     long 0-0
debugLastHalfTime       long 0-0
debugLastHalfTimeS      long 0-0
nextSlowSquaredHub      long 0-0
debugFastTotal          long 0-0
debugSlowTotal          long 0-0
debugScratchTime444     long 0-0
debugScratchTime        long 0-0
debugLocationClue       long 0-0
debugLocationClueF      long 0-0
debugNextSlowHub        long 0-0
debugFastIndex          long 0-0
debugSlowIndex          long 0-0
debugFastStepMask       long 0-0
debugSlowStepMask       long 0-0
debugFastDirection      long 0-0
debugSlowDirection      long 0-0
debugFastAtNextSlow     long 0-0
debugFastAtNextSlowSq   long 0-0
debugMathA              long 0-0
debugMathB              long 0-0
debugMathResult         long 0-0
debugSwapCount          long 0-0
debugOctant             long 0-0
debugNewLastHalfStepTime long 0-0
debugAccelCount         long 0-0
debugLoopCount          long 0-0
debugSlowHalfCount      long 0-0
debugGetSlowCount       long 0-0
debugSlowHighCount      long 0-0
debugFastHighCount      long 0-0
debugFastLowCount       long 0-0
{debugExtra5             long 0-0
debugExtra4             long 0-0
debugExtra3             long 0-0 }

dirPinX                 long Header#DIR_X_PIN
dirPinY                 long Header#DIR_Y_PIN
dirPinZ                 long Header#DIR_Z_PIN
stepMaskX               long 1 << Header#STEP_X_PIN
stepMaskY               long 1 << Header#STEP_Y_PIN
stepMaskZ               long 1 << Header#STEP_Z_PIN
stepMaskFast            long 1 << Header#STEP_Y_PIN, 1 << Header#STEP_X_PIN
                        long 1 << Header#STEP_X_PIN, 1 << Header#STEP_Y_PIN
                        long 1 << Header#STEP_Y_PIN, 1 << Header#STEP_X_PIN
                        long 1 << Header#STEP_X_PIN, 1 << Header#STEP_Y_PIN
                        
stepMaskSlow            long 1 << Header#STEP_X_PIN, 1 << Header#STEP_Y_PIN
                        long 1 << Header#STEP_Y_PIN, 1 << Header#STEP_X_PIN
                        long 1 << Header#STEP_X_PIN, 1 << Header#STEP_Y_PIN
                        long 1 << Header#STEP_Y_PIN, 1 << Header#STEP_X_PIN

dirMaskFast             long 1 << Header#DIR_Y_PIN, 1 << Header#DIR_X_PIN
                        long 1 << Header#DIR_X_PIN, 1 << Header#DIR_Y_PIN
                        long 1 << Header#DIR_Y_PIN, 1 << Header#DIR_X_PIN
                        long 1 << Header#DIR_X_PIN, 1 << Header#DIR_Y_PIN
                        
dirMaskSlow             long 1 << Header#DIR_X_PIN, 1 << Header#DIR_Y_PIN
                        long 1 << Header#DIR_Y_PIN, 1 << Header#DIR_X_PIN
                        long 1 << Header#DIR_X_PIN, 1 << Header#DIR_Y_PIN
                        long 1 << Header#DIR_Y_PIN, 1 << Header#DIR_X_PIN                        
                            ' Y   X   X   Y   Y   X   X   Y
directionFast           long  1, -1, -1, -1, -1,  1,  1,  1
                            ' 0   1   2   3   4   5   6   7
                            ' X   Y   Y   X   X   Y   Y   X
directionSlow           long -1,  1, -1, -1,  1, -1,  1,  1
  '' Which eight of the circle does the move start? (Piece of Eight)
  '' 4) Cx>0, Cy<0        \2|1/  3) Cx<0, Cy<0
  '' 5) Cx>R/root2, Cy<0  3\|/0  2) Cx<-R/root2, Cy<0
  ''                     ---*---
  '' 6) Cx>R/root2, Cy>0  4/|\7  1) Cx<-R/root2, Cy>0
  '' 7) Cx>0, Cy>0        /5|6\  0) Cx<0, Cy>0
  ''                          
'testBuffer              long 0[TEST_BUFFER_SIZE]

OBJ

  Header : "HeaderCnc"
  Pst : "Parallax Serial TerminalDat"
  'Format : "StrFmt"
  'Cnc : "CncCommonMethods"
   
PUB Start(address165_) '| debugPtr

  'address165 := address165_
 
  'testBufferPtr := @testBuffer
 
 { debugPtr := @debugActiveDelayS
  'accelIntervals := ComputeAccelIntervals(maxDelay, minDelay, delayChange, accelInterval)
  
  repeat result from 0 to 16 'Header#MAX_DEBUG_SPI_INDEX
    debugActiveDelaySPtr[result] := debugPtr
    debugPtr += 4   }
       
  dira[dirPinX] := 1
  dira[dirPinY] := 1
  dira[dirPinZ] := 1
       
  cognew(@entry, @command)

  waitcnt(clkfreq / 100 + cnt)
  
  SetMotorParameters(maxDelay, minDelay, delayChange, accelInterval)

PUB SetCommand(cmd)

  Pst.Str(string(11, 13, "SetCommand(")) 
  Pst.Dec(cmd)
  Pst.Char(")")
    
  command := cmd                '' Write command 
  repeat while command          '' Wait for command to be cleared, signifying receipt

    Pst.Str(string(11, 13, "location = ")) ' watch progress
    Pst.Dec(debugLocationClueF)
    
PUB GetPasmArea
'' To reuse memory if desired.

  result := @entry 

PUB SetMaxDelay(localMax)

  SetMotorParameters(localMax, minDelay, delayChange, accelInterval)
  
PUB SetMinDelay(localMin)

  SetMotorParameters(maxDelay, localMin, delayChange, accelInterval)
  
PUB SetDelayChange(localChange)

  SetMotorParameters(maxDelay, minDelay, localChange, accelInterval)
  
PUB SetMotorParameters(localMax, localMin, localChange, localAccelInterval)

  longmove(@maxDelay, @localMax, 4)

  mailbox := @result
  result := @maxDelay
  'accelMaxIntervals := ComputeMaxAccelIntervals(localMax, localMin, localChange)
  accelIntervals := ComputeAccelIntervals(localMax, localMin, localChange, localAccelInterval)
  SetCommand(Header#NEW_PARAMETERS_MOTOR)

{PRI ComputeMaxAccelIntervals(localMax, localMin, localChange)

  result := localMax - localMin
  result += localChange - 1     ' make sure divide doesn't truncate value at all
  result /= localChange
}  
  ''Pst.Str(string(11, 13, "accelMaxIntervals = "))
  ''Pst.Dec(result)
  
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
  
PUB MoveSingle(localAxis, localDistance) | spinScratch

  {{Pst.Str(string(11, 13, "MoveSingle("))
  Pst.Dec(localAxis)
  Pst.Str(string(", "))
  Pst.Dec(localDistance)
  Pst.Str(string("), accelIntervals = "))
  Pst.Dec(accelIntervals)  }}
  
  longfill(@debugActiveDelayS, 0, 16)
  
  localAxis := stepMaskX[localAxis]
  if localDistance < 0
    outa[dirPinX[localAxis]] := 0
    ||localDistance
  else
    outa[dirPinX[localAxis]] := 1
      
  mailbox := @result
  ''Pst.Str(string(11, 13, "localAxis (mask) "))
  'Cnc.ReadableBin(localAxis, 32)
  
  'Cnc.PressToContinue
   
  'SetCommand(Header#SINGLE_MOTOR)
  command := Header#SINGLE_MOTOR
  repeat 'while command          '' Wait for command to be cleared, signifying receipt
    {{Pst.Str(string(11, 13, "location = ")) ' watch progress
    Pst.Dec(debugLocationClueF)
    Pst.Str(string(", ")) 
    Pst.Dec(debugLocationClue)
    Pst.Str(string(", fastTotal = ")) 
    Pst.Dec(debugFastTotal)
    Pst.Str(string(", activeDelay = ")) 
    Pst.Dec(debugActiveDelay)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugActiveDelay / 80_000)
    Pst.Str(string(" ms, delayTotal = ")) 
    Pst.Dec(debugDelayTotal)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugDelayTotal / 80_000)
    Pst.Str(string(" ms  ")) 
    Pst.Dec(debugNextSlowHub)
    
    Pst.Str(string(11, 13, "maxDelayCog = ")) 
    Pst.Dec(debugMaxDelay)
    Pst.Str(string(", PASM scratchTime = ")) 
    Pst.Dec(debugScratchTime444)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugScratchTime444 / 80_000)
    Pst.Str(string(", scratchTime (accel) = ")) 
    Pst.Dec(debugScratchTime)
    Pst.Str(string(11, 13, "Spin scratchTime = ")) 
    spinScratch := debugLastHalfTime - cnt
    Pst.Dec(spinScratch)
    Pst.Str(string(" or ")) 
    Pst.Dec(spinScratch / 80_000)
    Pst.Str(string(" ms")) 
       
    Pst.Str(string(11, 13, "accelStepsF = ")) 
    Pst.Dec(debugNextSlowHub)   
    Pst.Str(string(", fullStepsF = ")) 
    Pst.Dec(debugFullSpeedSteps)   
    Pst.Str(string(", decelStepsF = ")) 
    Pst.Dec(debugDecelSteps)   
    Pst.Str(string(", a+f+d = ")) 
    Pst.Dec(debugNextSlowHub + debugFullSpeedSteps + debugDecelSteps)   
    Pst.Str(string(", localDistance = ")) 
    Pst.Dec(localDistance)   

    Pst.Str(string(11, 13, "debugHalfTime = ")) 
    Pst.Dec(debugLastHalfTime)   
    Pst.Str(string(", lastStepTime = ")) 
    Pst.Dec(debuglastStepTime)   
    Pst.Str(string(", next - half = ")) 
    Pst.Dec(debuglastStepTime - debugLastHalfTime)   
    }}
    
                        
  while command and debugLocationClue <> 999        
  ''Pst.Str(string(11, 13, "full speed steps = "))
 '' Pst.Dec(result)
  outa[dirPinX] := 0
  outa[dirPinY] := 0
  outa[dirPinZ] := 0
   
PUB MoveLine(longAxis, shortAxis, longDistance, shortDistance) | {
} maxDelayS, minDelayS, delayChangeS, spinScratch, originalAxes[2]

  maxDelayS := Header.TtaMethod(||longDistance, maxDelay, ||shortDistance)
  minDelayS := Header.TtaMethod(||longDistance, minDelay, ||shortDistance)
  delayChangeS := Header.TtaMethod(||longDistance, delayChange, ||shortDistance)
  longmove(@originalAxes, @longAxis, 2)
  longfill(@debugActiveDelayS, 0, 16)
  
  {{Pst.Str(string(11, 13, "MoveLine("))
  Pst.Dec(longAxis)
  Pst.Str(string(", "))
  Pst.Dec(shortAxis)
  Pst.Str(string(", "))
  Pst.Dec(longDistance)
  Pst.Str(string(", "))
  Pst.Dec(shortDistance)
  Pst.Str(string("), accelIntervals = "))
  Pst.Dec(accelIntervals)
  Pst.Str(string("), accelMaxIntervals = "))
  Pst.Dec(accelMaxIntervals) 

  
  
  Pst.Str(string(11, 13, "startDelay (long) = "))
  Pst.Dec(maxDelay)
  Pst.Str(string(", (short) = "))
  Pst.Dec(maxDelayS)
  Pst.Str(string(11, 13, "minDelay (long) = "))
  Pst.Dec(minDelay)
  Pst.Str(string(", (short) = "))
  Pst.Dec(minDelayS)
  Pst.Str(string(11, 13, "delayChange (long) = "))
  Pst.Dec(delayChange)
  Pst.Str(string(", (short) = "))
  Pst.Dec(delayChangeS)  }}

  repeat result from 0 to 1
    longAxis[result] := stepMaskX[originalAxes[result]]
    if longDistance[result] < 0
      outa[dirPinX[originalAxes[result]]] := 0
      ||longDistance[result]
    else
      outa[dirPinX[originalAxes[result]]] := 1
   {{ Pst.Str(string(11, 13))
    {Pst.Str(Header.FindString(Cnc.GetAxisText, originalAxes[result]))} 
    Pst.Str(string(" (mask)["))
    Pst.Dec(originalAxes[result])
    Pst.Str(string("] = "))  }}
    'Cnc.ReadableBin(longAxis[result], 32)  

  'Cnc.PressToContinue
  
  mailbox := @result

  'SetCommand(Header#DUAL_MOTOR)
  command := Header#DUAL_MOTOR
  repeat 'while command          '' Wait for command to be cleared, signifying receipt
    {{Pst.Str(string(11, 13, "location = ")) ' watch progress
    Pst.Dec(debugLocationClueF)
    Pst.Str(string(", ")) 
    Pst.Dec(debugLocationClue)
    Pst.Str(string(", fastTotal = ")) 
    Pst.Dec(debugFastTotal)
    Pst.Str(string(", activeDelay = ")) 
    Pst.Dec(debugActiveDelay)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugActiveDelay / 80_000)
    Pst.Str(string(" ms, delayTotal = ")) 
    Pst.Dec(debugDelayTotal)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugDelayTotal / 80_000)
    Pst.Str(string(" ms  ")) 
    Pst.Dec(debugNextSlowHub)
    
    Pst.Str(string(11, 13, "location = ")) 
    Pst.Dec(debugLocationClueF)
    Pst.Str(string(", ")) 
    Pst.Dec(debugLocationClue)
    Pst.Str(string(", slowTotal = ")) 
    Pst.Dec(debugSlowTotal)
    Pst.Str(string(", activeDelayS = ")) 
    Pst.Dec(debugActiveDelayS)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugActiveDelayS / 80_000)
    Pst.Str(string(" ms, delayTotal = ")) 
    Pst.Dec(debugDelayTotalS)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugDelayTotalS / 80_000)
    Pst.Str(string(" ms  ")) 
    'Pst.Dec(debugNextSlowHub)
    Pst.Str(string(11, 13, "activeChange = ")) 
    Pst.Dec(debugActiveChange)
    Pst.Str(string(", ")) 
    Pst.Dec(debugActiveChangeS)
   
    
    Pst.Str(string(11, 13, "maxDelayCog = ")) 
    Pst.Dec(debugMaxDelay)
    Pst.Str(string(", PASM scratchTime = ")) 
    Pst.Dec(debugScratchTime444)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugScratchTime444 / 80_000)
    Pst.Str(string(", scratchTime (accel) = ")) 
    Pst.Dec(debugScratchTime)
    Pst.Str(string(11, 13, "Spin scratchTime = ")) 
    spinScratch := debugLastHalfTime - cnt
    Pst.Dec(spinScratch)
    Pst.Str(string(" or "))
    Pst.Dec(spinScratch / 80_000)
    Pst.Str(string(" ms"))
       
    Pst.Str(string(11, 13, "accelStepsF = ")) 
    Pst.Dec(debugNextSlowHub)   
    Pst.Str(string(", fullStepsF = "))
    Pst.Dec(debugFullSpeedSteps)   
    Pst.Str(string(", decelStepsF = ")) 
    Pst.Dec(debugDecelSteps)   
    Pst.Str(string(", a+f+d = "))
    Pst.Dec(debugNextSlowHub + debugFullSpeedSteps + debugDecelSteps)   
    Pst.Str(string(", longDistance = "))
    Pst.Dec(longDistance)   
    Pst.Str(string(", shortDistance = ")) 
    Pst.Dec(shortDistance)   

    Pst.Str(string(11, 13, "accelStage = ")) 
    Pst.Dec(debugAccelStage)   
    Pst.Str(string(", stepCountdown = ")) 
    Pst.Dec(debugStepCountdown)   
    
    Pst.Str(string(11, 13, "fast low con1M = ")) 
    Pst.Dec(debug1M)   
    Pst.Str(string(", slow low con2M = ")) 
    Pst.Dec(debug2M)   
    Pst.Str(string(", slow high con3M = ")) 
    Pst.Dec(debug3M)   
    Pst.Str(string(", fast high con4M = ")) 
    Pst.Dec(debug4M)   
    Pst.Str(string(11, 13, "Accel = ")) 
    Pst.Dec(debug1MA)   
    Pst.Str(string(", ")) 
    Pst.Dec(debug2MA)   
    Pst.Str(string(", ")) 
    Pst.Dec(debug3MA)   
    Pst.Str(string(", "))
    Pst.Dec(debug4MA)   
    Pst.Str(string(11, 13, "Full = ")) 
    Pst.Dec(debug1MF)   
    Pst.Str(string(", ")) 
    Pst.Dec(debug2MF)   
    Pst.Str(string(", ")) 
    Pst.Dec(debug3MF)   
    Pst.Str(string(", "))
    Pst.Dec(debug4MF)   
    Pst.Str(string(11, 13, "Decel = ")) 
    Pst.Dec(debug1MD)   
    Pst.Str(string(", ")) 
    Pst.Dec(debug2MD)   
    Pst.Str(string(", ")) 
    Pst.Dec(debug3MD)   
    Pst.Str(string(", ")) 
    Pst.Dec(debug4MD)   

    Pst.Str(string(11, 13, "debugHalfTime = ")) 
    Pst.Dec(debugLastHalfTime)   
    Pst.Str(string(", lastStepTime = ")) 
    Pst.Dec(debuglastStepTime)   
    Pst.Str(string(", next - half = ")) 
    Pst.Dec(debuglastStepTime - debugLastHalfTime)}}
                        
  while command and debugLocationClue <> 999

  outa[dirPinX] := 0
  outa[dirPinY] := 0
  outa[dirPinZ] := 0
  
PUB MoveCircle(radius, startOctant, distanceOctants) | fastStepMask, slowStepMask, {
} fastDirMask, slowDirMask, radiusOverRoot2, fastIndex, slowIndex, {
} fastDirection, slowDirection, spinScratch, originalOctant
  '' Which eight of the circle does the move start? (Piece of Eight)
  '' 4) Cx>0, Cy<0        \2|1/  3) Cx<0, Cy<0
  '' 5) Cx>R/root2, Cy<0  3\|/0  2) Cx<-R/root2, Cy<0
  ''                     ---*---
  '' 6) Cx>R/root2, Cy>0  4/|\7  1) Cx<-R/root2, Cy>0
  '' 7) Cx>0, Cy>0        /5|6\  0) Cx<0, Cy>0
  ''
 
  Pst.Str(string(11, 13, "MoveCircle("))
  Pst.Dec(radius)
  Pst.Str(string(", ")) 
  Pst.Dec(startOctant)
  Pst.Str(string(", ")) 
  Pst.Dec(distanceOctants)
  Pst.Str(string(") ")) 
  originalOctant := startOctant
  {ifnot startOctant & 1
    startOctant := (startOctant - 1) & 7
    distanceOctants++
    Pst.Str(string(11, 13, "startOctant adjusted so compensate for intial state, startOctant = "))
    Pst.Dec(startOctant)
    Pst.Str(string(", adjusted distanceOctants = ")) 
    Pst.Dec(distanceOctants)    }
          
  radiusOverRoot2 := radius * Header#SCALED_MULTIPLIER / Header#SCALED_ROOT_2

  fastStepMask := stepMaskFast[startOctant]
  slowStepMask := stepMaskSlow[startOctant]
  fastDirMask := dirMaskFast[startOctant]
  slowDirMask := dirMaskSlow[startOctant]
  fastDirection := directionFast[startOctant]
  Pst.Str(string(11, 13, "fastDirection = directionFast[")) 
  Pst.Dec(startOctant)
  Pst.Str(string("] = ")) 
  Pst.Dec(directionFast[startOctant])
  Pst.Str(string(11, 13, "accelIntervals = ")) 
  Pst.Dec(accelIntervals)
  
  slowDirection := directionSlow[startOctant]

  dira[dirPinX] := 0
  dira[dirPinY] := 0
  dira[dirPinZ] := 0
  '' Which eight of the circle does the move start? (Piece of Eight)
  '' 4) Cx>0, Cy<0        \2|1/  3) Cx<0, Cy<0
  '' 5) Cx>R/root2, Cy<0  3\|/0  2) Cx<-R/root2, Cy<0
  ''                     ---*---
  '' 6) Cx>R/root2, Cy>0  4/|\7  1) Cx<-R/root2, Cy>0
  '' 7) Cx>0, Cy>0        /5|6\  0) Cx<0, Cy>0
  ''  
  case originalOctant 'startOctant  ' come up with a better algorithm for fill these values
    0:
      slowIndex {xIndex} := radius - 1 '0
      fastIndex := 0 '-radius 'yIndex := -radius
    1:
      fastIndex {xIndex} := radiusOverRoot2 '- 1 
      slowIndex {yIndex} := radiusOverRoot2 '+ 1
    2:
      fastIndex {xIndex} := 0 'radius
      slowIndex {yIndex} := radius '- 1 '0
    3:
      slowIndex {xIndex} := -radiusOverRoot2 '- 1 
      fastIndex {yIndex} := radiusOverRoot2' - 1
    4:
      slowIndex {xIndex} := -radius '+ 1'0
      fastIndex {yIndex} := 0 '-1 '0 'radius
    5:
      fastIndex {xIndex} := -radiusOverRoot2 + 1 
      slowIndex {yIndex} := -radiusOverRoot2 - 1
    6:
      fastIndex {xIndex} := 0 '1 '0 '-radius
      slowIndex {yIndex} := -radius '+ 1'0
    7:
      slowIndex {xIndex} := radiusOverRoot2 '+ 1
      fastIndex {yIndex} := -radiusOverRoot2 '+ 1

  fastIndex += fastDirection
  slowIndex += slowDirection

  longfill(@debugActiveDelayS, 0, 25)

  Pst.Str(string(11, 13, "radiusOverRoot2 = "))
  Pst.Dec(radiusOverRoot2)
  Pst.Str(string(", fastIndex = ")) 
  Pst.Dec(fastIndex)
  Pst.Str(string(", slowIndex = ")) 
  Pst.Dec(slowIndex)
  Pst.Str(string(", fastDirection = ")) 
  Pst.Dec(fastDirection)
  Pst.Str(string(", slowDirection = ")) 
  Pst.Dec(slowDirection)

  if fastStepMask == stepMaskX
    Pst.Str(string(11, 13, "Fast axis = X")) 
  else
    Pst.Str(string(11, 13, "Fast axis = Y"))
  'Cnc.PressToContinue

  
  mailbox := @result

  'SetCommand(Header#CIRCLE_MOTOR)
  command := Header#CIRCLE_MOTOR
  repeat 'while command          '' Wait for command to be cleared, signifying receipt
    Pst.Str(string(11, 13, 11, 13, "loc= ")) ' watch progress
    Pst.Dec(debugLocationClueF)
    Pst.Str(string(", ")) 
    Pst.Dec(debugLocationClue)
     
    Pst.Str(string(", lHTime= ")) 
    {Pst.Dec(debugLastHalfTime)
    Pst.Str(string(" or ")) }
    Pst.Dec(debugLastHalfTime / 80_000)
    Pst.Str(string(" ms, ago =  "))
    Pst.Dec((cnt - debugLastHalfTime) / 80_000)
    Pst.Str(string(" ms  "))
    Pst.Str(string(", lHTimeS= ")) 
    {Pst.Dec(debugLastHalfTimeS)
    Pst.Str(string(" or ")) }
    Pst.Dec(debugLastHalfTimeS / 80_000)
    Pst.Str(string(" ms, ago =  "))
    Pst.Dec((cnt - debugLastHalfTimeS) / 80_000)
    Pst.Str(string(" ms  "))

    
    
    Pst.Str(string(11, 13, "PASM scratchTime= ")) 
    {Pst.Dec(debugScratchTime)
    Pst.Str(string(" or "))} 
    Pst.Dec(debugScratchTime / 80_000) 
    Pst.Str(string(" ms, ago =  "))
    Pst.Dec((cnt - debugScratchTime) / 80_000)
    Pst.Str(string(" ms, cnt - PASM now= ")) 
    {Pst.Dec(debugScratchTime444)
    Pst.Str(string(" or "))} 
    Pst.Dec((cnt - debugScratchTime444) / 80_000)
    Pst.Str(string(" ms"))
    {Pst.Str(string(" ms, Spin scratchTime = ")) 
    spinScratch := cnt - debugLastHalfTime
    Pst.Dec(spinScratch)      
    Pst.Str(string(" or ")) 
    Pst.Dec(spinScratch / 80_000)
    Pst.Str(string(" ms"))
    
    Pst.Str(string(11, 13, "Spin scratchTime slow = ")) 
    spinScratch := cnt - debugLastHalfTimeS
    Pst.Dec(spinScratch)      
    Pst.Str(string(" or ")) 
    Pst.Dec(spinScratch / 80_000)
    Pst.Str(string(" ms"))   }
    Pst.Str(string(11, 13, "fastTotal= ")) 
    Pst.Dec(debugFastTotal)
    Pst.Str(string(",slowTotal= ")) 
    Pst.Dec(debugSlowTotal) 
    Pst.Str(string(",aDelay= ")) 
    Pst.Dec(debugActiveDelay)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugActiveDelay / 80_000)
    Pst.Str(string(",aDelayS= ")) 
    Pst.Dec(debugActiveDelayS)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugActiveDelayS / 80_000)
    Pst.Str(string(",S/F= ")) 
    Pst.Dec(debugActiveDelayS / debugActiveDelay)
    Pst.Str(string(",fSPS= ")) 
    Pst.Dec(fastStepsPerSlowHub)
    Pst.Str(string(11, 13, "fastIndex= ")) 
    Pst.Dec(debugFastIndex)
    Pst.Str(string(", slowIndex= ")) 
    Pst.Dec(debugSlowIndex)
    Pst.Str(string(", nextSlow= ")) 
    Pst.Dec(debugNextSlowHub)
    Pst.Str(string(", nextSlow^2= ")) 
    Pst.Dec(nextSlowSquaredHub)
    Pst.Str(string(",r^2= ")) 
    Pst.Dec(rSquaredHub)

    if debugFastStepMask == stepMaskX
      Pst.Str(string(11, 13, "F axis = X")) 
    else
      Pst.Str(string(11, 13, "F axis = Y"))
    
    Pst.Str(string(", o fast = ")) 
    Pst.Dec(fastStepMask)
    Pst.Str(string(", o slow = ")) 
    Pst.Dec(slowStepMask)
    Pst.Str(string(", pr fast = ")) 
    Pst.Dec(debugFastStepMask)
    Pst.Str(string(", pr slow = ")) 
    Pst.Dec(debugSlowStepMask)
    Pst.Str(string(", f dir = ")) 
    Pst.Dec(debugFastDirection)
    Pst.Str(string(", s dir = ")) 
    Pst.Dec(debugSlowDirection)
    Pst.Str(string(11, 13, "directionFast[")) 
    Pst.Dec(startOctant)
    Pst.Str(string("] = ")) 
    Pst.Dec(directionFast[startOctant])
    Pst.Str(string(", fastAtNextSlow = "))
    Pst.Dec(debugFastAtNextSlow)
    Pst.Str(string(", fastAtNextSlow^2 = "))
    Pst.Dec(debugFastAtNextSlowSq)
    
    Pst.Str(string(11, 13, "cnt = ")) 
    Pst.Dec(cnt)
    Pst.Str(string(" or ")) 
    Pst.Dec(cnt / 80_000)
    Pst.Str(string(", lastStepTime = ")) 
    Pst.Dec(debugLastStepTime)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugLastStepTime / 80_000)
    Pst.Str(string(", cnt - lastStepTime = ")) 
    Pst.Dec(cnt - debugLastStepTime)
    Pst.Str(string(" or ")) 
    Pst.Dec((cnt - debugLastStepTime) / 80_000)


    'Pst.Str(string(11, 13, "lastStepTime + activeDelay = lastStepTime")) 
    Pst.Str(string(11, 13, "lastHalfStepTimeS + activeDelay = lastHalfStepTimeS")) 
    Pst.Str(string(11, 13)) 
    Pst.Dec(debugMathA)
    Pst.Str(string(" + ")) 
    Pst.Dec(debugMathB)
    Pst.Str(string(" = ")) 
    Pst.Dec(debugMathResult)
    Pst.Str(string(" = ")) 
    Pst.Dec(debugMathA + debugMathB)
    Pst.Str(string(11, 13, "or "))
    Pst.Dec(debugMathA / 80_000)
    Pst.Str(string(" + ")) 
    Pst.Dec(debugMathB / 80_000)
    Pst.Str(string(" = ")) 
    Pst.Dec(debugMathResult / 80_000)
    Pst.Str(string(" = ")) 
    Pst.Dec((debugMathA + debugMathB) / 80_000)

    Pst.Str(string(11, 13, "accelCount = ")) 
    Pst.Dec(debugAccelCount)
    Pst.Str(string(", swapCount = ")) 
    Pst.Dec(debugSwapCount)
    Pst.Str(string(", loopCount = ")) 
    Pst.Dec(debugLoopCount)
    Pst.Str(string(", slowHalfCount = ")) 
    Pst.Dec(debugSlowHalfCount)
    Pst.Str(string(", getSlowCount = ")) 
    Pst.Dec(debugGetSlowCount)
    
    Pst.Str(string(11, 13, "missed fastHighCount = ")) 
    Pst.Dec(debugFastHighCount)
    Pst.Str(string(", missed slowHighCount = ")) 
    Pst.Dec(debugSlowHighCount)
    Pst.Str(string(", missed fastLowCount = ")) 
    Pst.Dec(debugFastLowCount)
    Pst.Str(string(", octant = ")) 
    Pst.Dec(debugOctant)
  
    Pst.Str(string(11, 13, "new lastHalfStepTime = ")) 
    Pst.Dec(debugNewLastHalfStepTime)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugNewLastHalfStepTime / 80_000)
    Pst.Str(string(" ms, ago =  "))
    Pst.Dec((cnt - debugNewLastHalfStepTime) / 80_000)
    Pst.Str(string(" ms"))                                                         
  while command 'and debugLocationClue <> 999

  Pst.Str(string(11, 13, "End MoveCircle Method ****************************************", 11, 13, 11, 13))
  
  dira[dirPinX] := 1
  dira[dirPinY] := 1
  dira[dirPinZ] := 1
      
DAT                     org
'------------------------------------------------------------------------------
entry                   or      dira, stepMask
maxDelayCog             andn    outa, stepMask

minDelayCog             mov     mailboxAddr, par

                        'mov     byteCount, #4    
delayChangeCog          add     mailboxAddr, #4   ' ** convert to loop

doubleAccel             mov     stepCountdown, #42 ' pointers to initialize
accelIntervalCog        mov     maxDelayAddr, mailboxAddr
accelIntervalsCog       add     maxDelayAddr, #4
accelStepsF             add     accelIntervalCog, destAndSourceIncrement ' increment pointers
accelStepsS             add     accelIntervalsCog, destinationIncrement
decelStepsF             djnz    stepCountdown, #accelIntervalCog
                       
'decelStepsS             nop 'mov     accelIntervalAddr, delayChangeAddr
fullStepsF              nop 'add     accelIntervalAddr, #4
'fullStepsS              nop 'mov     accelIntervalsAddr, accelIntervalAddr
fastPhase               nop 'add     accelIntervalsAddr, #4                                      
slowPhase               wrlong  con111, debugLocationClueFPtr

                        

                        
                                               
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
                        jmp     #pasmCircle
                        
'#0, IDLE_MOTOR, SINGLE_MOTOR, DUAL_MOTOR, TRIPLE_MOTOR, NEW_PARAMETERS_MOTOR

'------------------------------------------------------------------------------
{{
      C[i] = C[i-1] - ((2*C[i])/(4*i+1))
          
}}
'------------------------------------------------------------------------------
'------------------------------------------------------------------------------
DAT driveOne            jmp     #mainPasmLoop

'------------------------------------------------------------------------------
'------------------------------------------------------------------------------
DAT driveTwo            jmp     #mainPasmLoop
                      
'------------------------------------------------------------------------------
driveThree              jmp     #mainPasmLoop         
'------------------------------------------------------------------------------
DAT newParameters       rdlong  maxDelayCog, maxDelayAddr 
                        mov     halfMaxDelayCog, maxDelayCog
                        
                        'jmp     #mainPasmLoop ' ****

                        
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
{PUB MoveCircle(radius, startOctant, distanceOctants) | fastStepMask, slowStepMask, {
} fastDirMask, slowDirMask, radiusOverRoot2, fastIndex, slowIndex, {
} fastDirection, slowDirection, spinScratch}
DAT pasmCircle          rdlong  resultPtr, mailboxAddr                        
                        mov     bufferAddress, resultPtr
                        
                        'jmp     #mainPasmLoop ' ****
                        
                        wrlong  con222, debugLocationClueFPtr
                        'jmp     #$
                        add     bufferAddress, #4
                        rdlong  radiusCog, bufferAddress 'radius
                        add     bufferAddress, #4
                        rdlong  octantCog, bufferAddress 'startOctant            
                        add     bufferAddress, #4
                        rdlong  octantCountdown, bufferAddress 'distanceOctants            
                        add     bufferAddress, #4
                        rdlong  fastMask, bufferAddress 'fastStepMask            
                        add     bufferAddress, #4
                        'mov     fastTotal, zero
                        rdlong  slowMask, bufferAddress 'slowStepMask             
                        add     bufferAddress, #4
                        rdlong  fastDirMaskCog, bufferAddress 'fastDirMask            
                        add     bufferAddress, #4
                        'mov     fastTotal, zero
                        rdlong  slowDirMaskCog, bufferAddress 'slowDirMask             
                        'mov     delayTotal, zero
                        add     bufferAddress, #4
                        'wrlong  bufferAddress, debugDelayTotal
                        rdlong  radiusOverRoot2Cog, bufferAddress 'radiusOverRoot2            
                        add     bufferAddress, #4
                        rdlong  fastPositionCog, bufferAddress   'fastIndex            
                        add     bufferAddress, #4
                        rdlong  slowPositionCog, bufferAddress  'slowIndex        
                        add     bufferAddress, #4
                        rdlong  fastDirectionCog, bufferAddress 'fastDirection 
                        add     bufferAddress, #4
                        rdlong  slowDirectionCog, bufferAddress 'slowDirection
                        add     bufferAddress, #4

                        mov     mathA, radiusCog
                        mov     mathB, radiusCog
                        call    #multiply1
                        mov     rSquared, mathResult
                        
                        call    #setDirectionPins
                        
                        mov     activeDelay, maxDelayCog
                        wrlong  maxDelayCog, debugMaxDelayPtr
                        wrlong  activeDelay, debugActiveDelayPtr
                        
                        mov     accelStepsF, accelIntervalsCog
                       
                        mov     nextSlow, slowPositionCog 
                        'call    #getNextSlow

                        'mov     scratchTime, 
                        mov     lastHalfStepTime, activeDelay
                        shr     lastHalfStepTime, #1

                        wrlong  fastMask, debugFastStepMaskPtr                         
                        wrlong  slowMask, debugSlowStepMaskPtr
                        wrlong  fastDirectionCog, debugFastDirectionPtr
                        wrlong  slowDirectionCog, debugSlowDirectionPtr
     '***********************************
                        'mov     activeDelay, maxDelayCog
                        'wrlong  maxDelayCog, debugMaxDelayPtr
                        'wrlong  activeDelay, debugActiveDelayPtr
                                'cmpsub if d > s write c 
                                'sub    if d < s write c 
                                'cmp    if d < s write c
                                'cmps   if d < s write c signed 
              
                        mov     accelStage, #1

                        'wrlong  delayTotal, debugDelayTotalPtr
                        
                     

                        mov     fastTotal, zero
                        mov     slowTotal, zero
                        {mov     delayTotal, zero
                        mov     delayTotalS, zero}
                        'mov     fastPhase, zero
                        'mov     slowPhase, zero
                        mov     swapCount, zero
                        mov     swappedFlag, zero
                        mov     accelCount, zero
                        mov     loopCount, zero
                        mov     slowHalfCount, zero
                        mov     getSlowCount, zero
                        {mov     fastHighCount, zero
                        mov     slowHighCount, zero   }
                        
     '***********************************                                      
                        
setupAccelC             neg     activeChange, delayChangeCog  ' add a negative number to accel
                        
                        mov     stepCountdown, accelStepsF
                        wrlong  con333, debugLocationClueFPtr
                        wrlong  con100, debugLocationCluePtr
                        'mov     lastHalfStepTime, octantCog ' "lastHalfStepTime" is temp variable
                        'mov     lastAccelTime, octantCountdown
                        'call    #fixInitDirection ' fix initial direction
                        call    #getNextSlow
                        'mov     octantCog, lastHalfStepTime ' prevent advancing "octantCog"
                        'mov     octantCountdown, lastAccelTime
                        wrlong  con110, debugLocationCluePtr
                        mov     lastHalfStepTime, activeDelay
                        shr     lastHalfStepTime, #1
                        neg     lastHalfStepTime, lastHalfStepTime
                        mov     lastHalfStepTimeS, activeDelayS
                        shr     lastHalfStepTimeS, #1
                        neg     lastHalfStepTimeS, lastHalfStepTimeS
                        'mov     lastStepTime, activeDelay
                        'shr     lastStepTime, #1
                        'mov     lastStepTimeS, activeDelayS
                        'shr     lastStepTimeS, #1
                       
                        
                        mov     lastAccelTime, cnt
                        
                        mov     lastStepTime, lastAccelTime
                        'add     lastStepTimeS, lastAccelTime
                        add     lastHalfStepTime, lastAccelTime
                        add     lastHalfStepTimeS, lastAccelTime
                        'add     lastAccelTime, accelIntervalCog
                        'jmp     #mainPasmLoop ' ****                                                
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                       'cmps   if d < s write c signed 
circleLoop              add     loopCount, #1
                        wrlong  loopCount, debugLoopCountPtr
                        mov     now, cnt
                        wrlong  now, debugScratchTime444Ptr
                        mov     scratchTime, now '
                        subs    scratchTime, lastHalfStepTime 
                        cmps    activeDelay, scratchTime wc
                        
                        wrlong  con111, debugLocationCluePtr
              if_c      call    #stepFastHighC

                        mov     scratchTime, now '
                        subs    scratchTime, lastHalfStepTimeS
                        cmps    activeDelayS, scratchTime wc
              if_c      call    #stepSlowHighC

                        mov     scratchTime, now '
                        subs    scratchTime, lastStepTime 
                        cmps    activeDelay, scratchTime wc
              if_c      call    #stepFastLowC


continueCLoop           mov     scratchTime, now 
                        subs    scratchTime, lastAccelTime wc
                        cmps    accelIntervalCog, scratchTime wc 
              if_nc     jmp     #circleLoop
              
                        add     lastAccelTime, accelIntervalCog
                        'tjz     activeChange, #circleLoop ' optional
                        adds    activeDelay, activeChange ' activeChange may be zero, positive or negative
                        mov     lastHalfStepTime, lastStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        subs    lastHalfStepTime, scratchTime

                        add     accelCount, #1
                        wrlong  accelCount, debugAccelCountPtr
'adjustSlowDelayC        adds    activeDelayS, activeChangeS
                        'mov     lastHalfStepTimeS, lastStepTimeS
                        'mov     scratchTime, activeDelayS
                        'shr     scratchTime, #1
                        'sub     lastHalfStepTimeS, scratchTime

                        wrlong  activeDelay, debugNewLastHalfStepTimePtr
                        wrlong  activeDelay, debugActiveDelayPtr
                        jmp     #circleLoop

          '***************************************               
                        
finalizeCircle          call    #releaseDirPins
                        jmp     #mainPasmLoop
                       
'------------------------------------------------------------------------------
DAT 

stepFastHighC           'tjnz    fastPhase, #stepFastHighC_ret
                        tjnz    fastPhase, #stepFastHighC_debug 'stepFastHighC_ret
                        mov     fastHighCount, zero
                        wrlong  fastHighCount, debugFastHighCountPtr

                        or      outa, fastMask
                        mov     fastPhase, #1
                        add     lastHalfStepTime, activeDelay
                        wrlong  con444, debugLocationClueFPtr
                        wrlong  scratchTime, debugScratchTimePtr
                        wrlong  lastHalfStepTime, debugLastHalfTimePtr
                        'add     delayTotal, activeDelay
                        
stepFastHighC_ret       ret
'------------------------------------------------------------------------------
stepFastHighC_debug     add     fastHighCount, #1
                        wrlong  fastHighCount, debugFastHighCountPtr
                        wrlong  con440, debugLocationClueFPtr
                        jmp     #stepFastHighC_ret
'------------------------------------------------------------------------------
'------------------------------------------------------------------------------
stepSlowHighC           'tjnz    slowPhase, #stepSlowHighC_ret
                        tjnz    slowPhase, #stepSlowHighC_debug 'stepSlowHighC_ret
                        mov     slowHighCount, zero
                        wrlong  slowHighCount, debugSlowHighCountPtr

                        or      outa, slowMask
                        mov     slowPhase, #1
                        wrlong  lastHalfStepTimeS, debugMathAPtr
                        wrlong  activeDelay, debugMathBPtr

                        add     slowHalfCount, #1
                        wrlong  slowHalfCount, debugSlowHalfCountPtr
                        
                        add     lastHalfStepTimeS, activeDelayS 
                        
                        wrlong  lastHalfStepTimeS, debugMathResultPtr

                        wrlong  scratchTime, debugScratchTimePtr
                        wrlong  con555, debugLocationClueFPtr
                        wrlong  lastHalfStepTimeS, debugLastHalfTimeSPtr
stepSlowHighC_ret       ret
'------------------------------------------------------------------------------
stepSlowHighC_debug     add     slowHighCount, #1
                        wrlong  slowHighCount, debugSlowHighCountPtr
                        wrlong  con550, debugLocationClueFPtr
                        jmp     #stepFastHighC_ret
'------------------------------------------------------------------------------
'------------------------------------------------------------------------------
stepFastLowC            'tjz     fastPhase, #stepFastLowC_ret
                        tjz     fastPhase, #stepFastLowC_debug
                        mov     fastLowCount, zero
                        wrlong  fastLowCount, debugFastLowCountPtr
                        
                             
                        andn    outa, fastMask
                        mov     fastPhase, zero
                        'wrlong  decelStepsF, debugDecelStepsPtr
 
                        'wrlong  lastStepTime, debugMathAPtr
                        'wrlong  activeDelay, debugMathBPtr
                        
                        add     lastStepTime, activeDelay
                        call    #countdownStepsC
                        wrlong  lastStepTime, debugLastStepTimePtr
                        'wrlong  lastStepTime, debugMathResultPtr
                        
                        'add     con1M, #1
                        'wrlong  con1M, debug1MPtr
                        add     fastTotal, #1
                        wrlong  fastTotal, debugFastTotalPtr  
                        wrlong  con666, debugLocationClueFPtr
                        wrlong  scratchTime, debugScratchTimePtr
                        add     fastPositionCog, fastDirectionCog
                        wrlong  fastPositionCog, debugFastIndexPtr

                               'cmpsub if d > s write c
                                'sub    if d < s write c 
                                'cmp    if d < s write c
                                'cmps   if d < s write c signed 
                        cmp     fastPositionCog, fastAtNextSlow wz
              if_z      call    #getNextSlow              
                        
stepFastLowC_ret        ret
'------------------------------------------------------------------------------
stepFastLowC_debug      add     fastLowCount, #1
                        wrlong  fastLowCount, debugFastLowCountPtr
                        wrlong  con660, debugLocationClueFPtr
                        jmp     #stepFastLowC_ret
'------------------------------------------------------------------------------
'------------------------------------------------------------------------------
'** akward
countdownStepsC         djnz    stepCountdown, #countdownStepsC_ret
                        mov     activeChange, zero
                        mov     activeChangeS, zero
                        'mov     stepCountdown, fullStepsF '** add decel section later
                        'mov     lastAccelDelay, activeDelay 
                       ' mov     lastAccelDelayS, activeDelayS
                        mov     activeDelay, minDelayCog  ' slow will be changed elsewhere
                        
                        wrlong  activeDelay, debugActiveDelayPtr
countdownStepsC_ret     ret
                        'jmp     #fullSpeedStageC
                        'wrlong  accelStage, debugAccelStagePtr
                        'wrlong  stepCountdown, debugStepCountdownPtr
                       { wrlong  con777, debugLocationCluePtr
                        djnz    accelStage, #nextStageC
                        jmp     #fullSpeedStageC
nextStageC              cmp     accelStage, #2 wz
                        
              if_z      jmp     #fullSpeedStageC} '"fullSpeedStageC" returns to circleLoop 
                       ' jmp     #decelStageC  'accelStage equals one decel not used in circle yet

'------------------------------------------------------------------------------

                        jmp     #continueCLoop                    
{stepSlowHighC           tjnz    slowPhase, #stepSlowHighC_ret
                        or      outa, slowMask
                        mov     slowPhase, #1
                        add     lastHalfStepTimeS, activeDelayS
                        'add     con3M, #1
                        'wrlong  con3M, debug3MPtr
                        add     delayTotalS, activeDelayS
                        wrlong  delayTotalS, debugDelayTotalSPtr 'debugSlowTotalDelay
stepSlowHighC_ret       ret }                       
'------------------------------------------------------------------------------
{stepSlowLowC            tjz     slowPhase, #stepSlowLowC_ret
                        andn    outa, slowMask
                        mov     slowPhase, #0
                        add     lastStepTimeS, activeDelayS
                        'add     con2M, #1
                        'wrlong  con2M, debug2MPtr
                        add     slowTotal, #1
                        wrlong  con777, debugLocationClueFPtr
                        wrlong  slowTotal, debugSlowTotalPtr
stepSlowLowC_ret        ret   }

{nextFastHalf            tjnz    fastPhase, #stepFastHigh2_ret
                        or      outa, fastMask
                        mov     fastPhase, #1
                        add     lastHalfStepTime, activeDelay
                        wrlong  lastHalfStepTime, debugLastHalfTimePtr
                        add     delayTotal, activeDelay

                        add     activeDelay
                        mov     stepStateFast, #1
                        or      outa, fastMask
 
nextFastHalf_Ret        ret   }
'------------------------------------------------------------------------------
'nextSlowHalf
'nextSlowHalf_Ret        ret
'------------------------------------------------------------------------------
'nextFastStep
'nextFastStep_Ret        ret
'------------------------------------------------------------------------------
'------------------------------------------------------------------------------
DAT getNextSlow         abs     previousSlow, slowPositionCog
                        mov     slowPositionCog, nextSlow ' increment "slowPositionCog" 
                        wrlong  con888, debugLocationClueFPtr
                        andn    outa, slowMask
                        mov     slowPhase, zero
                        add     slowTotal, #1
                        wrlong  slowTotal, debugSlowTotalPtr
                        add     getSlowCount, #1
                        wrlong  getSlowCount, debugGetSlowCountPtr
                        
                        wrlong  slowPositionCog, debugSlowIndexPtr
                        abs     tmp1, slowPositionCog    ' if we're at an extreme, reverse direction
                        cmp     tmp1, radiusCog wz  ' reverses should only occur on the slow axis
              if_z      call    #reverseDirection

                        wrlong  con101, debugLocationCluePtr
                        abs     tmp2, fastPositionCog
                        cmp     tmp1, tmp2 wz
              if_z      jmp     #swapSpeeds
                        cmp     tmp2, previousSlow wz
              if_z      jmp     #swapSpeeds
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                       
continueNextSlow        adds    nextSlow, slowDirectionCog
                        wrlong  nextSlow, debugNextSlowPtr
                        mov     mathA, nextSlow
                        mov     mathB, nextSlow
                        call    #multiply1
                        mov     nextSlowSquared, mathResult
                        wrlong  nextSlowSquared, nextSlowSquaredPtr
                        mov     mathA, rSquared
                        sub     mathA, nextSlowSquared
                        wrlong  rSquared, rSquaredPtr
                        wrlong  mathA, debugfastAtNextSlowSqPtr
                        call    #squareRoot
                        wrlong  con102, debugLocationCluePtr
                        mov     fastAtNextSlow, mathResult
                                                
                        'fastAtNextSlow is now positive
                        
  'fastAtNextSlow := ^^(rSquared - nextSlowSquared)
'  nextSlow := -radius #> xIndex[presentSlow] + presentDirectionX[presentSlow] <# radius
'  nextSlowSquared := nextSlow * nextSlow
'  fastAtNextSlow := ^^(rSquared - nextSlowSquared)  
                        
                        abs     tmp1, fastPositionCog
                        mov     tmp2, fastAtNextSlow
                        subs    tmp1, tmp2
                        abs     fastStepsPerSlow, tmp1  'fastStepsPerSlow
                        wrlong  fastStepsPerSlow, fastStepsPerSlowPtr
                        mov     tmp1, fastStepsPerSlow
                        mov     activeChangeS, #0
                        mov     activeDelayS, #0
:loop                   add     activeChangeS, activeChange ' multiply by fastStepsPerSlow
                        add     activeDelayS, activeDelay 
                        djnz    tmp1, #:loop
                        wrlong  activeDelayS, debugActiveDelaySPtr
'  lastHalfStep[presentSlow] := cnt - (axisDelay[presentSlow] / 2)
                        mov     lastHalfStepTimeS, activeDelayS
                        shr     lastHalfStepTimeS, #1
                        neg     lastHalfStepTimeS, lastHalfStepTimeS
                        add     lastHalfStepTimeS, cnt
                        wrlong  lastHalfStepTimeS, debugLastHalfTimeSPtr
                        
                        wrlong  con103, debugLocationCluePtr
                        call    #checkFansDirection
afterFansCheck                                  

                        wrlong  fastAtNextSlow, debugfastAtNextSlowPtr
                        wrlong  con104, debugLocationCluePtr


'  fastStepsPerSlow := ||(fastAtNextSlow - xIndex[presentFast])
'  axisDelay[presentSlow] := axisDelay[presentFast] * fastStepsPerSlow
'  axisDeltaDelay[presentSlow] := axisDeltaDelay[presentFast] * fastStepsPerSlow
'  lastHalfStep[presentSlow] := cnt - (axisDelay[presentSlow] / 2)
  
getNextSlow_Ret         ret
'------------------------------------------------------------------------------
reverseDirection        neg     slowDirectionCog, slowDirectionCog
                        call    #incrementOctant
                        call    #setDirectionPins
                        mov     swappedFlag, zero
reverseDirection_Ret    ret
'------------------------------------------------------------------------------
incrementOctant         add     octantCog, #1
                        and     octantCog, #7
                        wrlong  octantCog, debugOctantPtr
                        djnz    octantCountdown, #incrementOctant_Ret
                        jmp     #finalizeCircle
incrementOctant_Ret     ret
'------------------------------------------------------------------------------
' There's a better way of doing this.
' use shr wc and if_c. This will be shorter. Try it later.
fixInitDirection        cmp     octantCog, #0 wz
              if_z      neg     slowDirectionCog, slowDirectionCog
                        cmp     octantCog, #2 wz
              if_z      neg     slowDirectionCog, slowDirectionCog
                        cmp     octantCog, #4 wz
              if_z      neg     slowDirectionCog, slowDirectionCog
                        cmp     octantCog, #6 wz
              if_z      neg     slowDirectionCog, slowDirectionCog
fixInitDirection_Ret    ret                      
                        
  '' Which eight of the circle does the move start? (octantCog)
  '' 4) Cx>0, Cy<0        \2|1/  3) Cx<0, Cy<0
  '' 5) Cx>R/root2, Cy<0  3\|/0  2) Cx<-R/root2, Cy<0
  ''                     ---*---
  '' 6) Cx>R/root2, Cy>0  4/|\7  1) Cx<-R/root2, Cy>0
  '' 7) Cx>0, Cy>0        /5|6\  0) Cx<0, Cy>0
  ''
'' check fastAtNextSlow octant and negate if needed  
checkFansDirection      cmp     octantCog, #2 wz
              if_z      neg     fastAtNextSlow, fastAtNextSlow
                        cmp     octantCog, #4 wz
              if_z      neg     fastAtNextSlow, fastAtNextSlow
                        cmp     octantCog, #5 wz
              if_z      neg     fastAtNextSlow, fastAtNextSlow
                        cmp     octantCog, #7 wz
              if_z      neg     fastAtNextSlow, fastAtNextSlow               
checkFansDirection_Ret  ret
'------------------------------------------------------------------------------
'' values swapped: fastDirMaskCog & slowDirMaskCog, fastMask & slowMask;
'' fastDirectionCog & slowDirectionCog, fastPositionCog & slowPositionCog,
'' fastTotal & slowTotal, fastIndex & slowIndex
'' debugFastTotalPtr & debugSlowTotalPtr
swapSpeeds              tjnz    swappedFlag, #continueNextSlow ' skip if we've already swapped
                        mov     swappedFlag, #1
                        call    #incrementOctant
                        add     swapCount, #1
                        wrlong  swapCount, debugSwapCountPtr
                        mov     tmp2, fastDirMaskCog
                        mov     fastDirMaskCog, slowDirMaskCog  
                        mov     slowDirMaskCog, tmp2  
                        mov     tmp2, fastMask
                        mov     fastMask, slowMask  
                        mov     slowMask, tmp2  
                        mov     tmp2, fastDirectionCog
                        mov     fastDirectionCog, slowDirectionCog  
                        mov     slowDirectionCog, tmp2
                        mov     tmp2, fastTotal
                        mov     fastTotal, slowTotal  
                        mov     slowTotal, tmp2
                        mov     tmp2, fastPositionCog
                        mov     fastPositionCog, slowPositionCog  
                        mov     slowPositionCog, tmp2
                        mov     tmp2, debugFastTotalPtr
                        mov     debugFastTotalPtr, debugSlowTotalPtr
                        wrlong  fastDirectionCog, debugFastDirectionPtr
                        wrlong  slowDirectionCog, debugSlowDirectionPtr
 
                        wrlong  fastMask, debugFastStepMaskPtr ' let us know which way is which
                        
                        mov     debugSlowTotalPtr, tmp2
                  
                        mov     nextSlow, slowPositionCog ' needed so when nextSlow in incremented
                                                          ' we end up with the correct number
                        
                        wrlong  slowMask, debugSlowStepMaskPtr
                        jmp     #continueNextSlow
'------------------------------------------------------------------------------


'------------------------------------------------------------------------------
'------------------------------------------------------------------------------
setDirectionPins        or      dira, fastDirMaskCog
                        or      dira, slowDirMaskCog
                        cmp     fastDirectionCog, #1 wz
              if_z      or      outa, fastDirMaskCog
              if_nz     andn    outa, fastDirMaskCog
                        cmp     slowDirectionCog, #1 wz
              if_z      or      outa, slowDirMaskCog
              if_nz     andn    outa, slowDirMaskCog
setDirectionPins_Ret    ret                              
'------------------------------------------------------------------------------
releaseDirPins          andn    dira, dirMask
                        andn    outa, dirMask
releaseDirPins_Ret      ret  
'------------------------------------------------------------------------------
squareRoot              mov     tmp1, #0
                        mov     mathResult, #0
                        mov     mathLoopCount, #16
:loop                   shl     mathA, #1 wc
                        rcl     tmp1, #1
                        shl     mathA, #1 wc
                        rcl     tmp1, #1
                        shl     mathResult, #2
                        or      mathResult, #1
                        cmpsub  tmp1, mathResult wc
                        shr     mathResult, #2
                        rcl     mathResult, #1
                        djnz    mathLoopCount, #:loop
squareRoot_Ret          ret                                                
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
multiply1      ' setup
                        mov     mathResult, #0      ' Primary accumulator (and final result)
                        mov     tmp1, mathA      ' Both my secondary accumulator,
                        shl     tmp1, #16     ' and the lower 16 bits of mathA.
                        mov     tmp2, mathB      ' This is the upper 16 bits of mathB,
                        shr     tmp2, #16     ' which will sum into my 2nd accumulator.
                        mov     mathLoopCount, #16        ' Instead of 4 instructions 32x, do 6 instructions 16x.          
:loop                   ' mathA_hi_lo * mathB_lo
                        shr     mathB, #1 wc     ' get the low bit of mathB          
              if_c      add     mathResult, mathA      ' (conditionally) sum mathA into my 1st accumulator
                        shl     mathA, #1        ' bit align mathA for the next pass 
                        ' mathA_lo * mathB_hi
                        shl     tmp1, #1 wc   ' get the high bit of mathA_lo, *AND* shift my 2nd accumulator
              if_c      add     tmp1, tmp2    ' (conditionally) add mathB_hi into the 2nd accumulator
                        ' repeat 16x
                        djnz    mathLoopCount, #:loop     ' I can't think of a way to early exit this
                        ' finalize
                        shl     tmp1, #16     ' align my 2nd accumulator
                        add     mathResult, tmp1    ' and add its contribution          
multiply1_ret           ret

'------------------------------------------------------------------------------
{multiply                and     mathB, sixteenBits
                        shl     mathA, #16    
                        mov     loopCount, #16
                        shr     mathB, #1 wc            
:loop         if_c      add     mathB, mathA wc
                        ror     mathB, #1 wc
                        djnz    loopCount, #:loop                            
multiply_ret            ret }
'------------------------------------------------------------------------------
'' Divide mathA[31..0] by mathB[15..0] (mathB[16] must be 0)
'' on exit, quotient is in the mathA[15..0] and remainder is in mathA[31..16]
{divide                  shl     mathB, #15    
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
destinationIncrement    long %10_0000_0000
destAndSourceIncrement  long %10_0000_0001
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
'twelveBits              long $F_FF
bitDelay                long 80
con100                  long 100
con101                  long 101
con102                  long 102
con103                  long 103
con104                  long 104
con110                  long 110
con111                  long 111
con222                  long 222
con333                  long 333
con338                  long 338
con440                  long 440
con444                  long 444
con448                  long 448
con550                  long 550
con555                  long 555
'con556                  long 556
'con557                  long 557
'con558                  long 558
con660                  long 660
con666                  long 666
'con771                  long 771
'con772                  long 772
con777                  long 777
con888                  long 888
con999                  long 999
'con1M                   long 1_000_000
'con2M                   long 2_000_000
'con3M                   long 3_000_000
'con4M                   long 4_000_000
                                           

stepMask                long 1 << Header#STEP_X_PIN | 1 << Header#STEP_Y_PIN | 1 << Header#STEP_Z_PIN
dirMask                 long 1 << Header#DIR_X_PIN | 1 << Header#DIR_Y_PIN | 1 << Header#DIR_Z_PIN
    
'testBufferPtr           long 0-0
'' Start of res section
mailboxAddr             long 0-0 '1
maxDelayAddr            long 0-0   
minDelayAddr            long 0-0   
delayChangeAddr         long 0-0   
accelIntervalAddr       long 0-0   
accelIntervalsAddr      long 0-0  '6

'address165Ptr           long 0-0
debugLastStepTimePtr    long 0-0
debugActiveDelaySPtr    long 0-0
debugActiveDelayPtr     long 0-0
'debugDelayTotalSPtr     long 0-0 '10
'debugDelayTotalPtr      long 0-0   
'debugFullStepsFPtr      long 0-0 ' not used
rSquaredPtr             long 0-0
debugMaxDelayPtr        long 0-0
fastStepsPerSlowPtr     long 0-0
debugLastHalfTimePtr    long 0-0
debugLastHalfTimeSPtr   long 0-0
nextSlowSquaredPtr      long 0-0
debugFastTotalPtr       long 0-0
debugSlowTotalPtr       long 0-0
debugScratchTime444Ptr  long 0-0 '20
debugScratchTimePtr     long 0-0
debugLocationCluePtr    long 0-0
debugLocationClueFPtr   long 0-0
debugNextSlowPtr        long 0-0
debugFastIndexPtr       long 0-0
debugSlowIndexPtr       long 0-0
debugFastStepMaskPtr    long 0-0
debugSlowStepMaskPtr    long 0-0
debugFastDirectionPtr   long 0-0
debugSlowDirectionPtr   long 0-0
debugFastAtNextSlowPtr  long 0-0
debugFastAtNextSlowSqPtr long 0-0
debugMathAPtr           long 0-0
debugMathBPtr           long 0-0
debugMathResultPtr      long 0-0
debugSwapCountPtr       long 0-0
debugOctantPtr          long 0-0
debugNewLastHalfStepTimePtr long 0-0
debugAccelCountPtr      long 0-0     
debugLoopCountPtr       long 0-0
debugSlowHalfCountPtr   long 0-0
debugGetSlowCountPtr    long 0-0
debugSlowHighCountPtr   long 0-0
debugFastHighCountPtr   long 0-0
debugFastLowCountPtr    long 0-0
{debugExtra5Ptr          long 0-0
debugExtra4Ptr          long 0-0
debugExtra3Ptr          long 0-0  }

{debugDecelStepsPtr      long 0-0
debugFullSpeedStepsPtr  long 0-0
debuglastStepTimePtr    long 0-0
debugAccelStagePtr      long 0-0
debugStepCountdownPtr   long 0-0 
debug1MPtr              long 0-0 '30
debug2MPtr              long 0-0 
debug3MPtr              long 0-0 
debug4MPtr              long 0-0
debug1MAPtr             long 0-0 
debug2MAPtr             long 0-0 
debug3MAPtr             long 0-0

debug4MAPtr             long 0-0  
debug1MFPtr             long 0-0 
debug2MFPtr             long 0-0 
debug3MFPtr             long 0-0 '40
debug4MFPtr             long 0-0  
debug1MDPtr             long 0-0 
debug2MDPtr             long 0-0 
debug3MDPtr             long 0-0 
debug4MDPtr             long 0-0  
debugActiveChangePtr    long 0-0 
debugAddressRPtr        long 0-0 
debugActiveChangeSPtr   long 0-0} '48

stepDelay               long 0-0
'wait                    long 0-0
'adcRequest              long 0-0
'activeAdcPtr            long 0-0
resultPtr               long 0-0
'inputData               long 0-0
'outputData              long 0-0

'temp                    long 0-0
'readErrors              long 0-0
'debugPtrCog             long 0-0
mathLoopCount           long 0-0
mathA                   long 0-0
mathB                   long 0-0
mathResult              long 0-0
tmp1                    long 0-0 
tmp2                    long 0-0
fastMask                long 0-0
slowMask                long 0-0
   


halfMaxDelayCog         long 0-0
halfMinDelayCog         long 0-0
'halfDelayChangeCog      long 0-0
'activeHalfDelay         long 0-0
activeDelay             long 0-0
'activeHalfChange        long 0-0
activeChange            long 0-0
'activeHalfDelayS        long 0-0
activeDelayS            long 0-0
'activeHalfChangeS       long 0-0
activeChangeS           long 0-0
commandCog              long 0-0
'dataOutToShred          long 0-0
shiftRegisterInput      long 0-0
'shiftOutputChange       long 0-0
'dataValue               long 0-0
'dataOut                 long 0-0
'byteCount               long 0-0
'lastAccelTime           long 0-0
fastTotal               long 0-0
slowTotal               long 0-0
delayTotal              long 0-0
delayTotalS             long 0-0
fastDistance            long 0-0
slowDistance            long 0-0
lastAccelTime           long 0-0
'lastAccelTimeS          long 0-0
lastStepTime            long 0-0
lastStepTimeS           long 0-0
lastHalfStepTime        long 0-0
lastHalfStepTimeS       long 0-0
lastAccelDelay          long 0-0
lastAccelDelayS         long 0-0
'lastAccelHalfDelay      long 0-0
'lastAccelHalfDelayS     long 0-0
shortFlag               long 0-0
minHalfDelayCog         long 0-0
minHalfDelayCogS        long 0-0
scratchTime             long 0-0
minDelayCogS            long 0-0
accelStage              long 0-0
'negativeChange          long 0-0
delayChangeCogS         long 0-0
stepCountdown           long 0-0
radiusCog               long 0-0
octantCog               long 0-0
octantCountdown         long 0-0
radiusOverRoot2Cog      long 0-0
fastPositionCog         long 0-0
slowPositionCog         long 0-0
fastDirectionCog        long 0-0
slowDirectionCog        long 0-0
fastDirMaskCog          long 0-0
slowDirMaskCog          long 0-0
nextSlow                long 0-0
rSquared                long 0-0
fastStepsPerSlow        long 0-0
previousSlow            long 0-0
'radiusCog               long 0-0
nextSlowSquared         long 0-0
fastAtNextSlow          long 0-0
now                     long 0-0
swapCount               long 0-0
accelCount              long 0-0
loopCount               long 0-0
slowHalfCount           long 0-0
getSlowCount            long 0-0
slowHighCount           long 0-0
fastHighCount           long 0-0
fastLowCount            long 0-0 
swappedFlag             long 0-0
                        fit

DAT