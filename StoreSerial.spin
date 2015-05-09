DAT programName         byte "StoreSerial", 0
CON
{{      

}}
{
  ******* Private Notes *******
  Change name from "CncCommonMethods150416a" to "StoreBitmap150416a."
  16a Successfully saved propBeanie bitmap.
  16b  splash
}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq
  MS_001   = CLK_FREQ / 1_000
  US_001   = CLK_FREQ / 1_000_000

  QUOTE = 34
  BELL = 7
  
OBJ

  Header : "HeaderCnc"
  Pst : "Parallax Serial TerminalDat"
  Format : "StrFmt"
  Sd[1]: "SdSmall" 
  'Spi : "StepperSpi"  
  Num : "Numbers"
   
VAR


  'long lastRefreshTime, refreshInterval
  long oledStack
  long sdErrorNumber, sdErrorString, sdTryCount
  long filePosition[Header#NUMBER_OF_AXES]
  long globalMultiplier
  long oledLabelPtr, oledDataPtr, oledDataQuantity ' keep together and in order
  long shiftRegisterOutput, shiftRegisterInput
  long adcData[8]
  long debugSpi[16]
  
  byte sdMountFlag[Header#NUMBER_OF_SD_INSTANCES]
  byte endFlag
  byte configData[Header#CONFIG_SIZE]
  byte sdFlag
  byte tstr[32]
  
DAT

designFileIndex         long -1             

machineState            byte Header#INIT_STATE
units                   byte Header#MILLIMETER_UNIT 
delimiter               byte 13, 10, ",", 9, 0
oledState               byte Header#DEMO_OLED

PUB Main | bitmapSize, fileName, bitmapPtr

  Pst.Start(115200)
  
  repeat
    result := Pst.RxCount
    Pst.str(string(11, 13, "Press any key to continue starting program."))
    waitcnt(clkfreq / 2 + cnt)
  until result
  Pst.RxFlush
  
  sdFlag := Header#INITIALIZING_SD
  
  Sd.fatEngineStart(Header#DOPIN, Header#ClkPIN, Header#DIPIN, Header#CSPIN, {
  } Header#WP_SD_PIN, Header#CD_SD_PIN, Header#RTC_PIN_1, Header#RTC_PIN_2, Header#RTC_PIN_3)
  
  
  Pst.str(string(11, 13, "SD Card Driver Started"))

  fileName := @sdFileName          '' Change these two lines to match names of data
  bitmapPtr := @entry
  
  bitmapSize := @afterData - bitmapPtr
        
  OpenOutputFileW(0, fileName)
  Sd.writeData(bitmapPtr, bitmapSize)
  Sd.closeFile  
  result := CompareData(fileName, bitmapPtr, bitmapSize, 1)
  if result
    Pst.str(string(11, 13, "Error, data in file does not match data in RAM."))
    Pst.str(string(11, 13, "There were "))
    Pst.dec(result)
    Pst.str(string("differences found between the two data sets."))
  else
    Pst.str(string(11, 13, "Success, the data in the file matches the data in RAM."))   
  Pst.str(string(11, 13, "End of program."))
  repeat
      
PUB CompareData(fileName, localPtr, bitmapSize, displayFlag) | localByte, rowCount, byteCount

  rowCount := 0
  byteCount := 0
  
  Pst.Str(string(11, 13, "Comparing RAM with File."))

  Pst.Str(string(11, 13, "RAM address = $"))
  Pst.Hex(localPtr, 4)

  Pst.Str(string(11, 13, "File name = "))
  Pst.Str(fileName) 

  Pst.Str(string(11, 13, "Bytes to compare = $"))
  Pst.Hex(bitmapSize, 4)
  Pst.Str(string(11, 13))
   
  OpenFileToRead(0, fileName)
  repeat bitmapSize
  
    ifnot rowCount++ // 8
      if displayFlag

        Pst.Str(string(11, 13, "<$"))
        Pst.Hex(localPtr, 4)
        Pst.Str(string("&$"))
        Pst.Hex(byteCount, 4)
        Pst.Str(string(">"))

    localByte := Sd.readByte
    if displayFlag
      Pst.Str(string("|$"))
      Pst.Hex(byte[localPtr], 2)
    if byte[localPtr] == localByte
      if displayFlag
        Pst.Str(string("==$"))
    else
      if displayFlag
        Pst.Str(string(7, "<>$"))
      result++
    if displayFlag
      Pst.Hex(localByte, 2)  
    localPtr++
    byteCount++
    
  Pst.Str(string(11, 13, "The compare method found "))
  Pst.Dec(result)
  Pst.Str(string(" unmatched bytes."))

  if result
    Pst.Str(string(11, 13, BELL, " Failure!!! ", BELL))
  else
    Pst.Str(string(" Success!!! "))
  
PRI OpenFileToRead(sdInstance, basePtr)
    
  result := MountSd(sdInstance)
  if result == 1
    Pst.str(string(11, 13, "Error in program.  Problem mounting SD card."))
    waitcnt(clkfreq * 2 + cnt)
    result := Header#READ_FILE_ERROR_OTHER
    return
  elseif result
    Pst.str(string(11, 13, "MountSd returned = "))
    Pst.str(result)
    waitcnt(clkfreq * 2 + cnt)

  Pst.str(string(11, 13, "Looking for file ", 34))
  Pst.str(basePtr)
  Pst.char(34)
  sdErrorString := \Sd[sdInstance].openFile(basePtr, "R")
  if strcomp(sdErrorString, basePtr)
    Pst.str(string(11, 13, "File ", 34))
    Pst.str(basePtr)
    Pst.str(string(34, " found."))
    result := Header#READ_FILE_SUCCESS
  else
    Pst.str(string(11, 13, "File ", 34))
    Pst.str(basePtr)
    Pst.str(string(34, " not found."))
    Pst.str(string(11, 13, "sdErrorString = "))
    Pst.dec(sdErrorString)
    Pst.str(string(11, 13, "sdErrorString ", 34))
    Pst.str(sdErrorString)
    Pst.char(34)
    UnmountSd(sdInstance)
   
    result := Header#FILE_NOT_FOUND

PUB OpenOutputFileW(sdInstance, localPtr)

  ifnot sdMountFlag[sdInstance] 
    Pst.str(string(11, 13, "Calling MountSd."))
    MountSd(sdInstance)
    

  Pst.str(string(11, 13, "Attempting to create file ", 34))
  Pst.str(localPtr)
  Pst.char(34)

  repeat
    sdErrorString := \Sd[sdInstance].newFile(localPtr)
    sdErrorNumber :=  Sd[sdInstance].partitionError ' Returns zero if no error occurred.
       
    if(sdErrorNumber) ' Try to handle the "entry_already_exist" error.
      if(sdErrorNumber == Sd#Entry_Already_Exist)

        Sd[sdInstance].deleteEntry(localPtr)
        result := 0
      else
 
        Pst.str(string(11, 13, "Create File Errror = "))
        Pst.dec(sdErrorNumber)
        
        waitcnt(clkfreq * 2 + cnt)
        result := -1
    else
      'sdFlag := NEW_LOG_CREATED_SD
      'repeat until not lockset(debugLockID) 
      Pst.str(string(11, 13, "Creating file ", 34))
      Pst.str(localPtr)
      Pst.str(string(34, "."))     
      'waitcnt(clkfreq / 4 + cnt)  
      Sd[sdInstance].openFile(localPtr, "W")
      result := 1
  until result 

PUB MountSd(sdInstance)
'' Returns 1 is no SD card is found.

  Pst.str(string(11, 13, "MountSd Method"))
  if sdMountFlag[sdInstance]
    result := string("SD Card Already Mounted")
    return  
  sdErrorNumber := Sd[sdInstance].mountPartition(0)
  Pst.str(string(11, 13, "After mount attempt.")) 
  if sdErrorNumber
    sdFlag := Header#NOT_FOUND_SD
    result := 1
    Pst.str(string(11, 13, "Error Mounting SD Card #"))
    Pst.dec(sdErrorNumber)
    
    if sdErrorNumber == -1
      Pst.str(string(11, 13, "The SD card was not properly unmounted after its last use."))
      Pst.str(string(11, 13, "Continuing with program."))
      sdFlag := Header#INITIALIZING_SD
      result := 0

  if result <> 1
    sdMountFlag[sdInstance] := 1

PUB UnmountSd(sdInstance)

  if sdMountFlag[sdInstance] == 0
    Pst.str(string(11, 13, "Partition not currently mounted."))
    return
  
  Pst.str(string(11, 13, "Unmounting Partition"))
  sdErrorNumber := Sd[sdInstance].unmountPartition
  Pst.str(string(11, 13, "sdErrorNumber = "))
  Pst.dec(sdErrorNumber)
  'outa[_GreenLedPin]~~
  'outa[_RedLedPin]~
  sdMountFlag[sdInstance] := 0

PUB PauseForInput

  Pst.Str(string(11, 13, "Press any key to continue."))
  result := Pst.CharIn

PRI SafeTx(localCharacter)
'' Debug lock should be set prior to calling this method.

  if (localCharacter > 32 and localCharacter < 127)
    Pst.Char(localCharacter)    
  else
    Pst.Char(60)
    Pst.Char(36) 
    Pst.Hex(localCharacter, 2)
    Pst.Char(62)

PUB PressToPause

  result := Pst.RxCount
  if result
    Pst.str(string(11, 13, "Paused."))
    Pst.RxFlush
    PressToContinue
    
PUB PressToContinue
  
  Pst.str(string(11, 13, "Press to continue."))
  repeat
    result := Pst.RxCount
  until result
  Pst.RxFlush

PUB PressToContinueOrClose(closeCharacter)
'StoreBitmap150416a

  if closeCharacter <> -1
    Pst.str(string(11, 13, "Press ", QUOTE))
    Pst.Char(closeCharacter)
    Pst.str(string(QUOTE, " to close or any other key to continue."))
    result := Pst.CharIn
  else
    result := -1  
  if result == closeCharacter
    Pst.str(string(11, 13, "Closing all files."))
    'Pst.str(string(11, 13, "End of program.")) 
   
    Sd[0].closeFile
   
    UnmountSd(result)
    UnmountSd(Header#DESIGN_AXIS)
    PressToContinue
  else
    result := 0

DAT

sdFileName              byte "SERIAL_4.DAT", 0

'bitmap
                        org 0
'                   
'To maximize the speed of rx and tx processing, all the mode checks are no longer inline
'The initialization code checks the modes and modifies the rx/tx code for that mode
'e.g. the if condition for rx checking for a start bit will be inverted if mode INVERTRX
'is it, similar for other mode flags
'The code is also patched depending on whether a cts or rts pin are supplied. The normal
' routines support cts/rts processing. If the cts/rts mask is 0, then the code is patched
'to remove the addtional code. This means I/O modes and CTS/RTS handling adds no extra code
'in the rx/tx routines which not required.
'Similar with the co-routine variables. If a rx or tx pin is not configured the co-routine
'variable for the routine that handles that pin is modified so the routine is never called
'We start with port 3 and work down to ports because we will be updating the co-routine pointers
'and the order matters. e.g. we can update txcode3 and then update rxcode3 based on txcode3.
'(TTA): coroutine patch was not working in the way originally described.   (TTA) patched
'unused coroutines jmprets become simple jmps.
' Tim's comments about the order from 3 to 0 no longer apply.

' The following 8 locations are skipped at entry due to if_never.
' The mov instruction and the destination address are here only for syntax.
' the important thing are the source field
' primed to contain the start address of each port routine.
' When jmpret instructions are executed, the source adresses here are used for jumps
' And new source addresses will be written in the process.
entry                   
rxcode  if_never        mov     rxcode, #receive       ' set source fields to initial entry points
txcode  if_never        mov     txcode, #transmit
rxcode1 if_never        mov     rxcode1, #receive1
txcode1 if_never        mov     txcode1, #transmit1
rxcode2 if_never        mov     rxcode2, #receive2
txcode2 if_never        mov     txcode2, #transmit2
rxcode3 if_never        mov     rxcode3, #receive3
txcode3 if_never        mov     txcode3, #transmit3

                        mov     txdata, #33 
                        mov     t1, par
waitToStart             rdword  rxsize_cog, t1 wz ' read startFlag
              if_z      jmp     #waitToStart
                        add     t1, #2                        
copyToCog               rdword  rxsize_cog, t1
                        add     copyToCog, destinationIncrement
                        add     t1, #2
                        djnz    txdata, #copyToCog

' txbuff_ptr_cog points to the location of the buffer.
                        
                        mov     txdata, #15
incrementPointer        mov     rx_head_ptr1_cog, rx_head_ptr_cog  
addFour                 add     rx_head_ptr1_cog, #2
                        add     incrementPointer, destAndSourceIncrement
                        add     addFour, destinationIncrement
                        djnz    txdata, #incrementPointer

                        mov     txdata, #24
                        mov     t1, txbuff_ptr_cog
copyToCog1              rdlong  rxmask_cog, t1
                        add     copyToCog1, destinationIncrement
                        add     t1, #4
                        djnz    txdata, #copyToCog1
                                                
' INITIALIZATIONS ==============================================================================
' port 3 initialization -------------------------------------------------------------
                        test    rxtx_mode3_cog, #OCTX wz   'init tx pin according to mode
                        test    rxtx_mode3_cog, #INVERTTX wc
        if_z_ne_c or            outa, txmask3_cog
        if_z            or      dira, txmask3_cog
                                                      'patch tx routine depending on invert and oc
                                                      'if invert change muxc to muxnc
                                                      'if oc change outa to dira
        if_z_eq_c or            txout3, domuxnc        'patch muxc to muxnc
        if_nz           movd    txout3, #dira          'change destination from outa to dira
                                                      'patch rx wait for start bit depending on invert
                        test    rxtx_mode3_cog, #INVERTRX wz 'wait for start bit on rx pin
        if_nz           xor     start3, doifc2ifnc     'if_c jmp to if_nc
                                                      'patch tx routine depending on whether cts is used
                                                      'and if it is inverted
                        or      ctsmask3_cog, #0     wz    'cts pin? z not set if in use
        if_nz           test    rxtx_mode3_cog, #INVERTCTS wc 'c set if inverted
        if_nz_and_c     or      ctsi3, doif_z_or_nc    'if_nc jmp   (TTA) reversed order to correctly invert CTS
        if_nz_and_nc    or      ctsi3, doif_z_or_c     'if_c jmp
                                                      'if not cts remove the test by moving
                                                      'the transmit entry point down 1 instruction
                                                      'and moving the jmpret over the cts test
                                                      'and changing co-routine entry point
        if_z            mov     txcts3, transmit3      'copy the jmpret over the cts test
        if_z            movs    ctsi3, #txcts3         'patch the jmps to transmit to txcts0
        if_z            add     txcode3, #1            'change co-routine entry to skip first jmpret
                                                      'patch rx routine depending on whether rts is used
                                                      'and if it is inverted
                        or      rtsmask3_cog, #0     wz
        if_nz           or      dira, rtsmask3_cog          ' (TTA) rts needs to be an output
        if_nz           test    rxtx_mode3_cog, #INVERTRTS wc
        if_nz_and_nc    or      rts3, domuxnc          'patch muxc to muxnc
        if_z            mov     norts3, rec3i          'patch rts code to a jmp #receive3
        if_z            movs    start3, #receive3      'skip all rts processing                  

                        or      txmask3_cog, #0      wz       'if tx pin not used
        if_z            movi    transmit3, #%010111_000  ' patch it out entirely by making the jmpret into a jmp (TTA)
                        or      rxmask3_cog, #0      wz       'ditto for rx routine
        if_z            movi    receive3, #%010111_000   ' (TTA)
                                                         ' in pcFullDuplexSerial4fc, the bypass was ostensibly done
                                                         ' by patching the co-routine variables,
                                                         ' but it was commented out, and didn't work when restored
                                                         ' so I did it by changing the affected jmpret to jmp.
                                                         ' Now the jitter is MUCH reduced.
' port 2 initialization -------------------------------------------------------------
                        test    rxtx_mode2_cog, #OCTX wz   'init tx pin according to mode
                        test    rxtx_mode2_cog, #INVERTTX wc
        if_z_ne_c       or      outa, txmask2_cog
        if_z            or      dira, txmask2_cog
        if_z_eq_c       or      txout2, domuxnc        'patch muxc to muxnc
        if_nz           movd    txout2, #dira          'change destination from outa to dira
                        test    rxtx_mode2_cog, #INVERTRX wz 'wait for start bit on rx pin
        if_nz           xor     start2, doifc2ifnc     'if_c jmp to if_nc
                        or      ctsmask2_cog, #0     wz
        if_nz           test    rxtx_mode2_cog, #INVERTCTS wc
        if_nz_and_c     or      ctsi2, doif_z_or_nc    'if_nc jmp   (TTA) reversed order to correctly invert CTS
        if_nz_and_nc    or      ctsi2, doif_z_or_c     'if_c jmp
       if_z            mov     txcts2, transmit2      'copy the jmpret over the cts test
        if_z            movs    ctsi2, #txcts2         'patch the jmps to transmit to txcts0  
        if_z            add     txcode2, #1            'change co-routine entry to skip first jmpret
                        or      rtsmask2_cog, #0     wz
        if_nz           or      dira, rtsmask2_cog          ' (TTA) rts needs to be an output
        if_nz           test    rxtx_mode2_cog, #INVERTRTS wc
        if_nz_and_nc    or      rts2, domuxnc          'patch muxc to muxnc
        if_z            mov     norts2, rec2i          'patch to a jmp #receive2
        if_z            movs    start2, #receive2      'skip all rts processing                  

                                or txmask2_cog, #0    wz       'if tx pin not used
        if_z            movi    transmit2, #%010111_000   ' patch it out entirely by making the jmpret into a jmp (TTA)
                        or      rxmask2_cog, #0      wz        'ditto for rx routine
        if_z            movi    receive2, #%010111_000    ' (TTA)

' port 1 initialization -------------------------------------------------------------
                        test    rxtx_mode1_cog, #OCTX wz   'init tx pin according to mode
                        test    rxtx_mode1_cog, #INVERTTX wc
        if_z_ne_c       or      outa, txmask1_cog
        if_z            or      dira, txmask1_cog
        if_z_eq_c       or      txout1, domuxnc        'patch muxc to muxnc
        if_nz           movd    txout1, #dira          'change destination from outa to dira
                        test    rxtx_mode1_cog, #INVERTRX wz 'wait for start bit on rx pin
        if_nz           xor     start1, doifc2ifnc     'if_c jmp to if_nc
                        or      ctsmask1_cog, #0     wz
        if_nz           test    rxtx_mode1_cog, #INVERTCTS wc
        if_nz_and_c     or      ctsi1, doif_z_or_nc    'if_nc jmp   (TTA) reversed order to correctly invert CTS
        if_nz_and_nc    or      ctsi1, doif_z_or_c     'if_c jmp
        if_z            mov     txcts1, transmit1      'copy the jmpret over the cts test
        if_z            movs    ctsi1, #txcts1         'patch the jmps to transmit to txcts0  
        if_z            add     txcode1, #1            'change co-routine entry to skip first jmpret
                                                      'patch rx routine depending on whether rts is used
                                                      'and if it is inverted
                        or      rtsmask1_cog, #0     wz
        if_nz           or      dira, rtsmask1_cog          ' (TTA) rts needs to be an output
        if_nz           test    rxtx_mode1_cog, #INVERTRTS wc
        if_nz_and_nc    or      rts1, domuxnc          'patch muxc to muxnc
        if_z            mov     norts1, rec1i          'patch to a jmp #receive1
        if_z            movs    start1, #receive1      'skip all rts processing                  

                        or      txmask1_cog, #0      wz       'if tx pin not used
        if_z            movi    transmit1, #%010111_000  ' patch it out entirely by making the jmpret into a jmp (TTA)
                        or      rxmask1_cog, #0      wz       'ditto for rx routine
        if_z            movi    receive1, #%010111_000   ' (TTA)

' port 0 initialization -------------------------------------------------------------
                        test    rxtx_mode_cog, #OCTX wz    'init tx pin according to mode
                        test    rxtx_mode_cog, #INVERTTX wc
        if_z_ne_c       or      outa, txmask_cog
        if_z            or      dira, txmask_cog
                                                      'patch tx routine depending on invert and oc
                                                      'if invert change muxc to muxnc
                                                      'if oc change out1 to dira
              if_z_eq_c or      txout0, domuxnc        'patch muxc to muxnc
              if_nz     movd    txout0, #dira          'change destination from outa to dira
                                                      'patch rx wait for start bit depending on invert
                        test    rxtx_mode_cog, #INVERTRX wz  'wait for start bit on rx pin
              if_nz     xor     start0, doifc2ifnc     'if_c jmp to if_nc
                                                      'patch tx routine depending on whether cts is used
                                                      'and if it is inverted
                        or      ctsmask_cog, #0     wz     'cts pin? z not set if in use
              if_nz     or      dira, rtsmask_cog          ' (TTA) rts needs to be an output
              if_nz     test    rxtx_mode_cog, #INVERTCTS wc 'c set if inverted
        if_nz_and_c     or      ctsi0, doif_z_or_nc    'if_nc jmp   (TTA) reversed order to correctly invert CTS
        if_nz_and_nc    or      ctsi0, doif_z_or_c     'if_c jmp
              if_z      mov     txcts0, transmit       'copy the jmpret over the cts test
              if_z      movs    ctsi0, #txcts0         'patch the jmps to transmit to txcts0  
              if_z      add     txcode, #1             'change co-routine entry to skip first jmpret
                                                      'patch rx routine depending on whether rts is used
                                                      'and if it is inverted
                        or      rtsmask_cog, #0     wz     'rts pin, z not set if in use
              if_nz     test    rxtx_mode_cog, #INVERTRTS wc
        if_nz_and_nc    or      rts0, domuxnc          'patch muxc to muxnc
              if_z      mov     norts0, rec0i          'patch to a jmp #receive
              if_z      movs    start0, #receive       'skip all rts processing if not used

                        or      txmask_cog, #0      wz       'if tx pin not used
              if_z      movi    transmit, #%010111_000  ' patch it out entirely by making the jmpret into a jmp (TTA)
                        or      rxmask_cog,#0      wz       'ditto for rx routine
              if_z      movi    receive, #%010111_000   ' (TTA)
'
' MAIN LOOP  =======================================================================================
' Receive0 -------------------------------------------------------------------------------------
receive                 jmpret  rxcode, txcode         'run a chunk of transmit code, then return
                                                      'patched to a jmp if pin not used                        
                        test    rxmask_cog, ina      wc
start0        if_c      jmp     #norts0               'go check rts if no start bit
                                                      ' have to check rts because other process may remove chars
                                                      'will be patched to jmp #receive if no rts  

                        mov     rxbits, #9             'ready to receive byte
                        mov     rxcnt, bit4_ticks_cog      '1/4 bits
                        add     rxcnt, cnt                          

:bit                    add     rxcnt, bit_ticks_cog       '1 bit period
                        
:wait                   jmpret  rxcode, txcode         'run a chuck of transmit code, then return

                        mov     t1, rxcnt              'check if bit receive period done
                        sub     t1, cnt
                        cmps    t1, #0           wc
              if_nc     jmp     #:wait

                        test    rxmask_cog, ina      wc    'receive bit on rx pin
                        rcr     rxdata, #1
                        djnz    rxbits, #:bit          'get remaining bits
                        test    rxtx_mode_cog, #INVERTRX  wz      'find out if rx is inverted
              if_z_ne_c jmp     #receive              'abort if no stop bit   (TTA) (from serialMirror)
                        jmpret  rxcode, txcode         'run a chunk of transmit code, then return
                        
                        shr     rxdata, #32-9          'justify and trim received byte

                        wrbyte  rxdata, rxbuff_head_ptr_cog'{7-22} '1wr
                        add     rx_head_cog, #1
                        cmpsub  rx_head_cog, rxsize_cog   ' (TTA) allows non-binary buffer size
                        wrword  rx_head_cog, rx_head_ptr_cog   '{8}     '2wr
                        mov     rxbuff_head_ptr_cog, rxbuff_ptr_cog 'calculate next byte head_ptr
                        add     rxbuff_head_ptr_cog, rx_head_cog
norts0                  rdword  rx_tail_cog, rx_tail_ptr_cog   '{7-22 or 8} will be patched to jmp #r3 if no rts
                                                                '1rd
                        mov     t1, rx_head_cog
                        sub     t1, rx_tail_cog  wc          'calculate number bytes in buffer, (TTA) add wc
'                        and     t1,#$7F               'fix wrap
              if_c      add     t1, rxsize_cog           ' fix wrap, (TTA) change
                        cmps    t1, rtssize_cog      wc    'is it more than the threshold
rts0                    muxc    outa, rtsmask_cog          'set rts correctly

rec0i                   jmp     #receive              'byte done, receive next byte
'
' Receive1 -------------------------------------------------------------------------------------
'
receive1                jmpret  rxcode1, txcode1       'run a chunk of transmit code, then return
                        
                        test    rxmask1_cog, ina     wc
start1        if_c      jmp     #norts1               'go check rts if no start bit

                        mov     rxbits1, #9            'ready to receive byte
                        mov     rxcnt1, bit4_ticks1_cog    '1/4 bits
                        add     rxcnt1, cnt                          

:bit1                   add     rxcnt1, bit_ticks1_cog     '1 bit period
                        
:wait1                  jmpret  rxcode1, txcode1       'run a chuck of transmit code, then return

                        mov     t1, rxcnt1             'check if bit receive period done
                        sub     t1, cnt
                        cmps    t1, #0           wc
              if_nc     jmp     #:wait1

                        test    rxmask1_cog, ina     wc    'receive bit on rx pin
                        rcr     rxdata1, #1
                        djnz    rxbits1, #:bit1

                        test    rxtx_mode1_cog, #INVERTRX  wz      'find out if rx is inverted
              if_z_ne_c jmp     #receive1              'abort if no stop bit   (TTA) (from serialMirror)

                        jmpret  rxcode1, txcode1       'run a chunk of transmit code, then return
                        shr     rxdata1, #32-9         'justify and trim received byte

                        wrbyte  rxdata1, rxbuff_head_ptr1_cog '7-22
                        add     rx_head1_cog, #1
                        cmpsub  rx_head1_cog, rxsize1_cog         ' (TTA) allows non-binary buffer size
                        wrword  rx_head1_cog, rx_head_ptr1_cog
                        mov     rxbuff_head_ptr1_cog, rxbuff_ptr1_cog 'calculate next byte head_ptr
                        add     rxbuff_head_ptr1_cog, rx_head1_cog
norts1                  rdword  rx_tail1_cog, rx_tail_ptr1_cog    '7-22 or 8 will be patched to jmp #r3 if no rts
                        mov     t1, rx_head1_cog
                        sub     t1, rx_tail1_cog    wc
              if_c      add     t1, rxsize1_cog           ' fix wrap, (TTA) change
                        cmps    t1, rtssize1_cog     wc
rts1                    muxc    outa, rtsmask1_cog

rec1i                   jmp     #receive1             'byte done, receive next byte
'
' Receive2 -------------------------------------------------------------------------------------
'
receive2                jmpret  rxcode2, txcode2       'run a chunk of transmit code, then return
                        
                        test    rxmask2_cog, ina     wc
start2        if_c      jmp     #norts2               'go check rts if no start bit
        
                        mov     rxbits2, #9            'ready to receive byte
                        mov     rxcnt2, bit4_ticks2_cog    '1/4 bits
                        add     rxcnt2, cnt                          

:bit2                   add     rxcnt2, bit_ticks2_cog     '1 bit period
                        
:wait2                  jmpret  rxcode2, txcode2       'run a chuck of transmit code, then return

                        mov     t1, rxcnt2             'check if bit receive period done
                        sub     t1, cnt
                        cmps    t1, #0           wc
              if_nc     jmp     #:wait2

                        test    rxmask2_cog, ina     wc    'receive bit on rx pin
                        rcr     rxdata2, #1
                        djnz    rxbits2, #:bit2
                        test    rxtx_mode2_cog, #INVERTRX  wz      'find out if rx is inverted
              if_z_ne_c jmp     #receive2              'abort if no stop bit   (TTA) (from serialMirror)

                        jmpret  rxcode2, txcode2       'run a chunk of transmit code, then return
                        shr     rxdata2, #32-9         'justify and trim received byte

                        wrbyte  rxdata2, rxbuff_head_ptr2_cog '7-22
                        add     rx_head2_cog, #1
                        cmpsub  rx_head2_cog, rxsize2_cog        '  ' (TTA) allows non-binary buffer size
                        wrword  rx_head2_cog, rx_head_ptr2_cog
                        mov     rxbuff_head_ptr2_cog, rxbuff_ptr2_cog 'calculate next byte head_ptr
                        add     rxbuff_head_ptr2_cog, rx_head2_cog
norts2                  rdword  rx_tail2_cog, rx_tail_ptr2_cog    '7-22 or 8 will be patched to jmp #r3 if no rts
                        mov     t1, rx_head2_cog
                        sub     t1, rx_tail2_cog    wc
              if_c      add     t1, rxsize2_cog            ' fix wrap, (TTA) change
                        cmps    t1, rtssize2_cog     wc
rts2                    muxc    outa, rtsmask2_cog

rec2i                   jmp     #receive2             'byte done, receive next byte
'
' Receive3 -------------------------------------------------------------------------------------
'
receive3                jmpret  rxcode3, txcode3       'run a chunk of transmit code, then return

                        test    rxmask3_cog, ina     wc
start3        if_c      jmp     #norts3               'go check rts if no start bit

                        mov     rxbits3, #9            'ready to receive byte
                        mov     rxcnt3, bit4_ticks3_cog    '1/4 bits
                        add     rxcnt3, cnt                          

:bit3                   add     rxcnt3, bit_ticks3_cog     '1 bit period
                        
:wait3                  jmpret  rxcode3, txcode3       'run a chuck of transmit code, then return

                        mov     t1, rxcnt3             'check if bit receive period done
                        sub     t1, cnt
                        cmps    t1, #0           wc
              if_nc     jmp     #:wait3

                        test    rxmask3_cog, ina     wc    'receive bit on rx pin
                        rcr     rxdata3, #1
                        djnz    rxbits3, #:bit3
                        test    rxtx_mode3_cog, #INVERTRX  wz      'find out if rx is inverted
              if_z_ne_c jmp     #receive3              'abort if no stop bit   (TTA) (from serialMirror)

                        jmpret  rxcode3, txcode3       'run a chunk of transmit code, then return
                        shr     rxdata3, #32-9         'justify and trim received byte

                        wrbyte  rxdata3, rxbuff_head_ptr3_cog '7-22
                        add     rx_head3_cog, #1
                        cmpsub  rx_head3_cog, rxsize3_cog         ' (TTA) allows non-binary buffer size
                        wrword  rx_head3_cog, rx_head_ptr3_cog    '8
                        mov     rxbuff_head_ptr3_cog, rxbuff_ptr3_cog 'calculate next byte head_ptr
                        add     rxbuff_head_ptr3_cog, rx_head3_cog
norts3                  rdword  rx_tail3_cog, rx_tail_ptr3_cog    '7-22 or 8, may be patched to jmp #r3 if no rts
                        mov     t1, rx_head3_cog
                        sub     t1, rx_tail3_cog    wc
              if_c      add     t1, rxsize3_cog            ' fix wrap, (TTA) change
                        cmps    t1, rtssize3_cog     wc    'is buffer more that 3/4 full?
rts3                    muxc    outa, rtsmask3_cog

rec3i                   jmp     #receive3             'byte done, receive next byte
'
' TRANSMIT =======================================================================================
'
transmit                jmpret  txcode, rxcode1        'run a chunk of receive code, then return
                                                      'patched to a jmp if pin not used                        
                        
txcts0                  test    ctsmask_cog, ina     wc    'if flow-controlled dont send
                        rdword  t1, tx_head_ptr_cog        '{7-22} - head[0]
                        cmp     t1, tx_tail_cog      wz    'tail[0]
ctsi0         if_z      jmp     #transmit             'may be patched to if_z_or_c or if_z_or_nc

                        rdbyte  txdata, txbuff_tail_ptr_cog '{8}
                        add     tx_tail_cog, #1
                        cmpsub  tx_tail_cog, txsize_cog    wz   ' (TTA) for individually sized buffers, will zero at rollover
                        wrword  tx_tail_cog, tx_tail_ptr_cog    '{8}  
              if_z      mov     txbuff_tail_ptr_cog, txbuff_ptr_cog 'reset tail_ptr if we wrapped
              if_nz     add     txbuff_tail_ptr_cog, #1    'otherwise add 1
                        
                        jmpret  txcode, rxcode1

                        shl     txdata, #2
                        or      txdata, txbitor        'ready byte to transmit
                        mov     txbits, #11
                        mov     txcnt, cnt

txbit                   shr     txdata, #1       wc
txout0                  muxc    outa, txmask_cog           'maybe patched to muxnc dira,txmask
                        add     txcnt, bit_ticks_cog       'ready next cnt

:wait                   jmpret  txcode, rxcode1        'run a chunk of receive code, then return

                        mov     t1, txcnt              'check if bit transmit period done
                        sub     t1, cnt
                        cmps    t1, #0           wc
              if_nc     jmp     #:wait

                        djnz    txbits, #txbit         'another bit to transmit?
txjmp0                  jmp     ctsi0                 'byte done, transmit next byte
'
' Transmit1 -------------------------------------------------------------------------------------
'
transmit1               jmpret  txcode1, rxcode2       'run a chunk of receive code, then return
                        
txcts1                  test    ctsmask1_cog, ina    wc    'if flow-controlled dont send
                        rdword  t1, tx_head_ptr1_cog
                        cmp     t1, tx_tail1_cog     wz
ctsi1         if_z      jmp     #transmit1            'may be patched to if_z_or_c or if_z_or_nc

                        rdbyte  txdata1, txbuff_tail_ptr1_cog
                        add     tx_tail1_cog, #1
                        cmpsub  tx_tail1_cog, txsize1_cog   wz   ' (TTA) for individually sized buffers, will zero at rollover
                        wrword  tx_tail1_cog, tx_tail_ptr1_cog
              if_z      mov     txbuff_tail_ptr1_cog, txbuff_ptr1_cog 'reset tail_ptr if we wrapped
              if_nz     add     txbuff_tail_ptr1_cog, #1   'otherwise add 1

                        jmpret  txcode1, rxcode2       'run a chunk of receive code, then return
                        
                        shl     txdata1, #2
                        or      txdata1, txbitor       'ready byte to transmit
                        mov     txbits1, #11
                        mov     txcnt1, cnt

txbit1                  shr     txdata1, #1      wc
txout1                  muxc    outa, txmask1_cog          'maybe patched to muxnc dira,txmask
                        add     txcnt1, bit_ticks1_cog     'ready next cnt

:wait1                  jmpret  txcode1, rxcode2       'run a chunk of receive code, then return

                        mov     t1, txcnt1             'check if bit transmit period done
                        sub     t1, cnt
                        cmps    t1, #0           wc
              if_nc     jmp     #:wait1

                        djnz    txbits1, #txbit1       'another bit to transmit?
txjmp1                  jmp     ctsi1                 'byte done, transmit next byte
'
' Transmit2 -------------------------------------------------------------------------------------
'
transmit2               jmpret  txcode2, rxcode3       'run a chunk of receive code, then return
                        
txcts2                  test    ctsmask2_cog, ina    wc    'if flow-controlled dont send
                        rdword  t1, tx_head_ptr2_cog
                        cmp     t1, tx_tail2_cog     wz
ctsi2         if_z      jmp     #transmit2            'may be patched to if_z_or_c or if_z_or_nc

                        rdbyte  txdata2, txbuff_tail_ptr2_cog
                        add     tx_tail2_cog, #1
                        cmpsub  tx_tail2_cog, txsize2_cog   wz   ' (TTA) for individually sized buffers, will zero at rollover
                        wrword  tx_tail2_cog, tx_tail_ptr2_cog
              if_z      mov     txbuff_tail_ptr2_cog, txbuff_ptr2_cog 'reset tail_ptr if we wrapped
              if_nz     add     txbuff_tail_ptr2_cog, #1   'otherwise add 1

                        jmpret  txcode2, rxcode3

                        shl     txdata2, #2
                        or      txdata2, txbitor       'ready byte to transmit
                        mov     txbits2, #11
                        mov     txcnt2, cnt

txbit2                  shr     txdata2, #1      wc
txout2                  muxc    outa, txmask2_cog          'maybe patched to muxnc dira,txmask
                        add     txcnt2, bit_ticks2_cog     'ready next cnt

:wait2                  jmpret  txcode2, rxcode3       'run a chunk of receive code, then return

                        mov     t1, txcnt2             'check if bit transmit period done
                        sub     t1, cnt
                        cmps    t1, #0           wc
              if_nc     jmp     #:wait2

                        djnz    txbits2, #txbit2       'another bit to transmit?
txjmp2                  jmp     ctsi2                 'byte done, transmit next byte
'
' Transmit3 -------------------------------------------------------------------------------------
'
transmit3               jmpret  txcode3, rxcode        'run a chunk of receive code, then return
                        
txcts3                  test    ctsmask3_cog, ina    wc    'if flow-controlled dont send
                        rdword  t1, tx_head_ptr3_cog
                        cmp     t1, tx_tail3_cog   wz
ctsi3         if_z      jmp     #transmit3            'may be patched to if_z_or_c or if_z_or_nc

                        rdbyte  txdata3, txbuff_tail_ptr3_cog
                        add     tx_tail3_cog, #1
                        cmpsub  tx_tail3_cog, txsize3_cog   wz   ' (TTA) for individually sized buffers, will zero at rollover
                        wrword  tx_tail3_cog, tx_tail_ptr3_cog
              if_z      mov     txbuff_tail_ptr3_cog, txbuff_ptr3_cog 'reset tail_ptr if we wrapped
              if_nz     add     txbuff_tail_ptr3_cog, #1   'otherwise add 1

                        jmpret  txcode3, rxcode

                        shl     txdata3, #2
                        or      txdata3, txbitor       'ready byte to transmit
                        mov     txbits3, #11
                        mov     txcnt3, cnt

txbit3                  shr     txdata3, #1      wc
txout3                  muxc    outa, txmask3_cog          'maybe patched to muxnc dira,txmask
                        add     txcnt3, bit_ticks3_cog     'ready next cnt

:wait3                  jmpret  txcode3, rxcode        'run a chunk of receive code, then return

                        mov     t1, txcnt3             'check if bit transmit period done
                        sub     t1, cnt
                        cmps    t1, #0           wc
              if_nc     jmp     #:wait3

                        djnz    txbits3, #txbit3       'another bit to transmit?
txjmp3                  jmp     ctsi3                 'byte done, transmit next byte
'
DAT
'The following are constants used by pasm for patching the code, depending on options required
doifc2ifnc              long $003c0000          'patch condition if_c to if_nc using xor
doif_z_or_c             long $00380000          'patch condition if_z to if_z_or_c using or
doif_z_or_nc            long $002c0000          'patch condition if_z to if_z_or_nc using or
domuxnc                 long $04000000          'patch muxc to muxnc using or
txbitor                 long $0401              'bits to or for transmitting, adding start and stop bits
destinationIncrement    long %10_0000_0000
destAndSourceIncrement  long %10_0000_0001
' Buffer sizes initialized from CONstants and used by both spin and pasm

rxsize_cog              long 0           ' (TTA) size of the rx and tx buffers is available to pasm
rxsize1_cog             long 0           ' these values are transfered from the declared CONstants
rxsize2_cog             long 0           ' at startup, individually configurable
rxsize3_cog             long 0
txsize_cog              long 0
txsize1_cog             long 0
txsize2_cog             long 0
txsize3_cog             long 0

' Dont Change the order of these initialized variables within port groups of 4 without modifying
' the code to match in assembly

rxtx_mode_cog           long 0  ' mode setting from values passed in by addport
rxtx_mode1_cog          long 0  
rxtx_mode2_cog          long 0
rxtx_mode3_cog          long 0
rxbuff_ptr_cog          long 0  ' These are the base hub addresses of the receive buffers
rxbuff_ptr1_cog         long 0  ' initialized in spin, referenced in pasm and spin
rxbuff_ptr2_cog         long 0  ' these buffers and sizes are individually configurable
rxbuff_ptr3_cog         long 0
txbuff_ptr_cog          long 0  ' These are the base hub addresses of the transmit buffers
txbuff_ptr1_cog         long 0
txbuff_ptr2_cog         long 0
txbuff_ptr3_cog         long 0
rtssize_cog             long 0  ' threshold in count of bytes above which will assert rts to stop flow
rtssize1_cog            long 0
rtssize2_cog            long 0
rtssize3_cog            long 0
rxbuff_head_ptr_cog     long 0  ' Hub address of data received, base plus offset
rxbuff_head_ptr1_cog    long 0  ' pasm writes WRBYTE to hub at this address, initialized in spin to base address
rxbuff_head_ptr2_cog    long 0
rxbuff_head_ptr3_cog    long 0
txbuff_tail_ptr_cog     long 0  ' Hub address of data tranmitted, base plus offset
txbuff_tail_ptr1_cog    long 0  ' pasm reads RDBYTE from hub at this address, initialized in spin to base address
txbuff_tail_ptr2_cog    long 0
txbuff_tail_ptr3_cog    long 0


rx_head_ptr_cog         long 0  ' pointer to the hub address of where the head and tail offset pointers are stored
rx_head_ptr1_cog        long 0  ' these pointers are initialized in spin but then used only by pasm
rx_head_ptr2_cog        long 0  ' the pasm cog has to know where in the hub to find those offsets.
rx_head_ptr3_cog        long 0
rx_tail_ptr_cog         long 0
rx_tail_ptr1_cog        long 0
rx_tail_ptr2_cog        long 0
rx_tail_ptr3_cog        long 0
tx_head_ptr_cog         long 0
tx_head_ptr1_cog        long 0
tx_head_ptr2_cog        long 0
tx_head_ptr3_cog        long 0
tx_tail_ptr_cog         long 0
tx_tail_ptr1_cog        long 0
tx_tail_ptr2_cog        long 0
tx_tail_ptr3_cog        long 0

rxmask_cog              long 0  ' a single bit set, a mask for the pin used for receive, zero if port not used for receive
rxmask1_cog             long 0
rxmask2_cog             long 0
rxmask3_cog             long 0
txmask_cog              long 0  ' a single bit set, a mask for the pin used for transmit, zero if port not used for transmit
txmask1_cog             long 0
txmask2_cog             long 0
txmask3_cog             long 0
ctsmask_cog             long 0  ' a single bit set, a mask for the pin used for cts input, zero if port not using cts
ctsmask1_cog            long 0
ctsmask2_cog            long 0
ctsmask3_cog            long 0
rtsmask_cog             long 0  ' a single bit set, a mask for the pin used for rts output, zero if port not using rts
rtsmask1_cog            long 0
rtsmask2_cog            long 0
rtsmask3_cog            long 0
bit4_ticks_cog          long 0  ' bit ticks for start bit, 1/4 of standard bit
bit4_ticks1_cog         long 0
bit4_ticks2_cog         long 0
bit4_ticks3_cog         long 0
bit_ticks_cog           long 0  ' clock ticks per bit
bit_ticks1_cog          long 0
bit_ticks2_cog          long 0
bit_ticks3_cog          long 0

rx_head_cog             long 0  ' rx head pointer, from 0 to size of rx buffer, used in spin and pasm
rx_head1_cog            long 0  ' data is enqueued to this offset above base, rxbuff_ptr
rx_head2_cog            long 0
rx_head3_cog            long 0
rx_tail_cog             long 0  ' rx tail pointer, ditto, zero to size of rx buffer
rx_tail1_cog            long 0  ' data is dequeued from this offset above base, rxbuff_ptr
rx_tail2_cog            long 0
rx_tail3_cog            long 0
tx_tail_cog             long 0  ' tx tail pointer, ditto, zero to size of rx buffer
tx_tail1_cog            long 0  ' data is transmitted from this offset above base, txbuff_ptr
tx_tail2_cog            long 0
tx_tail3_cog            long 0


'  Start of HUB overlay ------------------------------------------------------------------------
' Some locations within the next set of values, after being init'd to zero, are then filled from spin with options
' That are transferred to and accessed by the pasm cog once started, but no longer needed in spin.
' Therefore, tx and rx buffers start here and overlays the hub footprint of these variables.
' tx_buffers come first, 0,1,2,3, then rx buffers 0,1,2,3 by offset from "buffers"
'overlay
'buffers
txdata                  res 1
txbits                  res 1
txcnt                   res 1
txdata1                 res 1
txbits1                 res 1
txcnt1                  res 1
txdata2                 res 1
txbits2                 res 1
txcnt2                  res 1
txdata3                 res 1
txbits3                 res 1
txcnt3                  res 1
rxdata                  res 1
rxbits                  res 1
rxcnt                   res 1
rxdata1                 res 1
rxbits1                 res 1
rxcnt1                  res 1
rxdata2                 res 1
rxbits2                 res 1
rxcnt2                  res 1
rxdata3                 res 1
rxbits3                 res 1
rxcnt3                  res 1
t1                      res 1  ' this is a temporary variable used by pasm

                        fit                                                                                                                                                                                       
afterData     byte 255

CON

  NOMODE                        = %000000
  INVERTRX                      = %000001
  INVERTTX                      = %000010
  OCTX                          = %000100
  NOECHO                        = %001000
  INVERTCTS                     = %010000
  INVERTRTS                     = %100000

  PINNOTUSED                    = -1                    'tx/tx/cts/rts pin is not used
  DEFAULTTHRESHOLD              = 0                     ' zero defaults to 3/4 of buffer length

CON

  ' offsets in buffer
  RX_MASK_OFFSET = 0
  TX_MASK_OFFSET = 4
  CTS_MASK_OFFSET = 8
  RTS_MASK_OFFSET = 12
  BIT_4_TICKS_OFFSET = 16
  BIT_TICKS_OFFSET = 20
  LONGS_TO_CLEAR = BIT_TICKS_OFFSET + 4
                                                                                                                                                                       