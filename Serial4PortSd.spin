DAT ObjectName          byte "Serial4PortSd", 0
CON
{{  FullDuplexSerial4portPlus version 1.01
  - Tracy Allen (TTA)   (c)22-Jan-2011   MIT license, see end of file for terms of use.  Extends existing terms of use.
}}

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
  
CON

  DEFAULT_DEBUG_PORT = 0
  
OBJ

  Format : "StrFmt"

DAT ' Hub Variables

rxchar                  byte 0  ' used by spin rxcheck, for inversion of received data
rxchar1                 byte 0
rxchar2                 byte 0
rxchar3                 byte 0
'cog                     long 0  'cog flag/id
debugLock               long -1 ' available to all cogs
'debugPort               byte DEFAULT_DEBUG_PORT

                        org     ' "startFlag" needs to be long aligned.
startFlag               word 0                        
rxsize                  word 0  ' (TTA) size of the rx and tx buffers is available to pasm and spin
rxsize1                 word 0  ' these values are initialized by the "AddPort" method
rxsize2                 word 0  ' at startup, individually configurable
rxsize3                 word 0
txsize                  word 0
txsize1                 word 0
txsize2                 word 0
txsize3                 word 0
rxtx_mode               word 0  ' mode setting from values passed in by addport
rxtx_mode1              word 0  ' used by Spin and copied to PASM           '
rxtx_mode2              word 0
rxtx_mode3              word 0
rxbuff_ptr              word 0  ' These are the base hub addresses of the receive buffers
rxbuff_ptr1             word 0  ' initialized in Spin, referenced in pasm and Spin
rxbuff_ptr2             word 0  ' these buffers and sizes are individually configurable
rxbuff_ptr3             word 0
txbuff_ptr              word 0  ' These are the base hub addresses of the transmit buffers
txbuff_ptr1             word 0  ' Used by "tx" method and in PASM.
txbuff_ptr2             word 0
txbuff_ptr3             word 0

rtssize                 word 0  ' threshold in count of bytes above which will assert rts to stop flow
rtssize1                word 0  ' Used only in PASM
rtssize2                word 0
rtssize3                word 0
rxbuff_head_ptr         word 0  ' Hub address of data received, base plus offset
rxbuff_head_ptr1        word 0  ' pasm writes WRBYTE to hub at this address, initialized in spin to base address
rxbuff_head_ptr2        word 0  ' Used only in PASM
rxbuff_head_ptr3        word 0
txbuff_tail_ptr         word 0  ' Hub address of data tranmitted, base plus offset
txbuff_tail_ptr1        word 0  ' pasm reads RDBYTE from hub at this address, initialized in spin to base address
txbuff_tail_ptr2        word 0  ' Used only in PASM
txbuff_tail_ptr3        word 0


rx_head_ptr             word 0  ' pointer to the hub address of where the head and tail offset pointers are stored
                                 ' these pointers are initialized in spin but then used only by pasm
                                ' the pasm cog has to know where in the hub to find those offsets.

'' The variables below are used only by the Spin section of the program.
bufferPtr               word 0  ' Should point to a long aligned location.
rx_head                 word 0  ' rx head pointer, from 0 to size of rx buffer, used in spin and pasm
rx_head1                word 0  ' data is enqueued to this offset above base, rxbuff_ptr
rx_head2                word 0
rx_head3                word 0
rx_tail                 word 0  ' rx tail pointer, ditto, zero to size of rx buffer
rx_tail1                word 0  ' data is dequeued from this offset above base, rxbuff_ptr
rx_tail2                word 0
rx_tail3                word 0
tx_head                 word 0  ' tx head pointer, , from 0 to size of tx buffer, used in spin only
tx_head1                word 0  ' data is enqueued to this offset above base, txbuff_ptr
tx_head2                word 0
tx_head3                word 0
tx_tail                 word 0  ' tx tail pointer, ditto, zero to size of rx buffer
tx_tail1                word 0  ' data is transmitted from this offset above base, txbuff_ptr
tx_tail2                word 0
tx_tail3                word 0

PUB Init(pasmAddress, bufferAddress)
'' Always call init before adding ports
'' The buffer at location "bufferAddress" should be
'' long aligned. 96 bytes of the buffer will temporarily
'' be used to pass values to PASM. The parent object needs
'' to make sure there are 96 bytes available at the location
'' of "bufferAddress". This will unlikely be a problem since
'' the combined buffers of the serial driver will likely
'' exceed 96 bytes.

  bufferPtr := bufferAddress

  result := cognew(pasmAddress, @startFlag) + 1
  waitcnt(80_000 + cnt) ' give time for PASM to load completely
  longfill(bufferPtr, 0, LONGS_TO_CLEAR) ' unused port's values will be set to zero
                                        
