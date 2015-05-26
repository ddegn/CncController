DAT objectName          byte "MotorControlOld", 0
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

address165              long 0-0
debugActiveDelayS       long 0-0
debugActiveDelay        long 0-0
debugDelayTotalS        long 0-0
debugDelayTotal         long 0-0   
debugFullStepsF         long 0-0
debugAddress5           long 0-0
debugMaxDelay           long 0-0
debugAddress7           long 0-0
debugLastHalfTime       long 0-0
debugAddress9           long 0-0
debugFastTotal          long 0-0
debugSlowTotal          long 0-0
debugScratchTime111     long 0-0
debugScratchTime        long 0-0
debugLocationClue       long 0-0
debugLocationClueF      long 0-0
debugAccelSteps         long 0-0
{
debugDecelSteps         long 0-0
debugFullSpeedSteps     long 0-0
debuglastStepTime       long 0-0
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
debugActiveChangeS      long 0-0}

'accelMaxIntervals       long 0-0

'debugAddress            long 0-0
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
directionFast           long  1, -1, -1  -1, -1,  1,  1,  1
                            ' 0   1   2   3   4   5   6   7
                            ' X   Y   Y   X   X   Y   Y   X
directionSlow           long -1,  1, -1, -1,  1  -1,  1,  1
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

  address165 := address165_
 
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
    Pst.Dec(debugAccelSteps)
    
    Pst.Str(string(11, 13, "maxDelayCog = ")) 
    Pst.Dec(debugMaxDelay)
    Pst.Str(string(", PASM scratchTime = ")) 
    Pst.Dec(debugScratchTime111)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugScratchTime111 / 80_000)
    Pst.Str(string(", scratchTime (accel) = ")) 
    Pst.Dec(debugScratchTime)
    Pst.Str(string(11, 13, "Spin scratchTime = ")) 
    spinScratch := debugLastHalfTime - cnt
    Pst.Dec(spinScratch)
    Pst.Str(string(" or ")) 
    Pst.Dec(spinScratch / 80_000)
    Pst.Str(string(" ms")) 
       
    Pst.Str(string(11, 13, "accelStepsF = ")) 
    Pst.Dec(debugAccelSteps)   
    Pst.Str(string(", fullStepsF = ")) 
    Pst.Dec(debugFullSpeedSteps)   
    Pst.Str(string(", decelStepsF = ")) 
    Pst.Dec(debugDecelSteps)   
    Pst.Str(string(", a+f+d = ")) 
    Pst.Dec(debugAccelSteps + debugFullSpeedSteps + debugDecelSteps)   
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
    Pst.Dec(debugAccelSteps)
    
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
    'Pst.Dec(debugAccelSteps)
    Pst.Str(string(11, 13, "activeChange = ")) 
    Pst.Dec(debugActiveChange)
    Pst.Str(string(", ")) 
    Pst.Dec(debugActiveChangeS)
   
    
    Pst.Str(string(11, 13, "maxDelayCog = ")) 
    Pst.Dec(debugMaxDelay)
    Pst.Str(string(", PASM scratchTime = ")) 
    Pst.Dec(debugScratchTime111)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugScratchTime111 / 80_000)
    Pst.Str(string(", scratchTime (accel) = ")) 
    Pst.Dec(debugScratchTime)
    Pst.Str(string(11, 13, "Spin scratchTime = ")) 
    spinScratch := debugLastHalfTime - cnt
    Pst.Dec(spinScratch)
    Pst.Str(string(" or "))
    Pst.Dec(spinScratch / 80_000)
    Pst.Str(string(" ms"))
       
    Pst.Str(string(11, 13, "accelStepsF = ")) 
    Pst.Dec(debugAccelSteps)   
    Pst.Str(string(", fullStepsF = "))
    Pst.Dec(debugFullSpeedSteps)   
    Pst.Str(string(", decelStepsF = ")) 
    Pst.Dec(debugDecelSteps)   
    Pst.Str(string(", a+f+d = "))
    Pst.Dec(debugAccelSteps + debugFullSpeedSteps + debugDecelSteps)   
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
} fastDirMask, slowDirMask, radiusOverRoot2, fastIndex, slowIndex, {xIndex, yIndex, 
} fastDirection, slowDirection, spinScratch
  '' Which eight of the circle does the move start? (Piece of Eight)
  '' 4) Cx>0, Cy<0        \2|1/  3) Cx<0, Cy<0
  '' 5) Cx>R/root2, Cy<0  3\|/0  2) Cx<-R/root2, Cy<0
  ''                     ---*---
  '' 6) Cx>R/root2, Cy>0  4/|\7  1) Cx<-R/root2, Cy>0
  '' 7) Cx>0, Cy>0        /5|6\  0) Cx<0, Cy>0
  ''     
  radiusOverRoot2 := radius * Header#SCALED_MULTIPLIER / Header#SCALED_ROOT_2

  fastStepMask := stepMaskFast[startOctant]
  slowStepMask := stepMaskSlow[startOctant]
  fastDirMask := dirMaskFast[startOctant]
  slowDirMask := dirMaskSlow[startOctant]
  fastDirection := directionFast[startOctant]
  slowDirection := directionSlow[startOctant]

  dira[dirPinX] := 0
  dira[dirPinY] := 0
  dira[dirPinZ] := 0
  
  case startOctant  ' come up with a better algorithm for fill these values
    0:
      slowIndex {xIndex} := 0
      fastIndex := -radius 'yIndex := -radius
    1:
      fastIndex {xIndex} := radiusOverRoot2 
      slowIndex {yIndex} := -radiusOverRoot2
    2:
      fastIndex {xIndex} := radius
      slowIndex {yIndex} := 0
    3:
      slowIndex {xIndex} := radiusOverRoot2 
      fastIndex {yIndex} := radiusOverRoot2
    4:
      slowIndex {xIndex} := 0
      fastIndex {yIndex} := radius
    5:
      fastIndex {xIndex} := -radiusOverRoot2 
      slowIndex {yIndex} := radiusOverRoot2
    6:
      fastIndex {xIndex} := -radius
      slowIndex {yIndex} := 0
    7:
      slowIndex {xIndex} := -radiusOverRoot2 
      fastIndex {yIndex} := -radiusOverRoot2

  longfill(@debugActiveDelayS, 0, 16)
  

  'Cnc.PressToContinue
  
  mailbox := @result

  'SetCommand(Header#CIRCLE_MOTOR)
  command := Header#CIRCLE_MOTOR
  repeat 'while command          '' Wait for command to be cleared, signifying receipt
    Pst.Str(string(11, 13, "location = ")) ' watch progress
    Pst.Dec(debugLocationClueF)
    {Pst.Str(string(", ")) 
    Pst.Dec(debugLocationClue)
    Pst.Str(string(", fastTotal = ")) 
    Pst.Dec(debugFastTotal)
    Pst.Str(string(", activeDelay = ")) 
    Pst.Dec(debugActiveDelay)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugActiveDelay / 80_000)  }
    Pst.Str(string(", debugLastHalfTime = ")) 
    Pst.Dec(debugLastHalfTime)
    Pst.Str(string(" or ")) 
    Pst.Dec(debugLastHalfTime / 80_000)
    Pst.Str(string(" ms  ")) 
     
    Pst.Str(string(", scratchTime = ")) 
    spinScratch := cnt - debugLastHalfTime
    Pst.Dec(spinScratch)      
    Pst.Str(string(" or ")) 
    Pst.Dec(spinScratch / 80_000)
    Pst.Str(string(" ms"))                     
  while command 'and debugLocationClue <> 999

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

