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

'debugAddress            long 0-0
dirMaskX                long 1 << Header#DIR_X_PIN
dirMaskY                long 1 << Header#DIR_Y_PIN
dirMaskZ                long 1 << Header#DIR_Z_PIN
stepMaskX               long 1 << Header#STEP_X_PIN
stepMaskY               long 1 << Header#STEP_Y_PIN
stepMaskZ               long 1 << Header#STEP_Z_PIN
  
testBuffer                  long 0[TEST_BUFFER_SIZE]

OBJ

  Header : "HeaderCnc"
  Pst : "Parallax Serial TerminalDat"
  Format : "StrFmt"
   
PUB Start(address165_) | debugPtr

  address165 := address165_
  mailboxAddr := @mailbox
  testBufferPtr = @testBuffer
  'debugAddress :=
  debugPtr := @debugAddress0
  repeat result from 0 to Header#MAX_DEBUG_SPI_INDEX
    debugAddress0[result] := debugPtr
    debugPtr += 4
    
  cognew(@entry, @command) + 1

  'repeat while command
   
  'Init
    
PUB Stop
'' Stop SPI Engine - frees a cog

  if cog
     cogstop(cog~ - 1)
  command~

PUB SpiL

  repeat while lockset(spiLock)

PUB SpiC

  lockclr(spiLock)
  
PUB SetCommand(cmd)

  SpiL
  command := cmd                '' Write command 
  repeat while command          '' Wait for command to be cleared, signifying receipt
    {if cmd == Header#ADC_SPI
  
      Pst.Str(string(11, 13, "adcRequest = "))
      Pst.Dec(long[debugAddress0])
      Pst.Str(string(" = "))
      ReadableBin(long[debugAddress0], 32)
      Pst.Str(string(11, 13, "activeAdcPtr = "))
      Pst.Dec(long[debugAddress1])
      Pst.Str(string(", adcPtr = "))
      Pst.Dec(adcPtr)
      Pst.Str(string(11, 13, "dataValue = "))
      Pst.Dec(long[debugAddress2])
      Pst.Str(string(" = "))
      ReadableBin(long[debugAddress2], 32)
      Pst.Str(string(11, 13, "bufferAddress = "))
      Pst.Dec(long[debugAddress3])
      Pst.Str(string(11, 13, "dataOut = "))
      Pst.Dec(long[debugAddress4])
      Pst.Str(string(" = "))
      ReadableBin(long[debugAddress4], 32)
      Pst.Str(string(11, 13, "byteCount = "))
      Pst.Dec(long[debugAddress5])
      Pst.Str(string(11, 13, "location clue = "))
      Pst.Dec(long[debugAddress6])
      Pst.Str(string(11, 13, "dataOutToShred = "))
      Pst.Dec(long[debugAddress7])
      Pst.Str(string(" = "))
      ReadableBin(long[debugAddress7], 32)
      Pst.Str(string(11, 13, "adcInUseCog = "))
      Pst.Dec(long[debugAddress8])   }
  SpiC
      
PRI Init

 

PUB GetPasmArea

  result := @entry 