PUB AddPort(port, rxpin, txpin, ctspin, rtspin, rtsthreshold, mode, baudrate, {
} rxBufferSize, txBufferSize)
'' Call AddPort to define each port
'' port 0-3 port index of which serial port
'' rx/tx/cts/rtspin pin number                          XXX#PINNOTUSED if not used
'' rtsthreshold - buffer threshold before rts is used   XXX#DEFAULTTHRSHOLD means use default
'' mode bit 0 = invert rx                               XXX#INVERTRX
'' mode bit 1 = invert tx                               XXX#INVERTTX
'' mode bit 2 = open-drain/source tx                    XXX#OCTX
'' mode bit 3 = ignore tx echo on rx                    XXX#NOECHO
'' mode bit 4 = invert cts                              XXX#INVERTCTS
'' mode bit 5 = invert rts                              XXX#INVERTRTS
'' baudrate

  if rxpin <> -1
    'rxmask[port] := |< rxpin
    long[bufferPtr][RX_MASK_OFFSET + port] := |< rxpin
  if txpin <> -1
    'txmask[port] := |< txpin
    long[bufferPtr][TX_MASK_OFFSET + port] := |< txpin
  if ctspin <> -1
    'ctsmask[port] := |< ctspin
    long[bufferPtr][CTS_MASK_OFFSET + port] := |< ctspin
  if rtspin <> -1
    'rtsmask[port] := |< rtspin
    long[bufferPtr][RTS_MASK_OFFSET + port] := |< rtspin 
    if (rtsthreshold > 0) and (rtsthreshold < rxsize[port])           ' (TTA) modified for variable buffer size
      rtssize[port] := rtsthreshold
    else
      rtssize[port] := rxsize[port]*3/4                        'default rts threshold 3/4 of buffer  TTS ref RX_BUFSIZE
  rxtx_mode[port] := mode
  if mode & INVERTRX
    rxchar[port] := $ff
  'bit_ticks[port] := (clkfreq / baudrate)
  long[bufferPtr][BIT_TICKS_OFFSET + port] := (clkfreq / baudrate)
  'bit4_ticks[port] := bit_ticks[port] >> 2
  long[bufferPtr][BIT_4_TICKS_OFFSET + port] := long[bufferPtr][BIT_TICKS_OFFSET + port] >> 2
  rxsize[port] := rxBufferSize
  txsize[port] := txBufferSize

PUB Start
'' Call start to start cog
'' Start serial driver - starts a cog
'' returns false if no cog available
''
'' tx buffers will start within the object footprint, overlaying certain locations that were initialized in spin
'' for  use within the cog but are not needed by spin thereafter and are not needed for object restart.

  txbuff_tail_ptr := txbuff_ptr  := bufferPtr                 ' (TTA) all buffers are calculated as offsets from this address.
  txbuff_tail_ptr1 := txbuff_ptr1 := txbuff_ptr + txsize      'base addresses of the corresponding port buffer.
  txbuff_tail_ptr2 := txbuff_ptr2 := txbuff_ptr1 + txsize1
  txbuff_tail_ptr3 := txbuff_ptr3 := txbuff_ptr2 + txsize2
  rxbuff_head_ptr := rxbuff_ptr := txbuff_ptr3 + txsize3     ' rx buffers follow immediately after the tx buffers, by size
  rxbuff_head_ptr1 := rxbuff_ptr1 := rxbuff_ptr + rxsize
  rxbuff_head_ptr2 := rxbuff_ptr2 := rxbuff_ptr1 + rxsize1
  rxbuff_head_ptr3 := rxbuff_ptr3 := rxbuff_ptr2 + rxsize2
                                                        ' note that txbuff_ptr ... rxbuff_ptr3 are the base addresses fixed
                                                        ' in memory for use by both spin and pasm
                                                        ' while txbuff_tail_ptr ... rxbuff_head_ptr3 are dynamic addresses used only by pasm
                                                        ' and here initialized to point to the start of the buffers.
                                                             ' the rx buffer #3 comes last, up through address @endfill
  rx_head_ptr := @rx_head                               ' (TTA) note: addresses of the head and tail counts are passed to the cog
                                                        ' if that is confusing, take heart.   These are pointers to pointers to pointers
  debugLock := locknew

  startFlag := 1