doubleAccel             mov     stepCountdown, #23 '47 ' 48 pointers to initialize
accelIntervalCog        mov     maxDelayAddr, mailboxAddr
accelIntervalsCog       add     maxDelayAddr, #4
accelStepsF             add     accelIntervalCog, destAndSourceIncrement ' increment pointers
accelStepsS             add     accelIntervalsCog, destinationIncrement
decelStepsF             djnz    stepCountdown, #accelIntervalCog
                       
decelStepsS             nop 'mov     accelIntervalAddr, delayChangeAddr
fullStepsF              nop 'add     accelIntervalAddr, #4
fullStepsS              nop 'mov     accelIntervalsAddr, accelIntervalAddr
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
DAT driveOne            {rdlong  resultPtr, mailboxAddr                        
                        mov     bufferAddress, resultPtr
                        wrlong  con222, debugLocationClueFPtr
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
                        wrlong  maxDelayCog, debugMaxDelayPtr
                        mov     activeChange, delayChangeCog
                        wrlong  activeDelay, debugActiveDelayPtr
                        
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
                       
                        mov     lastAccelTime, cnt
                        mov     lastStepTime, lastAccelTime
                        mov     lastHalfStepTime, lastAccelTime
                        sub     lastHalfStepTime, halfMaxDelayCog
                        add     lastAccelTime, accelIntervalCog
                        
accelLoopSingle         djnz    accelStepsF, #accelSingleBody
                        wrlong  con777, debugLocationCluePtr
                        jmp     #fullSpeedSizeCheck
' exit acceleration loop                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
                        
accelSingleBody         call    #stepFastHigh
'                                                
firstPartOfStepA        mov     scratchTime, lastHalfStepTime
                        sub     scratchTime, cnt wc
                        'cmp     lastHalfStepTime, cnt wc  ' ** use waitcnt instead?
                        wrlong  scratchTime, debugScratchTime111Ptr
                        'mov     lastHalfStepTimeS, cnt
                        'wrlong  lastHalfStepTimeS, debugScratchTime
                        wrlong  con111, debugLocationCluePtr
              if_nc     jmp     #firstPartOfStepA
              
                        andn    outa, fastMask
                        
secondPartOfStepA       mov     scratchTime, lastStepTime
                        sub     scratchTime, cnt wc
                        'cmp     lastStepTime, cnt wc
                        wrlong  scratchTime, debugScratchTime111Ptr
                        wrlong  con222, debugLocationCluePtr
              if_nc     jmp     #secondPartOfStepA
                        wrlong  con771, debugLocationCluePtr
                        mov     scratchTime, lastAccelTime
                        sub     scratchTime, cnt wc
                        'cmp     lastAccelTime, cnt wc ' check if acceleration time
                        wrlong  scratchTime, debugScratchTimePtr
              if_nc     jmp     #accelLoopSingle

decreaseDelay           sub     activeDelay, activeChange
                        mov     lastHalfStepTime, lastStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     lastHalfStepTime, scratchTime
                        wrlong  activeDelay, debugActiveDelayPtr
                        add     lastAccelTime, accelIntervalCog
                        jmp     #accelLoopSingle
                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
' begin full speed
fullSpeedSizeCheck      mov     lastAccelDelay, activeDelay
                        'mov     lastAccelHalfDelay, activeHalfDelay
                        wrlong  con999, debugLocationCluePtr
                        wrlong  fullStepsF, debugFullStepsFPtr
                        'jmp     #$
' Remember last acceleration delay so the decel delays calculate correctly.
                                                                                                        
                        tjz     shortFlag, #fullSpeedLoopEnter 'shortCenter
' We want to know if we should use minDelayCog or the last computed delay.

' The code below is used is full speed is reached in the acceleration section.                        
                        mov     activeDelay, minDelayCog
                        mov     lastHalfStepTime, lastStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     lastHalfStepTime, scratchTime
                        
fullSpeedLoopEnter      wrlong  con554, debugLocationClueFPtr
                        wrlong  activeDelay, debugActiveDelayPtr
fullSpeedLoop           djnz    fullStepsF, #fullSpeedSingleBody ' awkward code
' We previously added one to fullStepsF so this fist djnz doesn't mess out the step count.
                        wrlong  con556, debugLocationClueFPtr
                        jmp     #decelSingleEnter
' exit full speed loop
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


fullSpeedSingleBody     call    #stepFastHigh
                        wrlong  con557, debugLocationClueFPtr
firstPartOfStepFull     mov     scratchTime, lastHalfStepTime
                        sub     scratchTime, cnt wc
                        'cmp     lastHalfStepTime, cnt wc  ' ** use waitcnt instead?
                        wrlong  con338, debugLocationCluePtr
              if_nc     jmp     #firstPartOfStepFull
              
                        andn    outa, fastMask
                        wrlong  con558, debugLocationClueFPtr
secondPartOfStepFull    mov     scratchTime, lastStepTime
                        sub     scratchTime, cnt wc
                        'cmp     lastStepTime, cnt wc
                        wrlong  con448, debugLocationCluePtr
              if_nc     jmp     #secondPartOfStepFull
                        wrlong  con888, debugLocationCluePtr
                        jmp     #fullSpeedLoop
                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
' decelerate

decelSingleEnter        wrlong  con772, debugLocationClueFPtr
                        mov     activeDelay, lastAccelDelay
                        'debugFullStepsF
                        'jmp     #$
''**************************************************************                       
                        'mov     activeHalfDelay, lastAccelHalfDelay
                        mov     lastAccelTime, lastStepTime ' ** not sure about timing
                        'mov     lastAccelTime, lastStepTime ' ** not sure about timing
                        add     lastAccelTime, accelIntervalCog
' Use last acceleration delay so the decel delays calculate correctly.
                                                                                                        
                        
decelLoopSingle         djnz    decelStepsF, #decelSingleBody

                        jmp     #finishSingleMove
' exit deceleration loop                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
 
decelSingleBody         call    #stepFastHigh

firstPartOfStepD        mov     scratchTime, lastHalfStepTime
                        sub     scratchTime, cnt wc
                        'cmp     lastHalfStepTime, cnt wc  ' ** use waitcnt instead?
                        wrlong  con555, debugLocationCluePtr
              if_nc     jmp     #firstPartOfStepD
              
                        andn    outa, fastMask
                        
secondPartOfStepD       mov     scratchTime, lastStepTime
                        sub     scratchTime, cnt wc
                        'cmp     lastStepTime, cnt wc
                        wrlong  con666, debugLocationCluePtr
              if_nc     jmp     #secondPartOfStepD

                        wrlong  con999, debugLocationCluePtr
              
                        mov     scratchTime, lastAccelTime
                        sub     scratchTime, cnt wc
                        'cmp     lastAccelTime, cnt wc ' check if acceleration time
              if_nc     jmp     #decelLoopSingle'cceleration

increaseDelay           add     activeDelay, activeChange
                        mov     lastHalfStepTime, lastStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     lastHalfStepTime, scratchTime
                        wrlong  activeDelay, debugActiveDelayPtr
                        add     lastAccelTime, accelIntervalCog
                        jmp     #decelLoopSingle
                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

finishSingleMove        wrlong  con999, debugLocationClueFPtr }
                        jmp     #mainPasmLoop

