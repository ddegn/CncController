DAT objectName          byte "MotorControl", 0
CON
{{

 
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
accelMaxIntervals       long 0-0

'debugAddress            long 0-0
dirPinX                 long Header#DIR_X_PIN
dirPinY                 long Header#DIR_Y_PIN
dirPinZ                 long Header#DIR_Z_PIN
stepMaskX               long 1 << Header#STEP_X_PIN
stepMaskY               long 1 << Header#STEP_Y_PIN
stepMaskZ               long 1 << Header#STEP_Z_PIN
  
testBuffer              long 0[TEST_BUFFER_SIZE]

OBJ

  Header : "HeaderCnc"
  Pst : "Parallax Serial TerminalDat"
  Format : "StrFmt"
  Cnc : "CncCommonMethods"
   
PUB Start(address165_) | debugPtr

  address165 := address165_
 
  testBufferPtr := @testBuffer
 
  debugPtr := @debugActiveDelayS

  'accelIntervals := ComputeAccelIntervals(maxDelay, minDelay, delayChange, accelInterval)
  
  repeat result from 0 to 40 'Header#MAX_DEBUG_SPI_INDEX
    debugActiveDelayS[result] := debugPtr
    debugPtr += 4
    
  cognew(@entry, @command)

  waitcnt(clkfreq / 100 + cnt)
  
  SetMotorParameters(maxDelay, minDelay, delayChange, accelInterval)

PUB SetCommand(cmd)

  command := cmd                '' Write command 
  repeat while command          '' Wait for command to be cleared, signifying receipt

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
  accelMaxIntervals := ComputeMaxAccelIntervals(localMax, localMin, localChange)
  accelIntervals := ComputeAccelIntervals(localMax, localMin, localChange, localAccelInterval)
  SetCommand(Header#NEW_PARAMETERS_MOTOR)

PRI ComputeMaxAccelIntervals(localMax, localMin, localChange)

  result := localMax - localMin
  result += localChange - 1     ' make sure divide doesn't truncate value at all
  result /= localChange
  
  Pst.Str(string(11, 13, "accelMaxIntervals = "))
  Pst.Dec(result)
  
PRI ComputeAccelIntervals(localMax, localMin, localChange, localAccelInterval) | nextAccel, {
} nextStep

  Pst.Str(string(11, 13, "ComputeAccelIntervals("))
  Pst.Dec(localMax)
  Pst.Str(string(", "))
  Pst.Dec(localMin)
  Pst.Str(string(", "))
  Pst.Dec(localChange)
  Pst.Str(string(", "))
  Pst.Dec(localAccelInterval)
  Pst.Str(string("), accelIntervals = "))
  Pst.Dec(accelIntervals)
  
  longfill(@nextAccel, 0, 2)

  repeat while localMax > localMin
    nextAccel += localAccelInterval
    Pst.Str(string(11, 13, "localMax = "))
    Pst.Dec(localMax)
    Pst.Str(string(", Min = "))
    Pst.Dec(localMin)
    
    repeat while nextStep < nextAccel
      result++
      nextStep += localMax
      Pst.Str(string(", intervals = "))
      Pst.Dec(result)
      Pst.Str(string(", nextStep = "))
      Pst.Dec(nextStep)
    localMax -= localChange  
  
  Pst.Str(string(11, 13, "accelIntervals = "))
  Pst.Dec(result)
  
PUB MoveSingle(localAxis, localDistance) | spinScratch

  Pst.Str(string(11, 13, "MoveSingle("))
  Pst.Dec(localAxis)
  Pst.Str(string(", "))
  Pst.Dec(localDistance)
  Pst.Str(string("), accelIntervals = "))
  Pst.Dec(accelIntervals)
  
  longfill(@debugActiveDelayS, 0, 40)
  
  localAxis := stepMaskX[localAxis]
  if localDistance < 0
    dira[dirPinX[localAxis]] := 0
    ||localDistance
  else
    dira[dirPinX[localAxis]] := 1
      
  mailbox := @result
  Pst.Str(string(11, 13, "localAxis (mask) "))
  Cnc.ReadableBin(localAxis, 32)
  
  Cnc.PressToContinue
   
  'SetCommand(Header#SINGLE_MOTOR)
  command := Header#SINGLE_MOTOR
  repeat 'while command          '' Wait for command to be cleared, signifying receipt
    Pst.Str(string(11, 13, "location = ")) ' watch progress
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
    spinScratch := debugNextHalfTime - cnt
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
    Pst.Dec(debugNextHalfTime)   
    Pst.Str(string(", nextStepTime = ")) 
    Pst.Dec(debugNextStepTime)   
    Pst.Str(string(", next - half = ")) 
    Pst.Dec(debugNextStepTime - debugNextHalfTime)   
    
    
                        
  while command and debugLocationClue <> 999        
  Pst.Str(string(11, 13, "full speed steps = "))
  Pst.Dec(result)
  
   
PUB MoveLine(longAxis, shortAxis, longDistance, shortDistance) | {
} maxDelayS, minDelayS, delayChangeS, spinScratch, originalAxes[2]

  maxDelayS := Cnc.TtaMethod(||longDistance, maxDelay, ||shortDistance)
  minDelayS := Cnc.TtaMethod(||longDistance, minDelay, ||shortDistance)
  delayChangeS := Cnc.TtaMethod(||longDistance, delayChange, ||shortDistance)
  longmove(@originalAxes, @longAxis, 2)
  longfill(@debugActiveDelayS, 0, 40)
  
  Pst.Str(string(11, 13, "MoveLine("))
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
  Pst.Dec(delayChangeS)

  repeat result from 0 to 1
    longAxis[result] := stepMaskX[originalAxes[result]]
    if longDistance[result] < 0
      dira[dirPinX[originalAxes[result]]] := 0
      ||longDistance[result]
    else
      dira[dirPinX[originalAxes[result]]] := 1
    Pst.Str(string(11, 13))
    Pst.Str(Cnc.FindString(Cnc.GetAxisText, originalAxes[result]))
    Pst.Str(string(" (mask)["))
    Pst.Dec(originalAxes[result])
    Pst.Str(string("] = "))
    Cnc.ReadableBin(longAxis[result], 32)  

  Cnc.PressToContinue
  
  mailbox := @result

  'SetCommand(Header#DUAL_MOTOR)
  command := Header#DUAL_MOTOR
  repeat 'while command          '' Wait for command to be cleared, signifying receipt
    Pst.Str(string(11, 13, "location = ")) ' watch progress
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
    spinScratch := debugNextHalfTime - cnt
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
    Pst.Dec(debugNextHalfTime)   
    Pst.Str(string(", nextStepTime = ")) 
    Pst.Dec(debugNextStepTime)   
    Pst.Str(string(", next - half = ")) 
    Pst.Dec(debugNextStepTime - debugNextHalfTime)
                        
  while command and debugLocationClue <> 999
    
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

DAT