{PUB Init(bufferAddress)
''Always call init before adding ports
  'Stop
  bytefill(@startfill, 0, (@endfill-@startfill))        ' initialize head/tails,port info and hub buffer pointers

  if bufferAddress > 0
    bufferPtr := bufferAddress
  else
    bufferPtr := @buffers  
  return @rxsize                                        ' TTA returns pointer to data structure, buffer sizes.

PUB AddPort(port,rxpin,txpin,ctspin,rtspin,rtsthreshold,mode,baudrate)
'' Call AddPort to define each port
'' port 0-3 port index of which serial port
'' rx/tx/cts/rtspin pin number                          XXX#PINNOTUSED if not used
'' rtsthreshold - buffer threshold before rts is used   XXX#DEFAULTTHRSHOLD means use default
'' mode bit 0 = invert rx                               XXX#INVERTRX
'' mode bit 1 = invert tx                               XXX#INVERTTX
'' mode bit 2 = open-drain/source tx                    XXX#OCTX
'' mode bit 3 = ignore tx echo on rx                    XXX#NOECHO
'' mode bit 4 = invert cts                              XXX#INVERTCTS
'' mode bit 5 = invert rts                              XXX#INVERTRTS
'' baudrate
  if cog OR (port > 3)
    abort
  if rxpin <> -1
    long[@rxmask][port] := |< rxpin
  if txpin <> -1
    long[@txmask][port] := |< txpin
  if ctspin <> -1
    long[@ctsmask][port] := |< ctspin
  if rtspin <> -1
    long[@rtsmask][port] := |< rtspin
    if (rtsthreshold > 0) AND (rtsthreshold < rxsize[port])           ' (TTA) modified for variable buffer size
      long[@rtssize][port] := rtsthreshold
    else
      long[@rtssize][port] := rxsize[port]*3/4                        'default rts threshold 3/4 of buffer  TTS ref RX_BUFSIZE
  long[@rxtx_mode][port] := mode
  if mode & INVERTRX
    byte[@rxchar][port] := $ff
  long[@bit_ticks][port] := (clkfreq / baudrate)
  long[@bit4_ticks][port] := long[@bit_ticks][port] >> 2

PUB Start : okay
'' Call start to start cog
'' Start serial driver - starts a cog
'' returns false if no cog available
''
'' tx buffers will start within the object footprint, overlaying certain locations that were initialized in spin
'' for  use within the cog but are not needed by spin thereafter and are not needed for object restart.

  txbuff_tail_ptr := txbuff_ptr  := bufferPtr             ' (TTA) all buffers are calculated as offsets from this address.
  txbuff_tail_ptr1 := txbuff_ptr1 := txbuff_ptr + txsize      'base addresses of the corresponding port buffer.
  txbuff_tail_ptr2 := txbuff_ptr2 := txbuff_ptr1 + txsize1
  txbuff_tail_ptr3 := txbuff_ptr3 := txbuff_ptr2 + txsize2
  rxbuff_head_ptr := rxbuff_ptr  := txbuff_ptr3 + txsize3     ' rx buffers follow immediately after the tx buffers, by size
  rxbuff_head_ptr1 := rxbuff_ptr1 := rxbuff_ptr + rxsize
  rxbuff_head_ptr2 := rxbuff_ptr2 :=  rxbuff_ptr1 + rxsize1
  rxbuff_head_ptr3 := rxbuff_ptr3 :=  rxbuff_ptr2 + rxsize2
                                                        ' note that txbuff_ptr ... rxbuff_ptr3 are the base addresses fixed
                                                        ' in memory for use by both spin and pasm
                                                        ' while txbuff_tail_ptr ... rxbuff_head_ptr3 are dynamic addresses used only by pasm
                                                        ' and here initialized to point to the start of the buffers.
                                                             ' the rx buffer #3 comes last, up through address @endfill
  rx_head_ptr  := @rx_head                              ' (TTA) note: addresses of the head and tail counts are passed to the cog
  rx_head_ptr1 := @rx_head1                             ' if that is confusing, take heart.   These are pointers to pointers to pointers
  rx_head_ptr2 := @rx_head2
  rx_head_ptr3 := @rx_head3
  rx_tail_ptr  := @rx_tail
  rx_tail_ptr1 := @rx_tail1
  rx_tail_ptr2 := @rx_tail2
  rx_tail_ptr3 := @rx_tail3
  tx_head_ptr  := @tx_head
  tx_head_ptr1 := @tx_head1
  tx_head_ptr2 := @tx_head2
  tx_head_ptr3 := @tx_head3
  tx_tail_ptr  := @tx_tail
  tx_tail_ptr1 := @tx_tail1
  tx_tail_ptr2 := @tx_tail2
  tx_tail_ptr3 := @tx_tail3

  debugLock := locknew
  
  okay := cog := cognew(@entry, @rx_head) + 1
}
{PUB Stop
'' Stop serial driver - frees a cog
  if cog
    cogstop(cog~ - 1)


PUB getCogID : result
  return cog -1
}
PUB Rxflush(port)
'' Flush receive buffer, here until empty.

  repeat while Rxcheck(port) => 0