'------------------------------------------------------------------------------
{setFullSpeedSingleSteps mov     accelStepsF, accelIntervalsCog
                        mov     decelStepsF, accelIntervalsCog
                        'mov     fullStepsF, fastDistance
                        mov     shortFlag, zero
                        wrlong  con333, debugLocationClueFPtr
                        jmp     #continueSingleSetup
'------------------------------------------------------------------------------
setLowSpeedSingleSteps  mov     accelStepsF, fastDistance
                        shr     accelStepsF, #1
                        mov     decelStepsF, accelStepsF
                        mov     shortFlag, #1
                        wrlong  con444, debugLocationClueFPtr
                        jmp     #continueSingleSetup 
'------------------------------------------------------------------------------
accelerateSingle
accelerateSingle_ret    ret

'------------------------------------------------------------------------------
setupNextStep

'------------------------------------------------------------------------------
DAT stepFastHigh        or      outa, fastMask
                        add     lastHalfStepTime, activeDelay 'activeHalfDelay
                        wrlong  lastHalfStepTime, debugLastHalfTimePtr
                        add     delayTotal, activeDelay
                        wrlong  delayTotal, debugDelayTotalPtr
                        'wrlong  fullStepsF, debugFullSpeedStepsPtr
                        wrlong  accelStepsF, debugAccelStepsPtr
                        'wrlong  decelStepsF, debugDecelStepsPtr
                                
                        add     lastStepTime, activeDelay
                        'wrlong  lastStepTime, debuglastStepTimePtr
                        
                        add     fastTotal, #1
                        wrlong  fastTotal, debugFastTotalPtr 'totalFromPasmFastPtr
stepFastHigh_ret        ret
'------------------------------------------------------------------------------
stepSlowHigh            or      outa, slowMask
                        add     lastHalfStepTimeS, activeDelayS
                        add     delayTotalS, activeDelayS
                        wrlong  delayTotalS, debugFullStepsFPtr
                        add     lastStepTimeS, activeDelayS
                        add     slowTotal, #1
                        wrlong  slowTotal, debugSlowTotalPtr 'totalFromPasmFastPtr
stepSlowHigh_ret        ret  }
'------------------------------------------------------------------------------
'------------------------------------------------------------------------------
DAT driveTwo            {rdlong  resultPtr, mailboxAddr                        
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
                        wrlong  maxDelayCog, debugMaxDelayPtr
                        wrlong  activeDelay, debugActiveDelayPtr
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

                        wrlong  delayTotal, debugDelayTotalPtr
                        'wrlong  fullStepsF, debugFullSpeedStepsPtr
                        wrlong  accelStepsF, debugAccelStepsPtr
                        'wrlong  accelStage, debugAccelStagePtr

                        mov     fastTotal, zero
                        mov     slowTotal, zero
                        mov     delayTotal, zero
                        mov     delayTotalS, zero
                        mov     fastPhase, zero
                        mov     slowPhase, zero
                                                              
setupAccel              neg     activeChange, delayChangeCog  ' add a negative number to accel
                        neg     activeChangeS, delayChangeCogS 
                        mov     stepCountdown, accelStepsF
                        'wrlong  stepCountdown, debugStepCountdownPtr

                        'wrlong  activeChange, debugActiveChangePtr
                        'wrlong  activeChangeS, debugActiveChangeSPtr
                        
' Add one to fullStepsF other acceleration steps to allow the use of djnz later.
                                         
                        'mov     stepDelay, activeHalfDelay
                       
                        mov     lastAccelTime, cnt
                        mov     lastStepTime, lastAccelTime
                        mov     lastHalfStepTime, lastAccelTime
                        sub     lastHalfStepTime, halfMaxDelayCog

                        mov     lastStepTimeS, lastAccelTime
                        mov     lastHalfStepTimeS, lastAccelTime
                        mov     scratchTime, activeDelayS
                        shr     scratchTime, #1
                        sub     lastHalfStepTimeS, scratchTime

                        add     lastAccelTime, accelIntervalCog
                      
                        
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
dualLoop                mov     scratchTime, lastHalfStepTime
                        sub     scratchTime, cnt wc
                        wrlong  scratchTime, debugScratchTime111Ptr
                        wrlong  con111, debugLocationCluePtr
              if_c      jmp     #stepFastLow2
continueDualLoop        mov     scratchTime, lastHalfStepTimeS
                        sub     scratchTime, cnt wc
              if_c      call    #stepSlowLow2
                        mov     scratchTime, lastStepTimeS
                        sub     scratchTime, cnt wc
              if_c      call    #stepSlowHigh2
                        mov     scratchTime, lastStepTime
                        sub     scratchTime, cnt wc
              if_c      call    #stepFastHigh2
              
checkForAcceleration    mov     scratchTime, lastAccelTime
                        sub     scratchTime, cnt wc
              if_nc     jmp     #dualLoop
              
                        add     lastAccelTime, accelIntervalCog
                        tjz     activeChange, #dualLoop ' optional
                        adds    activeDelay, activeChange ' activeChange may be zero, positive or negative
                        mov     lastHalfStepTime, lastStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     lastHalfStepTime, scratchTime

adjustSlowDelay         adds    activeDelayS, activeChangeS
                        mov     lastHalfStepTimeS, lastStepTimeS
                        mov     scratchTime, activeDelayS
                        shr     scratchTime, #1
                        sub     lastHalfStepTimeS, scratchTime

                        wrlong  activeDelay, debugActiveDelayPtr
                        jmp     #dualLoop


' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

finalDual               call    #stepSlowLow2  ' Finish slow step too
                        'wrlong  con1M, debug1MDPtr
                        'wrlong  con2M, debug2MDPtr
                        'wrlong  con3M, debug3MDPtr
                        'wrlong  con4M, debug4MDPtr
                        wrlong  con999, debugLocationClueFPtr }
                        jmp     #mainPasmLoop

