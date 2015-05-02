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
 
  debugPtr := @debugAddress0

  accelIntervals := ComputeAccelIntervals(maxDelay, minDelay, delayChange)
  
  repeat result from 0 to 21 'Header#MAX_DEBUG_SPI_INDEX
    debugAddress0[result] := debugPtr
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
  accelIntervals := ComputeAccelIntervals(localMax, localMin, localChange)
  SetCommand(Header#NEW_PARAMETERS_MOTOR)

PRI ComputeAccelIntervals(localMax, localMin, localChange)

  result := localMax - localMin
  result += localChange - 1     ' make sure divide doesn't truncate value at all
  result /= localChange
  
PUB MoveSingle(localAxis, localDistance) | spinScratch

  Pst.Str(string(11, 13, "MoveSingle("))
  Pst.Dec(localAxis)
  Pst.Str(string(", "))
  Pst.Dec(localDistance)
  Pst.Str(string("), accelIntervals = "))
  Pst.Dec(accelIntervals)
  
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
    Pst.Dec(debugAddressF)
    Pst.Str(string(", ")) ' watch progress
    Pst.Dec(debugAddressE)
    Pst.Str(string(", fastTotal = ")) ' watch progress
    Pst.Dec(debugAddressA)
    Pst.Str(string(", activeDelay = ")) ' watch progress
    Pst.Dec(debugAddress1)
    Pst.Str(string(" or ")) ' watch progress
    Pst.Dec(debugAddress1 / 80_000)
    Pst.Str(string(" ms, delayTotal = ")) ' watch progress
    Pst.Dec(debugAddress3)
    Pst.Str(string(" or ")) ' watch progress
    Pst.Dec(debugAddress3 / 80_000)
    Pst.Str(string(" ms  ")) ' watch progress
    Pst.Dec(debugAccelSteps)
    
    Pst.Str(string(11, 13, "maxDelayCog = ")) ' watch progress
    Pst.Dec(debugAddress6)
    Pst.Str(string(", PASM scratchTime = ")) ' watch progress
    Pst.Dec(debugAddressC)
    Pst.Str(string(" or ")) ' watch progress
    Pst.Dec(debugAddressC / 80_000)
    Pst.Str(string(", scratchTime (accel) = ")) ' watch progress
    Pst.Dec(debugAddressD)
    Pst.Str(string(11, 13, "Spin scratchTime = ")) ' watch progress
    spinScratch := debugNextHalfTime - cnt
    Pst.Dec(spinScratch)
    Pst.Str(string(" or ")) ' watch progress
    Pst.Dec(spinScratch / 80_000)
    Pst.Str(string(" ms")) ' watch progress
       
    Pst.Str(string(11, 13, "accelStepsF = ")) ' watch progress
    Pst.Dec(debugAccelSteps)   
    Pst.Str(string(", fullStepsF = ")) ' watch progress
    Pst.Dec(debugFullSpeedSteps)   
    Pst.Str(string(", decelStepsF = ")) ' watch progress
    Pst.Dec(debugDecelSteps)   
    Pst.Str(string(", a+f+d = ")) ' watch progress
    Pst.Dec(debugAccelSteps + debugFullSpeedSteps + debugDecelSteps)   
    Pst.Str(string(", localDistance = ")) ' watch progress
    Pst.Dec(localDistance)   

    Pst.Str(string(11, 13, "debugHalfTime = ")) ' watch progress
    Pst.Dec(debugNextHalfTime)   
    Pst.Str(string(", nextStepTime = ")) ' watch progress
    Pst.Dec(debugNextStepTime)   
    Pst.Str(string(", next - half = ")) ' watch progress
    Pst.Dec(debugNextStepTime - debugNextHalfTime)   
    
    
                        
  while command and debugAddressE <> 999            
  Pst.Str(string(11, 13, "full speed steps = "))
  Pst.Dec(result)
  
   
PUB MoveLine(longAxis, shortAxis, longDistance, shortDistance) | {
} startDelay[2], accelChange[2] 

  repeat result from 0 to 1
    longAxis[result] := stepMaskX[longAxis[result]]
    if longDistance[result] < 0
      dira[dirPinX[longAxis[result]]] := 0
      ||longDistance[result]
    else
      dira[dirPinX[longAxis[result]]] := 1
      
  mailbox := @result

  SetCommand(Header#DUAL_MOTOR)
    
DAT                     org
'------------------------------------------------------------------------------
entry                   or      dira, stepMask
                        andn    outa, stepMask

                        mov     mailboxAddr, par

                        'mov     byteCount, #4    
                        add     mailboxAddr, #4   ' ** convert to loop
                        mov     maxDelayAddr, mailboxAddr
                        add     maxDelayAddr, #4
                        mov     minDelayAddr, maxDelayAddr
                        add     minDelayAddr, #4
                        mov     delayChangeAddr, minDelayAddr
                        add     delayChangeAddr, #4
                        mov     accelIntervalAddr, delayChangeAddr
                        add     accelIntervalAddr, #4
                        mov     accelIntervalsAddr, accelIntervalAddr
                        add     accelIntervalsAddr, #4                                      
                        wrlong  con111, debugAddressF

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
                        wrlong  con222, debugAddressF
                        'wrlong  resultPtr, debugAddress0
                        add     bufferAddress, #4
                        rdlong  fastMask, bufferAddress             
                        'wrlong  bufferAddress, debugAddress1
                        'wrlong  shiftOutputChange, debugAddress2
                        add     bufferAddress, #4
                        mov     fastTotal, zero
                        mov     delayTotal, zero
                        'rdlong  slowMask, bufferAddress              
                        'wrlong  bufferAddress, debugAddress3
                        'wrlong  outputData, debugAddress4
                        'add     bufferAddress, #4
                        rdlong  fastDistance, bufferAddress             
                        'add     bufferAddress, #4
                        'rdlong  slowDistance, bufferAddress             
                        'mov     activeHalfDelay, halfMaxDelayCog
                        mov     activeDelay, maxDelayCog
                        'mov     activeHalfChange, halfDelayChangeCog
                        wrlong  maxDelayCog, debugAddress6
                        mov     activeChange, delayChangeCog
                        wrlong  activeDelay, debugAddress1
                        
                        'mov     activeHalfMinDelayCog, halfMinDelayCog
                        'mov     activeMinDelayCog, minDelayCog
                                      'activeChange
                                
                        'andn    outa, fastMask
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
                        wrlong  con777, debugAddressE 
                        jmp     #fullSpeedSizeCheck
' exit acceleration loop                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
                        
accelSingleBody         call    #stepFastHigh
'                                                
firstPartOfStepA        mov     scratchTime, nextHalfStepTime
                        sub     scratchTime, cnt wc
                        'cmp     nextHalfStepTime, cnt wc  ' ** use waitcnt instead?
                        wrlong  scratchTime, debugAddressC
                        'mov     nextHalfStepTimeS, cnt
                        'wrlong  nextHalfStepTimeS, debugAddressD
                        wrlong  con111, debugAddressE
              if_nc     jmp     #firstPartOfStepA
              
                        andn    outa, fastMask
                        
secondPartOfStepA       mov     scratchTime, nextStepTime
                        sub     scratchTime, cnt wc
                        'cmp     nextStepTime, cnt wc
                        wrlong  scratchTime, debugAddressC
                        wrlong  con222, debugAddressE
              if_nc     jmp     #secondPartOfStepA
                        wrlong  con771, debugAddressE
                        mov     scratchTime, nextAccelTime
                        sub     scratchTime, cnt wc
                        'cmp     nextAccelTime, cnt wc ' check if acceleration time
                        wrlong  scratchTime, debugAddressD
              if_nc     jmp     #accelLoopSingle

decreaseDelay           sub     activeDelay, activeChange
                        mov     nextHalfStepTime, nextStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     nextHalfStepTime, scratchTime
                        wrlong  activeDelay, debugAddress1
                        add     nextAccelTime, accelIntervalCog
                        jmp     #accelLoopSingle
                        'cmp     activeDelay, minDelayCog wc wz
          'if_nc_and_nz  jmp     #decelSingleEnter

' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
' begin full speed
fullSpeedSizeCheck      mov     lastAccelDelay, activeDelay
                        'mov     lastAccelHalfDelay, activeHalfDelay
                        wrlong  con999, debugAddressE
                        wrlong  fullStepsF, debugAddress4
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
                        
fullSpeedLoopEnter      wrlong  con554, debugAddressF
                        wrlong  activeDelay, debugAddress1
fullSpeedLoop           djnz    fullStepsF, #fullSpeedSingleBody ' awkward code
' We previously added one to fullStepsF so this fist djnz doesn't mess out the step count.
                        wrlong  con556, debugAddressF
                        jmp     #decelSingleEnter
' exit full speed loop
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


fullSpeedSingleBody     call    #stepFastHigh
                        wrlong  con557, debugAddressF
firstPartOfStepFull     mov     scratchTime, nextHalfStepTime
                        sub     scratchTime, cnt wc
                        'cmp     nextHalfStepTime, cnt wc  ' ** use waitcnt instead?
                        wrlong  con338, debugAddressE
              if_nc     jmp     #firstPartOfStepFull
              
                        andn    outa, fastMask
                        wrlong  con558, debugAddressF
secondPartOfStepFull    mov     scratchTime, nextStepTime
                        sub     scratchTime, cnt wc
                        'cmp     nextStepTime, cnt wc
                        wrlong  con448, debugAddressE
              if_nc     jmp     #secondPartOfStepFull
                        wrlong  con888, debugAddressE
                        jmp     #fullSpeedLoop
                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
' decelerate

decelSingleEnter        wrlong  con772, debugAddressF
                        mov     activeDelay, lastAccelDelay
                        'debugAddress4
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
                        wrlong  con555, debugAddressE
              if_nc     jmp     #firstPartOfStepD
              
                        andn    outa, fastMask
                        
secondPartOfStepD       mov     scratchTime, nextStepTime
                        sub     scratchTime, cnt wc
                        'cmp     nextStepTime, cnt wc
                        wrlong  con666, debugAddressE
              if_nc     jmp     #secondPartOfStepD

                        wrlong  con999, debugAddressE
              
                        mov     scratchTime, nextAccelTime
                        sub     scratchTime, cnt wc
                        'cmp     nextAccelTime, cnt wc ' check if acceleration time
              if_nc     jmp     #decelLoopSingle'cceleration

increaseDelay           add     activeDelay, activeChange
                        mov     nextHalfStepTime, nextStepTime
                        mov     scratchTime, activeDelay
                        shr     scratchTime, #1
                        sub     nextHalfStepTime, scratchTime
                        wrlong  activeDelay, debugAddress1
                        add     nextAccelTime, accelIntervalCog
                        jmp     #decelLoopSingle
                        
' - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

finishSingleMove        wrlong  con999, debugAddressF
                        jmp     #mainPasmLoop

'------------------------------------------------------------------------------
setFullSpeedSingleSteps mov     accelStepsF, accelIntervalsCog
                        mov     decelStepsF, accelIntervalsCog
                        'mov     fullStepsF, fastDistance
                        mov     shortFlag, zero
                        wrlong  con333, debugAddressF
                        jmp     #continueSingleSetup
'------------------------------------------------------------------------------
setLowSpeedSingleSteps  mov     accelStepsF, fastDistance
                        shr     accelStepsF, #1
                        mov     decelStepsF, accelStepsF
                        mov     shortFlag, #1
                        wrlong  con444, debugAddressF
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
                        wrlong  delayTotal, debugAddress3
                        wrlong  fullStepsF, debugFullSpeedSteps
                        wrlong  accelStepsF, debugAccelSteps
                        wrlong  decelStepsF, debugDecelSteps
                                
                        add     nextStepTime, activeDelay
                        wrlong  nextStepTime, debugNextStepTime
                        
                        add     fastTotal, #1
                        wrlong  fastTotal, debugAddressA 'totalFromPasmFastPtr
stepFastHigh_ret        ret
'------------------------------------------------------------------------------
stepSlowHigh            or      outa, slowMask
                        add     nextHalfStepTimeS, activeDelayS
                        add     delayTotalS, activeDelayS
                        wrlong  delayTotalS, debugAddress4
                        add     nextStepTimeS, activeDelayS
                        add     slowTotal, #1
                        wrlong  slowTotal, debugAddressB 'totalFromPasmFastPtr
stepSlowHigh_ret        ret
'------------------------------------------------------------------------------
'------------------------------------------------------------------------------
driveTwo                rdlong  resultPtr, mailboxAddr                        
                        mov     bufferAddress, resultPtr
                        'wrlong  con222, debugAddressF
                        'wrlong  resultPtr, debugAddress0
                        add     bufferAddress, #4
                        rdlong  fastMask, bufferAddress             
                        'wrlong  bufferAddress, debugAddress1
                        'wrlong  shiftOutputChange, debugAddress2
                        add     bufferAddress, #4
                        'mov     stepDelay, bitDelay
                        rdlong  slowMask, bufferAddress              
                        'wrlong  bufferAddress, debugAddress3
                        'wrlong  outputData, debugAddress4
                        add     bufferAddress, #4
                        rdlong  fastDistance, bufferAddress             
                        add     bufferAddress, #4
                        rdlong  slowDistance, bufferAddress             
                        
                        andn    outa, fastMask
                        andn    outa, slowMask
                     
                        jmp     #mainPasmLoop

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
                                           

stepMask                long 1 << Header#STEP_X_PIN | 1 << Header#STEP_Y_PIN | 1 << Header#STEP_Z_PIN
    
testBufferPtr           long 0-0
address165              long 0-0
debugAddress0           long 0-0
debugAddress1           long 0-0
debugAddress2           long 0-0
debugAddress3           long 0-0
debugAddress4           long 0-0
debugAddress5           long 0-0
debugAddress6           long 0-0
debugAddress7           long 0-0
debugNextHalfTime       long 0-0
debugAddress9           long 0-0
debugAddressA           long 0-0
debugAddressB           long 0-0
debugAddressC           long 0-0
debugAddressD           long 0-0
debugAddressE           long 0-0
debugAddressF           long 0-0
debugAccelSteps         long 0-0
debugDecelSteps         long 0-0
debugFullSpeedSteps     long 0-0
debugNextStepTime       long 0-0
debugAddressK           long 0-0
debugAddressL           long 0-0 '21

stepDelay               res 1
wait                    res 1
adcRequest              res 1
activeAdcPtr            res 1
resultPtr               res 1
inputData               res 1
outputData              res 1

temp                    res 1
readErrors              res 1
                    
loopCount               res 1
debugPtrCog             res 1
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
maxDelayCog             res 1
minDelayCog             res 1
delayChangeCog          res 1
accelIntervalCog        res 1
accelIntervalsCog       res 1
doubleAccel             res 1
accelStepsF             res 1
accelStepsS             res 1
decelStepsF             res 1
decelStepsS             res 1
fullStepsF              res 1
fullStepsS              res 1
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
nextAccelTimeS          res 1
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
                        fit

DAT