PUB Tx(port,txbyte)
'' Send byte (may wait for room in buffer)
  if port > 3
    abort
  repeat until (tx_tail[port] <> (tx_head[port] + 1) // txsize[port])
  byte[txbuff_ptr[port] + tx_head[port]] := txbyte
  tx_head[port] := (tx_head[port] + 1) // txsize[port]

  if rxtx_mode[port] & NOECHO
    Rx(port)

PUB Txs(port, txbyte)

  DebugCog
  if txbyte <> 13
    Tx(port, txbyte)

PUB Txe(port, txbyte)

  Tx(port, txbyte)
  lockclr(debugLock)
  
PUB Txse(port, txbyte)

  Txs(port, txbyte)
  lockclr(debugLock)

PUB Lock
'' set lock without sending cog ID

  'repeat until not lockset(debugLock)
  repeat while lockset(debugLock)

PUB DebugCog
'' display cog ID at the beginning of debug statements

  Lock
  Tx(0, 11)
  Tx(0, 13)
  dec(0, cogid)
  Tx(0, ":")
  Tx(0, 32)
  
PUB E

  lockclr(debugLock) 

PUB RxHowFull(port)    ' (TTA) added method
'' returns number of chars in rx buffer

  return ((rx_head[port] - rx_tail[port]) + rxsize[port]) // rxsize[port]
'   rx_head and rx_tail are values in the range 0=< ... < RX_BUFSIZE

PUB Rxcheck(port) : rxbyte
'' Check if byte received (never waits)
'' returns -1 if no byte received, $00..$FF if byte
'' (TTA) simplified references
  if port > 3
    abort
  rxbyte--
  if rx_tail[port] <> rx_head[port]
    rxbyte := rxchar[port] ^ byte[rxbuff_ptr[port] + rx_tail[port]]
    rx_tail[port] := (rx_tail[port] + 1) // rxsize[port]

PUB Rxtime(port,ms) : rxbyte | t
'' Wait ms milliseconds for a byte to be received
'' returns -1 if no byte received, $00..$FF if byte
  t := cnt
  repeat until (rxbyte := rxcheck(port)) => 0 or (cnt - t) / (clkfreq / 1000) > ms

PUB Rx(port) : rxbyte
'' Receive byte (may wait for byte)
'' returns $00..$FF
  repeat while (rxbyte := Rxcheck(port)) < 0

{PUB Txflush(port)

  repeat until (long[@tx_tail][port] == long[@tx_head][port])
}
PUB Str(port, stringptr)
'' Send zstring
  Strn(port, stringptr, strsize(stringptr))

PUB Strs(port, stringptr)

  DebugCog
  Str(port, stringptr)
  
PUB Stre(port, stringptr)

  Str(port, stringptr)
  E
  
PUB Strse(port, stringptr)

  Strs(port, stringptr)
  E

PUB Strn(port, stringptr, nchar)
'' Send counted string
  repeat nchar
    Tx(port, byte[stringptr++])

PUB Dece(port, value) 

  Dec(port, value) 
  E
  
PUB Dec(port, value) | fnumbuf[4]  
'' Print a decimal number

  result := Format.Dec(@fnumbuf, value)
  byte[result] := 0 ' is this needed?
  
  Str(port, @fnumbuf) 

PUB Fdec(port, value, len, dp) | fnumbuf[4]
'' Formated decimal output.

  result := Format.Fdec(@fnumbuf, value, len, dp)
  byte[result] := 0 ' is this needed?
  
  Str(port, @fnumbuf) 
  
PUB Bin(port, value, digits) | fnumbuf[9]  
'' Print a binary number

  result := Format.Bin(@fnumbuf, value, digits)
  byte[result] := 0 ' is this needed?
  
  Str(port, @fnumbuf) 

PUB Hex(port, value, digits)
'' Print a hexadecimal number

  value <<= (8 - digits) << 2
  repeat digits
    Tx(port, lookupz((value <-= 4) & $F : "0".."9", "A".."F"))