'------------------------------------------------------------------------------
{setFullSpeedDualSteps   mov     accelStepsF, accelIntervalsCog
                        mov     decelStepsF, accelIntervalsCog
                        'mov     fullStepsF, fastDistance
                        mov     shortFlag, zero
                        wrlong  con333, debugLocationClueFPtr
                        jmp     #continueDualSetup
'------------------------------------------------------------------------------
setLowSpeedDualSteps    mov     accelStepsF, fastDistance
                        shr     accelStepsF, #1
                        mov     decelStepsF, accelStepsF
                        mov     shortFlag, #1
                        wrlong  con444, debugLocationClueFPtr
                        jmp     #continueDualSetup

'------------------------------------------------------------------------------
fullSpeedStageDual      mov     activeChange, zero
                        mov     activeChangeS, zero
                        mov     stepCountdown, fullStepsF
                        mov     lastAccelDelay, activeDelay 
                        mov     lastAccelDelayS, activeDelayS
                        wrlong  activeDelay, debugActiveDelayPtr
                        'wrlong  activeChange, debugActiveChangePtr
                        'wrlong  activeChangeS, debugActiveChangeSPtr
                        'wrlong  con1M, debug1MAPtr
                        'wrlong  con2M, debug2MAPtr
                        'wrlong  con3M, debug3MAPtr
                        'wrlong  con4M, debug4MAPtr
                        
                        tjnz    shortFlag, #continueDualLoop ' present delays okay
                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
' setup full speed with full acceleration intervals, adjust delays for max speed

                        mov     activeDelay, minDelayCog 
                        mov     lastHalfStepTime, lastStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     lastHalfStepTime, scratchTime
                        
                        mov     activeDelayS, minDelayCogS
                        mov     lastHalfStepTimeS, lastStepTimeS
                        mov     scratchTime, activeDelayS
                        shr     scratchTime, #1
                        sub     lastHalfStepTimeS, scratchTime
                        jmp     #continueDualLoop 

'------------------------------------------------------------------------------
decelStageDual          mov     activeChange, delayChangeCog
                        mov     activeChangeS, delayChangeCogS
                        mov     stepCountdown, decelStepsF
                        'wrlong  activeChange, debugActiveChangePtr
                        'wrlong  activeChangeS, debugActiveChangeSPtr
                        'wrlong  con1M, debug1MFPtr
                        'wrlong  con2M, debug2MFPtr
                        'wrlong  con3M, debug3MFPtr
                        'wrlong  con4M, debug4MFPtr
                         
                        tjnz    shortFlag, #continueDualLoop  ' present delays okay
                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
' setup deceleration from full speed, adjust delays back to last acceleration delays

                        mov     activeDelay, lastAccelDelay 
                        mov     lastHalfStepTime, lastStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     lastHalfStepTime, scratchTime
                        
                        mov     activeDelayS, lastAccelDelayS
                        mov     lastHalfStepTimeS, lastStepTimeS
                        mov     scratchTime, activeDelayS
                        shr     scratchTime, #1
                        sub     lastHalfStepTimeS, scratchTime
                        jmp     #continueDualLoop 
 
'------------------------------------------------------------------------------
DAT 

stepFastHigh2           tjnz    fastPhase, #stepFastHigh2_ret
                        or      outa, fastMask
                        mov     fastPhase, #1
                        add     lastHalfStepTime, activeDelay
                        wrlong  lastHalfStepTime, debugLastHalfTimePtr
                        add     delayTotal, activeDelay
                        
                        'add     con4M, #1
                        'wrlong  con4M, debug4MPtr 
                        'wrlong  accelStage, debugAccelStagePtr
                        'wrlong  stepCountdown, debugStepCountdownPtr
                        
stepFastHigh2_ret       ret
'------------------------------------------------------------------------------
stepFastLow2            tjz     fastPhase, #continueDualLoop 
                             
                        andn    outa, fastMask
                        mov     fastPhase, zero
                        'wrlong  decelStepsF, debugDecelStepsPtr                          
                        add     lastStepTime, activeDelay
                        'wrlong  lastStepTime, debuglastStepTimePtr
                        'add     con1M, #1
                        'wrlong  con1M, debug1MPtr
                        add     fastTotal, #1
                        wrlong  fastTotal, debugFastTotalPtr 
'stepFastLow2_ret        ret
countdownSteps          djnz    stepCountdown, #continueDualLoop  'stepFastHigh2
                        'wrlong  accelStage, debugAccelStagePtr
                        'wrlong  stepCountdown, debugStepCountdownPtr
                        wrlong  con777, debugLocationCluePtr
                        djnz    accelStage, #nextStage
                        jmp     #finalDual
nextStage               cmp     accelStage, #2 wz
                        
              if_z      jmp     #fullSpeedStageDual '"fullSpeedStageDual" returns to dualLoop 
                        jmp     #decelStageDual  'accelStage equals one
'------------------------------------------------------------------------------
stepSlowHigh2           tjnz    slowPhase, #stepSlowHigh2_ret
                        or      outa, slowMask
                        mov     slowPhase, #1
                        add     lastHalfStepTimeS, activeDelayS
                        'add     con3M, #1
                        'wrlong  con3M, debug3MPtr
                        add     delayTotalS, activeDelayS
                        wrlong  delayTotalS, debugDelayTotalSPtr 'debugSlowTotalDelay
stepSlowHigh2_ret       ret                        
'------------------------------------------------------------------------------
stepSlowLow2            tjz     slowPhase, #stepSlowLow2_ret
                        andn    outa, slowMask
                        mov     slowPhase, #0
                        add     lastStepTimeS, activeDelayS
                        'add     con2M, #1
                        'wrlong  con2M, debug2MPtr
                        add     slowTotal, #1
                        wrlong  slowTotal, debugSlowTotalPtr
stepSlowLow2_ret        ret  }                      
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
{PUB MoveCircle(radius, startOctant, distanceOctants) | fastStepMask, slowStepMask, {
} fastDirMask, slowDirMask, radiusOverRoot2, xIndex, yIndex, {
} fastDirection, slowDirection}
DAT pasmCircle          rdlong  resultPtr, mailboxAddr                        
                        mov     bufferAddress, resultPtr
                        wrlong  con222, debugLocationClueFPtr
                        'jmp     #$
                        add     bufferAddress, #4
                        rdlong  radiusCog, bufferAddress
                        add     bufferAddress, #4
                        rdlong  octantCog, bufferAddress             
                        add     bufferAddress, #4
                        rdlong  octantCountdown, bufferAddress             
                        add     bufferAddress, #4
                        rdlong  fastMask, bufferAddress             
                        add     bufferAddress, #4
                        mov     fastTotal, zero
                        rdlong  slowMask, bufferAddress              
                        add     bufferAddress, #4
                        rdlong  fastDirMaskCog, bufferAddress             
                        add     bufferAddress, #4
                        mov     fastTotal, zero
                        rdlong  slowDirMaskCog, bufferAddress              
                        mov     delayTotal, zero
                        add     bufferAddress, #4
                        'wrlong  bufferAddress, debugDelayTotal
                        rdlong  radiusOverRoot2Cog, bufferAddress             
                        add     bufferAddress, #4
                        rdlong  fastCog, bufferAddress             
                        add     bufferAddress, #4
                        rdlong  slowCog, bufferAddress ' is this used?            
                        add     bufferAddress, #4
                        rdlong  fastDirectionCog, bufferAddress 
                        add     bufferAddress, #4
                        rdlong  slowDirectionCog, bufferAddress 
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
                       
                        mov     nextSlow, slowCog 
                        'call    #getNextSlow

                        'mov     scratchTime, 
                        mov     lastHalfStepTime, activeDelay
                        shr     lastHalfStepTime, #1
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
                        'wrlong  accelStepsF, debugAccelStepsPtr
                     

                        mov     fastTotal, zero
                        mov     slowTotal, zero
                        mov     delayTotal, zero
                        mov     delayTotalS, zero
                        mov     fastPhase, zero
                        mov     slowPhase, zero
     '***********************************                                      
                        