PUB MoveLine(longAxis, shortAxis, longDistance, shortDistance) 

  repeat result from 0 to 1
    longAxis[result] := stepMaskX[longAxis[result]]
    if longDistance[result] < 0
      dirMask[longAxis[result]] := 0
      ||longDistance[result]
    else
      dirMask[longAxis[result]] := 1
      
  mailbox := @result

  SetCommand(Header#DRV8711_WRITE_SPI)
  
PUB WriteDrv8711(axis, register, value) 

  axis := 1 << (axis * Header#CHANNELS_PER_CS)
  mailbox := @result
  SetCommand(Header#DRV8711_WRITE_SPI) ' PASM code should not retrun to normal loop until CS low again
  
DAT                     org
'------------------------------------------------------------------------------
entry
commandCog              or      dira, latch165Mask
dataOutToShred          or      outa, latch165Mask  ' This long gets reused as a temp variable
shiftRegisterInput      or      dira, latch595Mask
shiftOutputChange       or      dira, clockMask
dataValue               or      dira, mosiMask
dataOut                 or      dira, shiftMosiMask
byteCount               or      dira, shiftClockMask                        
                        
'bitCount                or      dira, p4
                                     
bitsFromPasmCog         mov     bitsFromPasmCog, csOledChanMask
bitsFromSpinCog         or      bitsFromPasmCog, csAdcChanMask
                        'or      dira, p4Cs
                        
                        wrlong  con111, debugAddressF                        
adcInUseCog             jmp     #setAdc
' Pass through only on start up.                        
'------------------------------------------------------------------------------
   
'------------------------------------------------------------------------------
{{
      C[i] = C[i-1] - ((2*C[i])/(4*i+1))
          
}}
'------------------------------------------------------------------------------
driveOne                rdlong  resultPtr, mailboxAddr                        
                        mov     bufferAddress, resultPtr
                        'wrlong  con222, debugAddressF
                        'wrlong  resultPtr, debugAddress0
                        add     bufferAddress, #4
                        rdlong  fastMask, bufferAddress             
                        'wrlong  bufferAddress, debugAddress1
                        'wrlong  shiftOutputChange, debugAddress2
                        add     bufferAddress, #4
                        'mov     cogDelay, bitDelay
                        rdlong  slowMask, bufferAddress              
                        'wrlong  bufferAddress, debugAddress3
                        'wrlong  outputData, debugAddress4
                        add     bufferAddress, #4
                        rdlong  fastDistance, bufferAddress             
                        add     bufferAddress, #4
                        rdlong  slowDistance, bufferAddress             
                        
                        andn    outa, fastMask
                        andn    outa, slowMask
                       
                        
                        
                        wrlong  outputData, debugAddress5
                        
                        call    #spiBits
                     
                        and     inputData, twelveBits
                        wrlong  inputData, resultPtr                        
                        'andn    outa, p4Cs
                        call    #low595
                        wrlong  con999, debugAddressF
                        jmp     #loopSpi

                       
'------------------------------------------------------------------------------
writeDrv8711Pasm        rdlong  resultPtr, mailboxAddr                        
                        mov     bufferAddress, resultPtr
                        add     bufferAddress, #4
                        rdlong  shiftOutputChange, bufferAddress ' CS mask               
                        add     bufferAddress, #4
                        rdlong  outputData, bufferAddress  ' register to write           
                        add     bufferAddress, #4
                        mov     cogDelay, bitDelay
                        rdlong  dataValue, bufferAddress  ' data to write
                        shl     outputData, #12          ' shift regiter to make remove for data
                        or      outputData, dataValue    ' combine regiter and data     
                        call    #high595
                        'or      outa, p4Cs
                        mov     bitCount, #16 
                        
                        call    #spiBits
                        
                        'andn    outa, p4Cs
                        call    #low595
                        jmp     #loopSpi
                              
'------------------------------------------------------------------------------
'' The variables "outputData", "bitCount" and "bitDelay" should be set
'' prior to calling spiBits

spiBits                 ror     outputData, bitCount
                        wrlong  outputData, debugAddress6
                        wrlong  con777, debugAddressF
                        mov     wait, cnt
                        add     wait, cogDelay
:loop
                        rcl     outputData, #1  wc
                        waitcnt wait, cogDelay
                        andn    outa, clockMask
                        muxc    outa, mosiMask
                        waitcnt wait, cogDelay
                        or      outa, clockMask
                        test    misoMask, ina  wc
                        rcl     inputData, #1
                        djnz    bitCount, #:loop
spiBits_ret             ret
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
                                               
divide_ret              ret
'------------------------------------------------------------------------------
zero                    long 0                  '' Constant
sixteenBits             long %1111_1111_1111_1111
bufferSize              long OLED_BUFFER_SIZE
                                              
'csMask                  long %10000                  '' Used for Chip Select mask
mailboxAddr             long 0                    
bufferAddress           long 0                  '' Used for buffer address

DAT ' PASM Variables

negativeOne             long -1

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
con444                  long 444
con555                  long 555
con666                  long 666
con777                  long 777
con888                  long 888
con999                  long 999
                                           

     
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
debugAddress8           long 0-0
debugAddress9           long 0-0
debugAddressA           long 0-0
debugAddressB           long 0-0
debugAddressC           long 0-0
debugAddressD           long 0-0
debugAddressE           long 0-0
debugAddressF           long 0-0

cogDelay                res 1
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
mathA                   res 1
mathB                   res 1
mathResult              res 1
tmp1                    res 1 
tmp2                    res 1
fastMask                res 1
slowMask                res 1
                        fit

DAT