setupAccelC             neg     activeChange, delayChangeCog  ' add a negative number to accel
                        
                        mov     stepCountdown, accelStepsF
                        wrlong  con333, debugLocationClueFPtr
                        call    #getNextSlow
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
                        adds    lastHalfStepTime, lastAccelTime
                        adds    lastHalfStepTimeS, lastAccelTime
                        'add     lastAccelTime, accelIntervalCog
                                                                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                       'cmps   if d < s write c signed 
circleLoop              mov     now, cnt
                        mov     scratchTime, now '
                        subs    scratchTime, lastHalfStepTime 
                        cmps    activeDelay, scratchTime wc
                        wrlong  scratchTime, debugScratchTime111Ptr
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


continueCLoop          {mov     scratchTime, now '
                        sub     scratchTime, lastHalfStepTimeS wc
              if_c      call    #stepSlowLowC   }
                       { mov     scratchTime, lastStepTimeS
                        sub     scratchTime, cnt wc
              if_c      call    #stepSlowHighC 
                        mov     scratchTime, lastStepTime
                        sub     scratchTime, cnt wc
              if_c      call    #stepFastHighC }
              
checkForAccelerationC   mov     scratchTime, now 
                        subs    scratchTime, lastAccelTime wc
                        cmps    accelIntervalCog, scratchTime wc 
              if_nc     jmp     #circleLoop
              
                        add     lastAccelTime, accelIntervalCog
                        'tjz     activeChange, #circleLoop ' optional
                        adds    activeDelay, activeChange ' activeChange may be zero, positive or negative
                        mov     lastHalfStepTime, lastStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     lastHalfStepTime, scratchTime

adjustSlowDelayC        adds    activeDelayS, activeChangeS
                        'mov     lastHalfStepTimeS, lastStepTimeS
                        'mov     scratchTime, activeDelayS
                        'shr     scratchTime, #1
                        'sub     lastHalfStepTimeS, scratchTime

                        wrlong  activeDelay, debugActiveDelayPtr
                        jmp     #circleLoop

          '***************************************               
                        
finalizeCircle          call    #releaseDirPins
                        jmp     #mainPasmLoop
 {mov     stepCountdown, #24
                        mov     t1, txbuff_ptr_cog
copyToCog1              rdlong  rxmask_cog, t1
                        add     copyToCog1, destinationIncrement
                        add     t1, #4
                        djnz    stepCountdown, #copyToCog1}                         
'------------------------------------------------------------------------------
DAT 

stepFastHighC           tjnz    fastPhase, #stepFastHighC_ret
                        or      outa, fastMask
                        mov     fastPhase, #1
                        add     lastHalfStepTime, activeDelay
                        wrlong  con444, debugLocationClueFPtr
                        wrlong  lastHalfStepTime, debugLastHalfTimePtr
                        'add     delayTotal, activeDelay
                        
stepFastHighC_ret       ret
'------------------------------------------------------------------------------
stepSlowHighC           tjnz    slowPhase, #stepFastHighC_ret
                        or      outa, slowMask
                        mov     slowPhase, #1
                        add     lastHalfStepTimeS, activeDelay  ' not really needed
                        wrlong  con555, debugLocationClueFPtr
stepSlowHighC_ret       ret
'------------------------------------------------------------------------------
stepFastLowC            tjz     fastPhase, #stepFastLowC_ret
                             
                        andn    outa, fastMask
                        mov     fastPhase, zero
                        'wrlong  decelStepsF, debugDecelStepsPtr                          
                        add     lastStepTime, activeDelay
                        'wrlong  lastStepTime, debuglastStepTimePtr
                        'add     con1M, #1
                        'wrlong  con1M, debug1MPtr
                        add     fastTotal, #1
                        wrlong  con666, debugLocationClueFPtr
                        wrlong  fastTotal, debugFastTotalPtr 
stepFastLowC_ret        ret
'------------------------------------------------------------------------------

countdownStepsC         djnz    stepCountdown, #continueCLoop  'stepFastHigh2
                        jmp     #fullSpeedStageC
                        'wrlong  accelStage, debugAccelStagePtr
                        'wrlong  stepCountdown, debugStepCountdownPtr
                       { wrlong  con777, debugLocationCluePtr
                        djnz    accelStage, #nextStageC
                        jmp     #fullSpeedStageC
nextStageC              cmp     accelStage, #2 wz
                        
              if_z      jmp     #fullSpeedStageC} '"fullSpeedStageC" returns to circleLoop 
                       ' jmp     #decelStageC  'accelStage equals one decel not used in circle yet

'------------------------------------------------------------------------------
fullSpeedStageC         mov     activeChange, zero
                        mov     activeChangeS, zero
                        'mov     stepCountdown, fullStepsF '** add decel section later
                        'mov     lastAccelDelay, activeDelay 
                       ' mov     lastAccelDelayS, activeDelayS
                        mov     activeDelay, minDelayCog  ' slow will be changed elsewhere
                        
                        wrlong  activeDelay, debugActiveDelayPtr
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
nextSlowHalf
nextSlowHalf_Ret        ret
'------------------------------------------------------------------------------
nextFastStep
nextFastStep_Ret        ret
'------------------------------------------------------------------------------
'------------------------------------------------------------------------------
getNextSlow             abs     previousSlow, slowCog
                        mov     slowCog, nextSlow ' increment "slowCog" 
                        wrlong  con888, debugLocationClueFPtr
                        abs     tmp1, slowCog    ' if we're at an extreme, reverse direction
                        cmp     tmp1, radiusCog wz  ' reverses should only occur on the slow axis
              if_z      call    #reverseDirection

              
                        abs     tmp2, fastCog
                        cmp     tmp1, tmp2 wz
              if_z      jmp     #swapSpeeds
                        cmp     tmp2, previousSlow wz
              if_z      jmp     #swapSpeeds


                        
continueNextSlow        adds    nextSlow, slowDirectionCog 
                        mov     mathA, nextSlow
                        mov     mathB, nextSlow
                        call    #multiply1
                        mov     nextSlowSquared, mathResult
                        
                        mov     mathA, rSquared
                        sub     mathA, nextSlowSquared
     
                        call    #squareRoot

                        mov     fastAtNextSlow, mathResult

                        'fastAtNextSlow is now positive
                        
  'fastAtNextSlow := ^^(rSquared - nextSlowSquared)
'  nextSlow := -radius #> xIndex[presentSlow] + presentDirectionX[presentSlow] <# radius
'  nextSlowSquared := nextSlow * nextSlow
'  fastAtNextSlow := ^^(rSquared - nextSlowSquared)  
                        
                        abs     tmp1, fastCog
                        mov     tmp2, fastAtNextSlow
                        subs    tmp1, tmp2
                        abs     fastStepsPerSlow, tmp1  'fastStepsPerSlow
                        mov     tmp1, fastStepsPerSlow
                        mov     activeChangeS, #0
                        mov     activeDelayS, #0
:loop                   add     activeChangeS, activeChange ' multiply by fastStepsPerSlow
                        add     activeDelayS, activeDelay 
                        djnz    tmp1, #:loop

'  lastHalfStep[presentSlow] := cnt - (axisDelay[presentSlow] / 2)
                        mov     lastHalfStepTimeS, activeDelayS
                        shr     lastHalfStepTimeS, #1
                        'neg     lastHalfStepTimeS, lastHalfStepTimeS
                        add     lastHalfStepTimeS, cnt
                        
                        call    #checkFansDirection
afterFansCheck                                  

        
                        


'  fastStepsPerSlow := ||(fastAtNextSlow - xIndex[presentFast])
'  axisDelay[presentSlow] := axisDelay[presentFast] * fastStepsPerSlow
'  axisDeltaDelay[presentSlow] := axisDeltaDelay[presentFast] * fastStepsPerSlow
'  lastHalfStep[presentSlow] := cnt - (axisDelay[presentSlow] / 2)
  
getNextSlow_Ret         ret
'------------------------------------------------------------------------------
reverseDirection        neg     slowDirectionCog, slowDirectionCog
reverseDirection_Ret    ret
'------------------------------------------------------------------------------
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
'' values swapped: fastDirMaskCog & slowDirMaskCog; fastMask, slowMask;
'' fastDirectionCog & slowDirectionCog; fastCog & slowCog, fastTotal & slowTotal
'' debugFastTotalPtr & debugSlowTotalPtr
swapSpeeds              add     octantCog, #1
                        and     octantCog, #7
                        djnz    octantCountdown, #finalizeCircle
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
                        mov     tmp2, debugFastTotalPtr
                        mov     debugFastTotalPtr, debugSlowTotalPtr  
                        mov     debugSlowTotalPtr, tmp2
                  
                        mov     nextSlow, slowCog
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
                        mov     tmp2, #16
:loop                   shl     mathA, #1 wc
                        rcl     tmp1, #1
                        shl     mathResult, #1 wc
                        rcl     tmp1, #1
                        shl     mathA, #2
                        or      mathA, #1
                        cmpsub  tmp1, mathA wc
                        shr     mathA, #2
                        rcl     mathA, #1
                        djnz    tmp2, #:loop
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
'con1M                   long 1_000_000
'con2M                   long 2_000_000
'con3M                   long 3_000_000
'con4M                   long 4_000_000
                                           

stepMask                long 1 << Header#STEP_X_PIN | 1 << Header#STEP_Y_PIN | 1 << Header#STEP_Z_PIN
dirMask                 long 1 << Header#DIR_X_PIN | 1 << Header#DIR_Y_PIN | 1 << Header#DIR_Z_PIN
    
'testBufferPtr           long 0-0
mailboxAddr             res 1 '1
maxDelayAddr            res 1   
minDelayAddr            res 1   
delayChangeAddr         res 1   
accelIntervalAddr       res 1   
accelIntervalsAddr      res 1  '6

address165Ptr           res 1
debugActiveDelaySPtr    res 1
debugActiveDelayPtr     res 1
debugDelayTotalSPtr     res 1 '10
debugDelayTotalPtr      res 1   
debugFullStepsFPtr      res 1
debugAddress5Ptr        res 1
debugMaxDelayPtr        res 1
debugAddress7Ptr        res 1
debugLastHalfTimePtr    res 1
debugAddress9Ptr        res 1
debugFastTotalPtr       res 1
debugSlowTotalPtr       res 1
debugScratchTime111Ptr  res 1 '20
debugScratchTimePtr     res 1
debugLocationCluePtr    res 1
debugLocationClueFPtr   res 1
debugAccelStepsPtr      res 1
{debugDecelStepsPtr      res 1
debugFullSpeedStepsPtr  res 1
debuglastStepTimePtr    res 1
debugAccelStagePtr      res 1
debugStepCountdownPtr   res 1 
debug1MPtr              res 1 '30
debug2MPtr              res 1 
debug3MPtr              res 1 
debug4MPtr              res 1
debug1MAPtr             res 1 
debug2MAPtr             res 1 
debug3MAPtr             res 1

debug4MAPtr             res 1  
debug1MFPtr             res 1 
debug2MFPtr             res 1 
debug3MFPtr             res 1 '40
debug4MFPtr             res 1  
debug1MDPtr             res 1 
debug2MDPtr             res 1 
debug3MDPtr             res 1 
debug4MDPtr             res 1  
debugActiveChangePtr    res 1 
debugAddressRPtr        res 1 
debugActiveChangeSPtr   res 1} '48

stepDelay               res 1
'wait                    res 1
'adcRequest              res 1
'activeAdcPtr            res 1
resultPtr               res 1
'inputData               res 1
'outputData              res 1

'temp                    res 1
'readErrors              res 1
                    
loopCount               res 1
'debugPtrCog             res 1
mathA                   res 1
mathB                   res 1
mathResult              res 1
tmp1                    res 1 
tmp2                    res 1
fastMask                res 1
slowMask                res 1
   


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
lastAccelTime           res 1
'lastAccelTimeS          res 1
lastStepTime            res 1
lastStepTimeS           res 1
lastHalfStepTime        res 1
lastHalfStepTimeS       res 1
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
radiusCog               res 1
octantCog               res 1
octantCountdown         res 1
radiusOverRoot2Cog      res 1
fastCog                 res 1
slowCog                 res 1
fastDirectionCog        res 1
slowDirectionCog        res 1
fastDirMaskCog          res 1
slowDirMaskCog          res 1
nextSlow                res 1
rSquared                res 1
fastStepsPerSlow        res 1
previousSlow            res 1
'radiusCog               res 1
nextSlowSquared         res 1
fastAtNextSlow          res 1
now                     res 1
                        fit

DAT