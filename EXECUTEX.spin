DAT programName         byte "EXECUTEX", 0
CON
{  Design Execute
  This sub program reads the design file from the SD card and executes the instructions.

  ******* Private Notes *******
 
  Change name from "DESIGNIN" to "EXECUTE_."
 
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
  'long configPtr', filePosition[4]
  long globalMultiplier, fileNamePtr
  long fileIdNumber[Header#MAX_DATA_FILES]
  long dataFileCounter, highlightedFile
  
  'byte debugLock, spiLock
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
oledStackPtr            long 0 ' used to test how much stack space is actually used
pasmBuffer              long 0[Header#MAX_PASM_IMAGE]
 
OBJ

  Header : "HeaderCnc"
  'Pst : "Parallax Serial TerminalDat"
  Com : "Serial4PortSd"
  Format : "StrFmt"
  'Sd[1]: "SdSmall" 
  Cnc : "CncCommonMethodsX1"
  Motor : "MotorControlSd"
   
PUB Setup'(parameter0, parameter1) 

  'configPtr := Header.GetConfigName
  'fileNamePtr := Header.GetFileName
  'configNamePtr := Header.GetFileName(Header#CONFIG_FILE)
  fileNamePtr := Header.GetFileName(Header#CNC_DATA_FILE)
  
  'Pst.Start(115_200)
  'cognew(OledDemo, @stack)
  'debugLock := locknew
  'spiLock := locknew
  'Cnc.SetDebugLock(debugLock)

  oledStackPtr := Cnc.Start

  Cnc.OpenFileToRead(0, Header.GetFileName(Header#MOTOR_FILE), -1)
  Cnc.ReadData(0, @pasmBuffer, Header#MOTOR_PASM_IMAGE * 4)
  Cnc.CloseFile(0)
  Motor.Start(Cnc.Get165Address, @pasmBuffer)
  
  Cnc.OpenFileToRead(0, Header.GetFileName(Header#SERIAL_FILE), -1)
  Cnc.ReadData(0, @pasmBuffer, Header#SERIAL_PASM_IMAGE * 4)
  Cnc.CloseFile(0)
  Com.Init(@pasmBuffer, @pasmBuffer)
  Com.AddPort(0, 31, 30, -1, -1, Com#DEFAULTTHRESHOLD, 0, 115_200, Header#RX_BUFFER, Header#TX_BUFFER)
  Com.Start        

  
  repeat
    result := Com.RxHowFull(0) 'Pst.RxCount
    Com.Str(0, string(11, 13, "Press any key to continue starting program."))
    waitcnt(clkfreq / 2 + cnt)
  until result
  
  Com.RxFlush(0)

  longfill(@pasmBuffer + Header#TOTAL_SERIAL_BUFFERS, Header#STACK_CHECK_LONG, {
  } Header#MONITOR_OLED_STACK_SIZE)
  
  Cnc.LauchOledMonitor(@pasmBuffer + Header#TOTAL_SERIAL_BUFFERS, {
  } @pasmBuffer + Header#TOTAL_SERIAL_BUFFERS + (4 * Header#MONITOR_OLED_STACK_SIZE))

  
  'TestMath
  
  'cncCog := Cnc.Start'(spiLock)
  
  adcPtr := Cnc.GetAdcPtr
  buttonMask := 1 << Header#JOYSTICK_BUTTON_165
  
  Com.Str(0, string(11, 13, "Helper object started."))
 
  waitcnt(clkfreq * 2 + cnt)

  'Cnc.PressToContinue
  
  'AdcJoystickLoop


  'repeat
  
  'TempLoop

  'repeat
  
  ''OpenConfig
  repeat result from 0 to 2
    Cnc.ResetDrv8711(result)
    Com.Str(0, string(11, 13, "Reset axis #"))
    Com.Dec(0, result)   
    Com.Tx(0, ".")

    Com.Str(0, string(11, 13, "Reading registers prior to setup."))
    Cnc.ShowRegisters(result)
    
    Cnc.SetupDvr8711(result, Header#DEFAULT_DRIVE_DRV8711, Header#DEFAULT_MICROSTEP_CODE_DRV8711, {
    } Header#DEFAULT_DECAY_MODE_DRV8711, Header#DEFAULT_GATE_SPEED_DRV8711, {
    } Header#DEFAULT_GATE_DRIVE_DRV8711, Header#DEFAULT_DEADTIME_DRV8711)
    Com.Str(0, string(11, 13, "Setup finished axis #"))
    Com.Dec(0, result)   
    Com.Tx(0, ".")
    'Cnc.PressToContinue
    Com.Str(0, string(11, 13, "Reading registers."))
    Cnc.ShowRegisters(result)

   
  'Cnc.ReadData(0, @pasmBuffer, 454 * 4)
  
  'Motor.Start(Cnc.Get165Address)
  
  'repeat
  result := 0
 { repeat result from 0 to 2
    Cnc.ResetDrv8711(result)
    Com.Str(0, string(11, 13, "Reset axis #"))
    Com.Dec(0, result)   
    Com.Tx(0, ".")

    Com.Str(0, string(11, 13, "Reading registers prior to setup."))
    Cnc.ShowRegisters(result)
    
    Cnc.SetupDvr8711(result, Header#DEFAULT_DRIVE_DRV8711, Header#DEFAULT_MICROSTEP_CODE_DRV8711, {
    } Header#DEFAULT_DECAY_MODE_DRV8711, Header#DEFAULT_GATE_SPEED_DRV8711, {
    } Header#DEFAULT_GATE_DRIVE_DRV8711, Header#DEFAULT_DEADTIME_DRV8711)
    Com.Str(0, string(11, 13, "Setup finished axis #"))
    Com.Dec(0, result)   
    Com.Tx(0, ".")
    Cnc.PressToContinue
    Com.Str(0, string(11, 13, "Reading registers."))
    Cnc.ShowRegisters(result)
    Cnc.PressToContinue    }

  'repeat  
  MainLoop
{
PUB AdcJoystickLoop | localIndex, buttonValue, previousButton, {
} invertPos[2], invertSize, center[3], deadBand, posSlope[2], sizeSlope, previousJoy[3], {
} temp, maxPos[2]
  L
  Com.Str(0, string(11, 13, "AdcJoystickLoop Method"))
  C
 
  previousButton := -1

  oledPtr[3] := 0 '$80_00_00_00
  oledPtr[4] := Cnc.GetAdcPtr

  oledPtr[5] := oledPtr[4] + 4
  oledPtr[6] := oledPtr[4] + 8
  oledPtr[0] := oledPtr[4] + 12
  oledPtr[1] := oledPtr[4] + 16
  oledPtr[2] := oledPtr[4] + 20
  oledPtr[7] := @timer

  timer := 9999
  Cnc.SetOled(Header#AXES_READOUT_OLED, @joystickLabels, @oledPtr, 8)

  Cnc.SetAdcChannels(0, 6)

  maxPos[0] := Header#MAX_OLED_X
  maxPos[1] := Header#MAX_OLED_Y
  deadBand := 4095 / 20
  {center[0] := long[oledPtr[0]]
  center[1] := long[oledPtr[1]]
  center[2] := long[oledPtr[2]]}
  longfill(@center, 4095 / 2, 3)
  'invertSize := 8
  invertSize := Header#MIN_OLED_INVERTED_SIZE_Y
  invertPos[0] := (128 - invertSize) / 2
  invertPos[2] := (96 - invertSize) / 2
  posSlope[0] := (center - deadBand) / 10
  posSlope[1] := (center - deadBand) / -10
  sizeSlope := posSlope / 2
  longfill(@previousJoy, 4095 / 2, 3)
  
  L
  Pst.Clear
  'Pst.RxFlush
  C
  repeat
    Cnc.ReadAdc

    L
    Com.Tx(0, 11)
    Com.Tx(0, 13)
    Pst.PositionY(0)
    Com.Dec(0, cogid)
    Com.Tx(0, ":")
    Com.Tx(0, 32)
    temp := long[oledPtr[2]] - center[2]
    if temp < -deadBand
      temp += deadBand
      temp -= sizeSlope - 1
    elseif temp > deadBand
      temp -= deadBand
      temp += sizeSlope - 1
    else
      temp := 0
    Com.Str(0, string("temp was = "))
    Com.Dec(0, temp)
    Com.Str(0, string(", sloped temp ="))
   
    temp /= sizeSlope
    
    Com.Dec(0, temp)
    Com.Str(0, string(", invertSize was ="))
    Com.Dec(0, invertSize)  
    invertSize := Header#MIN_OLED_INVERTED_SIZE_Y #> invertSize + temp <# 96
    Com.Str(0, string(", invertSize is ="))
    Com.Dec(0, invertSize)
    
    repeat localIndex from 0 to 1 
      temp := long[oledPtr[localIndex]] - center[localIndex]
      Com.Str(0, string(11, 13, "temp["))
      Com.Dec(0, localIndex)
      Com.Str(0, string("] was = "))
      Com.Dec(0, temp)
      Com.Str(0, string(", adjusted for deadband = "))
      if temp < -deadBand
        temp += deadBand
        temp -= posSlope - 1
      elseif temp > deadBand
        temp -= deadBand
        temp += posSlope - 1
      else
        temp := 0
      Com.Dec(0, temp)    
      temp /= posSlope[localIndex]
      Com.Str(0, string(", sloped temp ="))
      Com.Dec(0, temp)    
      Com.Str(0, string(11, 13, "invertPos["))
      Com.Dec(0, localIndex)
      Com.Str(0, string("] was = "))
      Com.Dec(0, invertPos[localIndex])
      Com.Str(0, string(", is = "))
      invertPos[localIndex] := 0 #> invertPos[localIndex] + temp <# {
      } (maxPos[localIndex] - (invertSize / 2))
      Com.Dec(0, invertPos[localIndex])
      
      
    temp := Cnc.SetInvert(invertPos[0], invertPos[1], invertPos[0] + invertSize, invertPos[1] + invertSize)
    
    Com.Str(0, string(11, 13, "SetInvert("))
    Com.Dec(0, invertPos[0])
    Com.Str(0, string(", "))
    Com.Dec(0, invertPos[1])
    Com.Str(0, string(", "))
    Com.Dec(0, invertPos[0] + invertSize)
    Com.Str(0, string(", "))
    Com.Dec(0, invertPos[1] + invertSize)
    Com.Tx(0, ")")
    buttonValue := Cnc.Get165Value & buttonMask 
    Com.Tx(0, 11)
    Com.Tx(0, 13)
    Cnc.ReadableBin(buttonValue, 32)
    if buttonValue <> previousButton
      previousButton := buttonValue
      if buttonValue
        buttonLabel[8] := "f"
        buttonLabel[9] := "f"
      else
        buttonLabel[8] := "n"
        buttonLabel[9] := " "
    Com.Tx(0, 11)
    Com.Tx(0, 13)
    'C
    timer--
    'DHome
    'Com.Tx(0, 1)
    repeat localIndex from 0 to 7
      Com.Str(0, Header.FindString(@adcLabels, localIndex))
      if oledPtr[localIndex] '<> $80_00_00_00
        Com.Dec(0, long[oledPtr[localIndex]])
      {Com.Tx(0, ",")
      Com.Tx(0, " ")
      Com.Dec(0, long[oledPtr[localIndex] + 32])  }
      Com.Tx(0, 11)
      Com.Tx(0, 13)  
    C
    waitcnt(clkfreq / 10 + cnt)
    'result := Pst.RxCount
    
  'until result
    result := Cnc.Get165Value & buttonMask    
    
  while result

  L
  Com.Str(0, string(11, 13, "End of AdcJoystickLoop Method"))
  C
  
  Cnc.InvertOff
  waitcnt(clkfreq / 10 + cnt)
  
  Cnc.SetOled(Header#DEMO_OLED, @xyzLabels, @oledPtr, 4) 
  waitcnt(clkfreq * 2 + cnt)
    }
PUB MainLoop

  repeat
    'if homedFlag <> Header#HOMED_POSITION
      'Com.Str(0, string(11, 13, "Unexpected executeState =")) 
    case executeState
      INIT_EXECUTE:
        \MainMenu
      SELECT_TO_EXECUTE:
        \ScanFiles
        Com.Str(0, string(11, 13, "Back in MainLoop before SelectToExecute call"))
        Cnc.PressToContinue
        \SelectToExecute(@fileIdNumber, dataFileCounter)
        Com.Str(0, string(11, 13, "Back in MainLoop after SelectToExecute call"))
        Cnc.PressToContinue
      ACTIVE_EXECUTE:
        \ActiveExecute
      RETURN_FROM_EXECUTE:
        ReturnToTop
  
      other:
        Com.Str(0, string(11, 13, "Unexpected executeState ="))               
        Com.Dec(0, executeState)
        Cnc.PressToContinueOrClose(-1)
        Com.Str(0, string(11, 13, "End of program."))               
        repeat
     
PUB ReturnToTop

  programState := Header#TRANSITIONING_PROGRAM
  previousProgram := Header#DESIGN_READ_MAIN
  'Cnc.OpenOutputFileW(0, configPtr, -1)
  Cnc.OpenOutputFileW(0, Header.GetFileName(Header#CONFIG_FILE), -1)

  Cnc.WriteData(0, @programState, Header#CONFIG_SIZE)
  'MountSd(0)
  {Cnc.BootPartition(0, fileNamePtr)

  Cnc.PressToContinueOrClose(-1)
  Com.Str(0, string(11, 13, 7, "Something is wrong.")) }              
  Com.Str(0, string(11, 13, 7, "Preparing to reboot."))               
  waitcnt(clkfreq * 3 + cnt)
  reboot
  
{PUB InitState

  repeat
    Com.Tx(0, 1)
    Com.Str(0, string(11, 13, "Machine needs to be homed."))
    Com.Str(0, string(11, 13, "Do homing stuff here."))
    Com.Str(0, string(11, 13, "Wait until limit switches are installed."))
    Com.Str(0, string(11, 13, "Changing to ", QUOTE, "HOMED_STATE", QUOTE, "."))
    Com.Tx(0, 11)
    Com.Tx(0, 13)
    Pst.ClearBelow
    waitcnt(clkfreq * 2 + cnt)
    machineState := Header#HOMED_STATE
  while machineState == Header#INIT_STATE
        }
PUB MainMenu

  longfill(@oledPtr, 0, oledMenuLimit)
  Cnc.SetOled(Header#AXES_READOUT_OLED, @oledMenu, @oledPtr, oledMenuLimit)
  highlightedLine := oledMenuHighlightRange[0]
  Cnc.SetAdcChannels(Header#JOY_Y_ADC, Header#JOY_Z_ADC)
  Com.Tx(0, 11)
  Com.Tx(0, 13)
  Com.Tx(0, 12)
  'Pst.ClearBelow
    
  repeat
    Com.Tx(0, 1)

    Com.Str(0, string(11, 13, "Machine waiting for input."))
    Com.Str(0, string(11, 13, "Press ", QUOTE, "s", QUOTE, " to Select design file to execute."))
    
    Com.Str(0, string(11, 13, "Press ", QUOTE, "r", QUOTE, " to Return to top menu.")) 
    Com.Tx(0, 11)
    Com.Tx(0, 13)
    'Pst.ClearBelow
    result := Com.RxHowFull(0) 'Pst.RxCount
  
    CheckMenu(result)  
  while machineState == Header#INIT_STATE

PUB CheckMenu(tempValue) 

  result := 1
  
  if tempValue
    tempValue := Com.Rx(0) 'Pst.CharIn
    result := 0
  else
    tempValue := highlightedLine
    result := Cnc.Get165Value & buttonMask
    Com.Str(0, string(11, 13, "highlightedLine ="))               
    Com.Dec(0, highlightedLine)
    Com.Tx(0, 11)
    Com.Tx(0, 13)
    Cnc.ReadableBin(result, 32)
    
  ifnot result
    Cnc.InvertOff
    case tempValue
      1, "s", "S": 
        executeState := SELECT_TO_EXECUTE
      '2, "o", "O":
      '  executeState := ACTIVE_EXECUTE
      2, "r", "R":
        executeState := RETURN_FROM_EXECUTE
      other:
        executeState := INIT_EXECUTE
        Cnc.SetOled(Header#AXES_READOUT_OLED, @oledMenu, @oledPtr, oledMenuLimit)
    
    abort

  Cnc.ReadAdc
  result := GetJoystick(Header#JOY_Y_ADC, -Header#DEFAULT_DEADBAND * 2)
  Com.Str(0, string(11, 13, "result Y ="))               
  Com.Dec(0, result)
  result += GetJoystick(Header#JOY_Z_ADC, Header#DEFAULT_DEADBAND * 2)
  Com.Str(0, string(11, 13, "result Y + Z ="))               
  Com.Dec(0, result)
  if result > 0 and highlightedLine < oledMenuHighlightRange[1]
    highlightedLine++
  elseif result < 0 and highlightedLine > oledMenuHighlightRange[0]
    highlightedLine--
  Com.Str(0, string(11, 13, "highlightedLine ="))               
  Com.Dec(0, highlightedLine)
  Cnc.SetInvert(0, highlightedLine * 8, Header#MAX_OLED_X, (highlightedLine * 8) + 7)

PUB GetJoystick(localAxis, scaler)

  result := long[adcPtr][localAxis] - Header#DEFAULT_CENTER
  {Com.Str(0, string(11, 13, "temp["))
  Com.Dec(0, localIndex)
  Com.Str(0, string("] was = "))
  Com.Dec(0, temp)
  Com.Str(0, string(", adjusted for deadband = "))  }

  Com.Str(0, string(11, 13, "GJ("))
  Com.Dec(0, localAxis)
  Com.Str(0, string(", "))
  Com.Dec(0, scaler)
  Com.Str(0, string(") "))  
  if result < -Header#DEFAULT_DEADBAND
    Com.Str(0, string("negative joystick = "))
    result += Header#DEFAULT_DEADBAND
    Com.Dec(0, result)
    'temp -= posSlope - 1
  elseif result > Header#DEFAULT_DEADBAND
    Com.Str(0, string("positive joystick = "))
    result -= Header#DEFAULT_DEADBAND
    Com.Dec(0, result)
    'temp += posSlope - 1
  else
    result := 0
  'Com.Dec(0, temp)    
  result /= scaler
  {Com.Str(0, string(", sloped temp ="))
  Com.Dec(0, temp)    
  Com.Str(0, string(11, 13, "invertPos["))
  Com.Dec(0, localIndex)
  Com.Str(0, string("] was = "))
  Com.Dec(0, invertPos[localIndex])
  Com.Str(0, string(", is = "))  
  invertPos[localIndex] := 0 #> invertPos[localIndex] + temp <# {
  } (maxPos[localIndex] - (invertSize / 2))
  Com.Dec(0, invertPos[localIndex])}
      
{PUB MenuInput | localState

  localState := machineState
  result := Pst.CharIn
  case result
    '"p", "P":
    '  result := Header#ENTER_PROGRAM_STATE
    "b", "B":
      {Cnc.OpenOutputFileW(0, Header.GetBitmapName(Header#BEANIE_SMALL_BITMAP), -1)
      Sd[0].writeData(@propBeanie, (Header.GetBitmapWidth(Header#BEANIE_SMALL_BITMAP) * {
      } Header.GetBitmapHeight(Header#BEANIE_SMALL_BITMAP)) / 8)  
      result := Header#HOMED_STATE  }
    "o", "O":
      result := Header#INTERPRETE_PROGRAM_STATE
    "d", "D":
      result := Header#DISPLAY_PROGRAM_SINGLE_STATE
    "l", "L":
      result := Header#DISPLAY_PROGRAM_LINE_STATE
    "e", "E":
      result := Header#RUN_PROGRAM_STATE
    "k", "K":
      result := Header#MANUAL_KEYPAD_STATE
    "n", "N":
      result := Header#MANUAL_NUNCHUCK_STATE
    "h", "H":
      result := Header#INIT_STATE
    other:
      result := Header#HOMED_STATE
    Cnc.InvertOff
    abort
         }

PUB ScanFiles | size, characterIndex

  dataFileCounter := 0

  Com.Str(0, string(11, 13, "SelectToExecute Method"))
  repeat
    characterIndex := 0
    result := Cnc.ListEntries(0, "N")
    ifnot result
      'executeState := INIT_EXECUTE
      return
    Com.Str(0, string(11, 13, "result = "))
    Com.Dec(0, result)
    size := strsize(result) <# MAX_LIST_SIZE
    Com.Str(0, string(11, 13, "size = "))
    Com.Dec(0, size)
    Com.Str(0, string(11, 13, "string = "))
    repeat size
      Cnc.SafeTx(byte[result][characterIndex++])
    'Cnc.PressToContinue
    dataFileCounter += CheckForMatch(fileNamePtr, result, Header#PRE_ID_CHARACTERS, {
    } Header#ID_CHARACTERS, Header#POST_ID_CHARACTERS, @fileIdNumber + (4 * dataFileCounter))
    dataFileCounter <#= Header#MAX_DATA_FILES - 1
  while executeState == SELECT_TO_EXECUTE and dataFileCounter < Header#MAX_DATA_FILES
  
PUB CheckForMatch(localTargetPtr, localNewPtr, preSize, idSize, postSize, idPointer) | multiplier, fileId

  repeat preSize
    if byte[localTargetPtr++] <> byte[localNewPtr++]
      return 0
      
  localTargetPtr += idSize

  multiplier := 1
  fileId := 0
  repeat idSize
    multiplier *= 10

  repeat idSize
    multiplier /= 10
    fileId += (0 #> byte[localNewPtr++] - "0" <# 9) * multiplier
    
  repeat postSize
    if byte[localTargetPtr++] <> byte[localNewPtr++]
      return 0
    
  long[idPointer] := fileId

  Com.Str(0, string(11, 13, "Match Found"))
  Com.Str(0, string(11, 13, "long["))
  Com.Dec(0, idPointer)
  Com.Str(0, string("] = "))
  Com.Dec(0, fileId)
  'Cnc.PressToContinue           
  result := 1
  
PUB SelectToExecute(idPointer, size) : doneFlag | localPtr[8], {
} filesToDisplay, idPtrOffset, maxOffset, localIdex', terminalChange

  oledPtr[0] := 0
  filesToDisplay := size <# 7
  idPtrOffset := 0
  maxOffset :=  0 #> (size - filesToDisplay)
  Cnc.SetOled(Header#AXES_READOUT_OLED, @selectFileTxt, @oledPtr, filesToDisplay + 1)
  highlightedLine := 1
  Cnc.SetAdcChannels(Header#JOY_Y_ADC, Header#JOY_Z_ADC)
  Com.Tx(0, 11)
  Com.Tx(0, 13)
  Com.Tx(0, 12)
  Com.Tx(0, 0)
  'Pst.ClearBelow
  'Pst.Clear
  
  filesToDisplay := size <# 7
  repeat localIdex from 1 to 7
    oledPtr[localIdex] := idPointer + (4 * (localIdex - 1))
      
  repeat 'until doneFlag
    result := CheckTerminalInput(Com.RxHowFull(0), filesToDisplay, idPtrOffset)
    Com.Tx(0, 1)
    Cnc.ReadAdc
    result := GetJoystick(Header#JOY_Y_ADC, -Header#DEFAULT_DEADBAND * 4)
    Com.Str(0, string(11, 13, "result Y ="))               
    Com.Dec(0, result)
    result += GetJoystick(Header#JOY_Z_ADC, Header#DEFAULT_DEADBAND * 4)
    Com.Str(0, string(11, 13, "result Y + Z ="))               
    Com.Dec(0, result)
    if result > 0 and highlightedLine < filesToDisplay
      highlightedLine++
    elseif result > 0 and highlightedLine == 7 and idPtrOffset < maxOffset
      idPtrOffset++
      repeat localIdex from 1 to 7
        oledPtr[localIdex] := idPointer + (4 * idPtrOffset) + (4 * localIdex)
      Cnc.SetOled(Header#AXES_READOUT_OLED, @selectFileTxt, @oledPtr, filesToDisplay + 1)
    elseif result < 0 and highlightedLine > 1
      highlightedLine--
    elseif result < 0 and highlightedLine == 1 and idPtrOffset > 0
      idPtrOffset--
      repeat localIdex from 1 to 7
        oledPtr[localIdex] := idPointer + (4 * idPtrOffset) + (4 * localIdex)
      Cnc.SetOled(Header#AXES_READOUT_OLED, @selectFileTxt, @oledPtr, filesToDisplay + 1)
     
    highlightedFile := highlightedLine + idPtrOffset 
    Com.Str(0, string(11, 13, "idPtrOffset ="))               
    Com.Dec(0, idPtrOffset)
    Com.Str(0, string(11, 13, "highlightedLine ="))               
    Com.Dec(0, highlightedLine)
    Com.Str(0, string(11, 13, "highlightedFile ="))               
    Com.Dec(0, highlightedFile)
    Com.Tx(0, 11)
    Com.Tx(0, 13)
    Cnc.ReadableBin(Cnc.Get165Value, 32)
    Cnc.SetInvert(0, highlightedLine * 8, Header#MAX_OLED_X, (highlightedLine * 8) + 7)
    'Cnc.PressToContinue
    
PUB CheckTerminalInput(tempValue, filesToDisplay, idPtrOffset) | localIdex

  result := 1
  
  if tempValue
    tempValue := Com.Rx(0)
    
    case tempValue
      "+", "-":
        result := 0
      13:
        tempValue := highlightedLine
        result := 0
      "0".."7":
        tempValue -= "0"
        result := 0
  else
    tempValue := highlightedLine
    result := Cnc.Get165Value & buttonMask

  Com.Tx(0, 11)
  Com.Tx(0, 13)
  Com.Str(0, @selectFileTxt)
  repeat localIdex from 1 to filesToDisplay
    Com.Tx(0, 11)
    Com.Tx(0, 13)
    Com.Dec(0, localIdex)
    Com.Str(0, string(")"))
    Com.Str(0, @cncNumber)           
    Com.Dec(0, long[oledPtr[localIdex]])
    
  ifnot result
    'Cnc.InvertOff
    case tempValue
      1..7:
        activeFile := fileIdNumber[tempValue + idPtrOffset - 1]
        Com.Str(0, string(11, 13, "activeFile = fileIdNumber["))               
        Com.Dec(0, tempValue)
        Com.Str(0, string(" + "))               
        Com.Dec(0, idPtrOffset)
        Com.Str(0, string(" - 1] = "))           
        Com.Dec(0, activeFile)
        executeState := ACTIVE_EXECUTE
        Cnc.PressToContinue
        Cnc.InvertOff
        abort
      {13:
        activeFile := fileIdNumber[tempValue + idPtrOffset - 1]
        Com.Str(0, string(11, 13, "activeFile = fileIdNumber["))               
        Com.Dec(0, tempValue)
        Com.Str(0, string(" + "))               
        Com.Dec(0, idPtrOffset)
        Com.Str(0, string(" - 1] = "))           
        Com.Dec(0, activeFile)
        executeState := ACTIVE_EXECUTE
        Cnc.PressToContinue
        Cnc.InvertOff
        abort   }
      "+":
        result := 1
        Com.Str(0, string(11, 13, "+ result := 1"))
        Cnc.PressToContinue
        return
      "-":
        result := -1
        Com.Str(0, string(11, 13, "- result := -1"))
        Cnc.PressToContinue
        return
      other:
        executeState := INIT_EXECUTE
        Cnc.SetOled(Header#AXES_READOUT_OLED, @oledMenu, @oledPtr, oledMenuLimit)
        return 0
   

  result := 0
  
CON

  ' expectedChar enumeration
  #0, CODE_TYPE_CHAR, CODE_VALUE_CHAR, PARAMETER_VALUE_CHAR
      STRING_CHAR, COMMENT_CHAR
  MAX_COMMENT_CHARACTERS = 30
  MAX_LIST_SIZE = 30
      
PUB ActiveExecute

  Com.Str(0, string(11, 13, "ActiveExecute Method"))
  Com.Str(0, string(11, 13, "activeFile = "))
  Com.Dec(0, activeFile)
  Com.Str(0, string(11, 13, "Calling InterpreteDesign Method"))
  InterpreteDesign(activeFile)
  repeat
  executeState := INIT_EXECUTE
  abort

PUB InterpreteDesign(fileIndex) | delimiterCount, parameterIndex, scratchValue, {
} previousExpectedChar, localStr, activeRow

  endFlag := 0
  delimiterCount := 0
  expectedChar := CODE_TYPE_CHAR
  'longfill(@filePosition, 0, 4)
  parameterIndex := 0
  scratchValue := 0
  activeRow := 0
  {Com.Str(0, string(11, 13, "accelerationTable[0] = "))
  Com.Dec(0, accelerationTable[0])
  PressToContinueOrClose("c")   }

  '**** should this be moved?
  'ifnot arraySize[1] ' since accelerationTable is also used as a SD buffer
    'arraySize[1] := FillAccelTable(@accelerationTable, Header#MAX_ACCEL_TABLE, Header#MIN_SPEED, Header#MAX_SPEED, Header#ACCELERATION, 1, 1, 1)

  codeType := 0
  'longfill(@longCount, 0, Header#NUMBER_OF_AXES)
  
  Com.Str(0, string(11, 13, "InterpreteDesign("))
  Com.Dec(0, fileIndex)
  Com.Tx(0, ")")      '0123456789012345
  localStr := string(" Opening Design")
  'Com.Tx(0, 11)
  ''Com.Tx(0, 13)
  'Com.Str(0, localStr)
  'Com.Str(0, string(11, 13, "Opening Design File"))
  
  Cnc.OpenFileToRead(0, fileNamePtr, fileIndex)

  Com.Str(0, string(11, 13, "Design file has been opened."))
  'Write4x16String(localStr, 15, activeRow++, 0)
  Cnc.ScrollString(localStr, 1)
  Cnc.ScrollString(fileNamePtr, 1)
  'Cnc.OpenOutputFilesW(fileIndex)
  
  'Com.Str(0, string(11, 13, "All output files have been opened."))
  '**** Read file once to get extremes.
  repeat
    result := Cnc.ReadByte(0)
    'filePosition[Header#DESIGN_AXIS]++
    Com.Str(0, string(11, 13, "Character = ", QUOTE))
    Cnc.SafeTx(result)
    Com.Tx(0, QUOTE)
    
    if delimiterCount and result == " " and expectedChar <> COMMENT_CHAR
      delimiterCount := 0
      Com.Str(0, string(11, 13, "Skipping first space after delimiter."))
      'Cnc.PressToContinue
      next ' skip first space after a delimter
    elseif delimiterCount
      case result
        delimiter[0], delimiter[1], delimiter[2], delimiter[3], delimiter[4]:
          delimiterCount++
          Com.Str(0, string(" -- Delimiter --"))
          Com.Str(0, string(11, 13, "delimiterCount = "))
          Com.Dec(0, delimiterCount)
          result := Cnc.PressToContinueOrClose("c")
          if result
            return
          next ' skip extra delimters
    Com.Str(0, string(11, 13, "expectedChar = ")) 
    Com.Str(0, Header.FindString(@expectedCharText, expectedChar))
    
    if result == Header#COMMENT_START_CHAR
      Com.Str(0, string(11, 13, "Beginning of Comment"))
      previousExpectedChar := expectedChar
      expectedChar := COMMENT_CHAR
      commentIndex := 0
      bytefill(@commentFromFile, 0, MAX_COMMENT_CHARACTERS)
      next      
    case expectedChar
      CODE_TYPE_CHAR:
        case result
          Header#PROGRAM_NAME_CHAR: '"O"
            GetName(Header#DESIGN_AXIS, @sdProgramName, Header#MAX_NAME_SIZE)
          "G", "M", "D":
            Com.Str(0, string(11, 13, "Code = ", QUOTE))
            Com.Tx(0, result)
            Com.Tx(0, QUOTE)
            codeType := result
            expectedChar := CODE_VALUE_CHAR
            scratchValue := 0
      CODE_VALUE_CHAR:
        case result
          "0".."9":
            scratchValue *= 10
            scratchValue += result - "0"
            Com.Str(0, string(11, 13, "scratchValue = "))
            Com.Dec(0, scratchValue)
          delimiter[0], delimiter[1], delimiter[2], delimiter[3], delimiter[4]:
            codeValue := scratchValue
            scratchValue := 0
            Com.Str(0, string(11, 13, "codeValue = "))
            Com.Dec(0, codeValue)
            CodeAction(Header#DESIGN_AXIS, codeType, codeValue)
            delimiterCount := 1
            expectedChar := CODE_TYPE_CHAR
      PARAMETER_VALUE_CHAR:
      COMMENT_CHAR:
        case result                                  
          Header#COMMENT_END_CHAR:
            expectedChar := previousExpectedChar 'CODE_TYPE_CHAR
            newCommentFlag := 1
            Com.Str(0, string(11, 13, "comment = ", QUOTE))
            Com.Str(0, @commentFromFile)
            Com.Tx(0, QUOTE)
            Cnc.ScrollString(@commentFromFile, 1)
          other:
            if commentIndex < MAX_COMMENT_CHARACTERS 
              commentFromFile[commentIndex++] := result
              
    case result  ' reset delimiterCount if no delimiter received
      delimiter[0], delimiter[1], delimiter[2], delimiter[3], delimiter[4]:
      other:
        delimiterCount := 0     
  until endFlag 

  repeat result from 0 to 3
    if result < 3
      'Cnc.WriteLong(endDat)
      'filePosition[result] += 4
    'Sd[result].closeFile
    Com.Str(0, string(11, 13, "filePosition["))
    Com.Dec(0, result)
    Com.Str(0, string("] = "))
    'Com.Dec(0, filePosition[result])
    'UnmountSd(result)
    
  Com.Str(0, string(11, 13, "End of InterpreteDesign method."))
  Cnc.PressToContinue

PUB CodeAction(sdInstance, localType, localValue)

  Com.Str(0, string(11, 13, "CodeAction("))
  Com.Str(0, Header.FindString(@axesText, sdInstance))
  Com.Str(0, string(", "))
  Com.Tx(0, localType)
  Com.Str(0, string(", "))
  Com.Dec(0, localValue)
  Com.Tx(0, ")")
   
  case localType
    "G":
      ReadG(sdInstance, localValue)
    "M":
      ReadM(sdInstance, localValue)
    "D":
      ReadD(sdInstance, localValue)
    
PUB ReadG(sdInstance, localValue)

  Com.Str(0, string(11, 13, "ReadG("))
  Com.Str(0, Header.FindString(@axesText, sdInstance))
  Com.Str(0, string(", "))
  Com.Dec(0, localValue)
  Com.Str(0, string(" = "))
  Com.Str(0, Header.FindString(@gCodeText, localValue))
  Com.Tx(0, ")")
  
  case localValue
    Header#RAPID_POSITION_G: 'G00
      'SetZDown(0)
      GetLine(sdInstance)
    Header#LINEAR_G: 'G01
      'SetZDown(1)
      GetLine(sdInstance)
    Header#CIRCULAR_CW_G, Header#CIRCULAR_CCW_G, Header#DWELL_G:
    Header#FULL_CIRCLE_CW_G, Header#FULL_CIRCLE_CCW_G:
    Header#INCHES_G:
      units := Header#INCH_UNIT
    Header#MILLIMETERS_G:
      units := Header#MILLIMETER_UNIT
    Header#HOME_G: ' not really needed. Program will home router on start up.
    Header#SECONDARY_HOME_G: ' probably a good starting point
    Header#TOOL_RADIUS_COMP_OFF_G, Header#TOOL_RADIUS_COMP_LEFT_G, Header#TOOL_RADIUS_COMP_RIGHT_G:
    Header#TOOL_HEIGHT_COMP_NEGATIVE_G, Header#TOOL_HEIGHT_COMP_POSITIVE_G:
    Header#TOOL_HEIGHT_COMP_OFF_G:
    Header#LOCAL_SYSTEM_G, Header#MACHINE_SYSTEM_G, Header#WORK_SYSTEM_G:
    
  Com.Str(0, string(11, 13, "End of ReadG method."))

{
  ' supported G-Codes
  #0, RAPID_POSITION_G, LINEAR_G, CIRCULAR_CW_G, CIRCULAR_CCW_G, DWELL_G
  #12, FULL_CIRCLE_CW_G, FULL_CIRCLE_CCW_G
  #20, INCHES_G, MILLIMETERS_G
  #28, HOME_G
  #30, SECONDARY_HOME_G
  #40, TOOL_RADIUS_COMP_OFF_G, TOOL_RADIUS_COMP_LEFT_G, TOOL_RADIUS_COMP_RIGHT_G
  TOOL_HEIGHT_COMP_NEGATIVE_G, TOOL_HEIGHT_COMP_POSITIVE_G
  TOOL_HEIGHT_COMP_OFF_G
  #52, LOCAL_SYSTEM_G, MACHINE_SYSTEM_G, WORK_SYSTEM_G
  }
PUB SetZDown(localDownFlag)

  if localDownFlag == downFlag
    return
    
  'Sd[Header#Z_AXIS].writeLong(lineDat)
  'filePosition[Header#Z_AXIS] += 4

  if localDownFlag
    result := lowerZAmount
  else
    result := lowerZAmount * -1
  result *= microsteps
  'Sd[Header#Z_AXIS].writeLong(result)
  'filePosition[Header#Z_AXIS] += 4
 
  downFlag := localDownFlag
    
PUB GetStepsFromUnits(localUnits, localValue, localMultiplier)

  Com.Str(0, string(11, 13, "GetStepsFromUnits("))
  Com.Str(0, Header.FindString(@unitsText, localUnits))
  Com.Str(0, string(", "))
  Com.Dec(0, localValue)
  Com.Str(0, string(", "))
  Com.Dec(0, localMultiplier)
  Com.Str(0, string(") microsteps = "))
  Com.Dec(0, microsteps)
  Com.Str(0, string(", result = "))
  
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
      
  'result *= microsteps
  
  Com.Dec(0, result)
      
PRI GetLine(sdInstance) | x0, y0, stepPosition[2], longAxis, shortAxis, localBuffer[7], {
} localStr, multiplier[2], decPoints[2], original[2], size, localIndex
'' x and y are relative to current position.

  'Cnc.ScrollString(string("line")) 
  original[0] := Cnc.GetDec(0)
  multiplier[0] := Cnc.GetMultiplier
  decPoints[0] := Cnc.GetDecPoints
  x0 := GetStepsFromUnits(units, original[0], multiplier[0])
  original[1] := Cnc.GetDec(0)
  multiplier[1] := Cnc.GetMultiplier
  decPoints[1] := Cnc.GetDecPoints
  y0 := GetStepsFromUnits(units, original[1], multiplier[1])

  'filePosition[Header#X_AXIS] += 4  ' all files will have holdDat or lineDat added
  'filePosition[Header#Y_AXIS] += 4
  'filePosition[Header#Z_AXIS] += 4
    
  if x0 == 0           '1234567890123
    localStr := string("Vertical Line")
  
    'filePosition[Header#Y_AXIS] += 4
    longAxis := Header#Y_AXIS
    shortAxis := Header#X_AXIS
  elseif y0 == 0
                       '123456789012345
    localStr := string("Horizontal Line")
    
    'filePosition[Header#X_AXIS] += 4
    longAxis := Header#X_AXIS
    shortAxis := Header#Y_AXIS
  elseif ||x0 > ||y0
                       '1234567890123456
    localStr := string("Low Slope Line")
 
    'result := SlopedLine(Header#X_AXIS, Header#Y_AXIS, x0, y0)
    longAxis := Header#X_AXIS
    shortAxis := Header#Y_AXIS
  else'if x0 < y0
                       '1234567890123456
    localStr := string("High Slope Line")

    'result := SlopedLine(Header#Y_AXIS, Header#X_AXIS, y0, x0)
    longAxis := Header#Y_AXIS
    shortAxis := Header#X_AXIS
  'else
  '  result := OneSlope(x0, y0)
  'Com.Tx(0, 11)
  'Com.Tx(0, 13)
  'Com.Str(0, localStr)
  
  Cnc.ScrollString(localStr, 1)

  repeat localIndex from 0 to 1
    size := DecSize(original[localIndex])
    if original[localIndex] < 0
      size++
    if decPoints[localIndex]
      size++ 
    result := Format.Str(@localBuffer, Header.FindString(@xyzLabels, localIndex))
    result := Format.FDec(result, original[localIndex], size, decPoints[localIndex])
    result := Format.Ch(result, " ")
    result := Format.Str(result, Header.FindString(@unitsTxt, units))
    byte[result] := 0
    Cnc.ScrollString(@localBuffer, 1)
    
  repeat localIndex from 0 to 1
    result := Format.Str(@localBuffer, Header.FindString(@xyzLabels, localIndex))
    result := Format.Dec(result, x0[localIndex])
    result := Format.Ch(result, " ")
    result := Format.Str(result, Header.FindString(@unitsText, Header#STEP_UNIT))
    byte[result] := 0
    Cnc.ScrollString(@localBuffer, 1)

  
  Motor.MoveLine(longAxis, shortAxis, x0[longAxis], x0[shortAxis])
  '''Motor.MoveLine(longAxis, shortAxis, x0[longAxis], x0[shortAxis])
  
 { result := SlopedLine(longAxis, shortAxis, x0[longAxis], x0[shortAxis])
         
  Com.Str(0, string(11, 13, "Writing total delay to all files."))
  Com.Str(0, string(11, 13, "Total delay "))
  Com.Str(0, FindString(@axesText, shortAxis))
  Com.Str(0, string(" = "))
  Com.Dec(0, long[result][0])
  Com.Str(0, string(11, 13, "Total delay "))
  Com.Str(0, FindString(@axesText, longAxis))
  Com.Str(0, string(" = "))
  Com.Dec(0, long[result][1])
  Com.Str(0, string(11, 13, "Total delay "))
  Com.Str(0, FindString(@axesText, Header#Z_AXIS))
  Com.Str(0, string(" = "))
  
  
  'Sd[longAxis].writeLong(long[result][1]) ' write total time
  'Sd[shortAxis].writeLong(long[result][0])
  if long[result][0] > long[result][1]
    'Sd[Header#Z_AXIS].writeLong(long[result][0])
    Com.Dec(0, long[result][0])
  else
    'Sd[Header#Z_AXIS].writeLong(long[result][1])
    Com.Dec(0, long[result][1])
  'filePosition[Header#X_AXIS] += 4
  'filePosition[Header#Y_AXIS] += 4
  'filePosition[Header#Z_AXIS] += 4       }

PUB DecSize(value)

  repeat while value => 10
    value /= 10
    result++
  result++
     
{PRI SlopedLine(longAxis, shortAxis, longDistance, shortDistance) | accel[2], {
} decel[2], full[2], slowIndex, fastIndex, slow, fast, {
} fastestIndex, localIndex, slowFullSpeedTimeTotal, slowFullSpeedTime, {
} slowFullSpeedRemainder, extraCountsRemaining, addExtraCountInterval, {
} pauseFlag, headingInterval, localDebugFlag, lastAccelDelay[2], temp[3]

  'longfill(@totalTimeSlow, 0, 2)
  'accelPtr := @accelerationTable

  Com.Str(0, string(11, 13, "SlopedLine("))
  Com.Str(0, FindString(@axesText, longAxis))
  Com.Str(0, string(", "))
  Com.Str(0, FindString(@axesText, shortAxis))
  Com.Str(0, string(", "))
  Com.Dec(0, longDistance)
  Com.Str(0, string(", "))
  Com.Dec(0, shortDistance)
  Com.Str(0, string(") "))

  localDebugFlag := GetDebugFlag("d")
  
  ||longDistance 'longAxis
  ||shortDistance 'shortAxis
  {
  arraySize[1] := FillAccelTable(@accelerationTable, Header#MAX_ACCEL_TABLE, {
  } Header#MIN_SPEED, Header#MAX_SPEED, Header#ACCELERATION, 1, longDistance, shortDistance, localDebugFlag)
  }
  if longDistance > doubleAccel
    full[1] := longDistance - doubleAccel
    accel[1] := singleAccel
    decel[1] := singleAccel
    
    'accel[0] := DivideWithRound(singleAccel * shortDistance, longDistance)
    accel[0] := singleAccel * shortDistance / longDistance
    ' the number of steps it takes to accelerate the slow axis is computed
    ' here and also in the "FillAccelTable" method.
    ' which value to use has yet to be determined.
    
    decel[0] := accel[0]
    full[0] := shortDistance - (accel[0] + decel[0])
    
  else'if longDistance < doubleAccel
    accel[1] := longDistance / 2
    decel[1] := accel[1]
    full[1] := longDistance - (accel[1] + decel[1])
    accel[0] := shortDistance / 2
    decel[0] := accel[0]
    full[0] := shortDistance - (accel[0] + decel[0])

  repeat localIndex from 0 to 1
    Com.Str(0, string(11, 13, "accel["))
    Com.Str(0, FindString(@accelChanTextB, localIndex))
    Com.Str(0, string("] = "))
    Com.Dec(0, accel[localIndex])
    Com.Str(0, string(11, 13, "decel["))
    Com.Str(0, FindString(@accelChanTextB, localIndex))
    Com.Str(0, string("] = "))
    Com.Dec(0, decel[localIndex])
    Com.Str(0, string(11, 13, "full["))
    Com.Str(0, FindString(@accelChanTextB, localIndex))
    Com.Str(0, string("] = "))
    Com.Dec(0, full[localIndex])

  if full[0] < 0
    Com.Str(0, string(11, 13, "************ Error! full[0] < 0 ************"))
    Com.Str(0, string(11, 13, "Recommend closing files."))
  PressToContinueOrClose("c")
 
  totalTimeFast := 0
  totalTimeSlow := 0
  fastestIndex := fastIndex := 0
  headingInterval := accel[1] / 2
  pauseFlag := 1
  
  repeat accel[1]
    fast := accelerationTable[fastIndex] 'fastestIndex]
    totalTimeFast += fast
    Sd[longAxis].writeLong(fast)
    filePosition[longAxis] += 4
    
    if shortDistance == longDistance
      slow := fast
      totalTimeSlow := totalTimeFast
      Sd[shortAxis].writeLong(slow)
      filePosition[shortAxis] += 4
      pauseFlag := 0

    if localDebugFlag  
      DisplayLineStats(totalTimeFast, totalTimeSlow, {
        } slowIndex, fastIndex, fast, slow, fastestIndex, pauseFlag, headingInterval)
    fastestIndex++
    fastIndex++
  Com.Str(0, string(11, 13, "Between accel and full."))
  if localDebugFlag  
    DisplayLineHeading
  fastestIndex--
  headingInterval := full[1] / 4
  pauseFlag := 1
    
  if full[1]
    repeat full[1]
      totalTimeFast += fast ' the value of "fast" stays the same in this section
      Sd[longAxis].writeLong(fast)
      filePosition[longAxis] += 4
      
      if shortDistance == longDistance
        slow := fast
        totalTimeSlow := totalTimeFast
        Sd[shortAxis].writeLong(slow)
        filePosition[shortAxis] += 4 
        pauseFlag := 0
        
      if localDebugFlag  
        DisplayLineStats(totalTimeFast, totalTimeSlow, {
        } slowIndex, fastIndex, fast, slow, fastestIndex, pauseFlag, headingInterval)
      'fastestIndex++
      fastIndex++
      
  Com.Str(0, string(11, 13, "Between full and decel."))
  if localDebugFlag  
    DisplayLineHeading
  headingInterval := decel[1] / 2
  pauseFlag := 1
      
  repeat decel[1]
    fast := accelerationTable[fastestIndex]
    totalTimeFast += fast
    Sd[longAxis].writeLong(fast)
    filePosition[longAxis] += 4
    
    if shortDistance == longDistance
      slow := fast
      totalTimeSlow := totalTimeFast
      Sd[shortAxis].writeLong(slow)
      filePosition[shortAxis] += 4
      pauseFlag := 0
      
    if localDebugFlag  
      DisplayLineStats(totalTimeFast, totalTimeSlow, {
      } slowIndex, fastIndex, fast, slow, fastestIndex, pauseFlag, headingInterval)
    fastestIndex--
    fastIndex++

  if shortDistance == longDistance
    totalTimeSlow := totalTimeFast
    slowIndex := fastIndex
      
  elseif shortDistance

    arraySize[0] := FillAccelTable(@accelerationTable, Header#MAX_ACCEL_TABLE, {
    } Header#MIN_SPEED, Header#MAX_SPEED, Header#ACCELERATION, 0, longDistance, shortDistance, localDebugFlag)

    if longDistance > doubleAccel 
      repeat localIndex from 0 to 1
        Com.Str(0, string(11, 13, "accelerationTime["))
        Com.Str(0, FindString(@accelChanTextB, localIndex))
        Com.Str(0, string("] = "))
        Com.Dec(0, accelerationTimeSlave[localIndex])
        Com.Str(0, string(11, 13, "delayAtMaxSpeed["))
        Com.Str(0, FindString(@accelChanTextB, localIndex))
        Com.Str(0, string("] = "))
        Com.Dec(0, delayAtMaxSpeed[localIndex])
        Com.Str(0, string(11, 13, "Difference in acceleration times = "))
        Com.Dec(0, ||(accelerationTimeSlave[1] - accelerationTimeSlave[0]))
        slowFullSpeedTimeTotal := totalTimeFast - (2 * accelerationTimeSlave[0])
        ' "slowFullSpeedTimeTotal" is the difference in time between the slow and the
        ' fast axes.
        ' It would be nice to lower this difference by adjusting the middle two or
        ' three steps of the slow axis.
        
    else
      repeat localIndex from 0 to 1
       Com.Str(0, string(11, 13, "timeTilFullSpeed["))
       Com.Str(0, FindString(@accelChanTextB, localIndex))
       Com.Str(0, string("] = "))
       Com.Dec(0, timeTilFullSpeed[localIndex])
       Com.Str(0, string(11, 13, "delayAtMaxSpeed["))
       Com.Str(0, FindString(@accelChanTextB, localIndex))
       Com.Str(0, string("] = "))
       Com.Dec(0, delayAtMaxSpeed[localIndex])
       Com.Str(0, string(11, 13, "Difference in acceleration times = "))
       Com.Dec(0, ||(accelerationTimeSlave[1] - accelerationTimeSlave[0]))
       slowFullSpeedTimeTotal := totalTimeFast - (2 * timeTilFullSpeed[0])
        

    Com.Str(0, string(11, 13, "totalTimeFast = ")) '**** Check accel times.
    Com.Dec(0, totalTimeFast)
    Com.Str(0, string(11, 13, "Time at full speed on slow axis. (slowFullSpeedTimeTotal) = "))
    Com.Dec(0, slowFullSpeedTimeTotal)
    Com.Str(0, string(11, 13, "full[0] = "))
    Com.Dec(0, full[0])
    if full[0] == 0
      Com.Str(0, string(11, 13, "****** Zero full speed (slow) steps. ******"))
      accel[0]--
      decel[0]--
      extraCountsRemaining := 0
      temp[0] := accelerationTable[accel[0] - 2] - accelerationTable[accel[0] - 1]
      ' "temp[0]" is the max acceptable delay change.
      temp[1] := accelerationTable[accel[0] - 1] - accelerationTable[accel[0]]
      ' "temp[1]" should be less than "temp[0]".
      
      slowFullSpeedTimeTotal += 2 * accelerationTable[accel[0]]
      
      lastAccelDelay[0] := slowFullSpeedTimeTotal / 2
      lastAccelDelay[1] := slowFullSpeedTimeTotal - lastAccelDelay[0]
      if lastAccelDelay[0] == lastAccelDelay[1]
        Com.Str(0, string(11, 13, "Both elements of lastAccelDelay = "))
        Com.Dec(0, lastAccelDelay[0])
      else
        Com.Str(0, string(11, 13, "lastAccelDelay[0] = "))
        Com.Dec(0, lastAccelDelay[0])
        Com.Str(0, string(11, 13, "lastAccelDelay[1] = "))
        Com.Dec(0, lastAccelDelay[1])
      Com.Str(0, string(11, 13, "accelerationTable["))
      Com.Dec(0, accel[0])  
      Com.Str(0, string("] = "))
      Com.Dec(0, accelerationTable[accel[0]])
      temp[2] := lastAccelDelay[0] - accelerationTable[accel[0] - 1]
      if ||temp[2] > temp[0]
        Com.Str(0, string(11, 13, "****** Possible Problem ******"))
        Com.Str(0, string(11, 13, "||temp[2] > temp[0]"))
        Com.Str(0, string(11, 13, "old lastAccelDelay[0] = "))
        Com.Dec(0, lastAccelDelay[0])
        Com.Str(0, string(11, 13, "temp[0] = "))
        Com.Dec(0, temp[0])
        Com.Str(0, string(11, 13, "temp[1] = "))
        Com.Dec(0, temp[1])
        Com.Str(0, string(11, 13, "temp[2] = "))
        Com.Dec(0, temp[2])
        if temp[2] < 0 'temp[0]
          lastAccelDelay[0] := accelerationTable[accel[0] - 1] - temp[0]
        else
          lastAccelDelay[0] := accelerationTable[accel[0] - 1] + temp[0]
        lastAccelDelay[1] := lastAccelDelay[0]
        Com.Str(0, string(11, 13, "adjusted lastAccelDelay[0] = "))
        Com.Dec(0, lastAccelDelay[0])
      PressToContinueOrClose("c")
    elseif full[0] == 1
      accel[0]--
      decel[0]--
      extraCountsRemaining := 0
      Com.Str(0, string(11, 13, "****** Only one full speed (slow) step. ******"))
      temp[0] := accelerationTable[accel[0] - 1] - accelerationTable[accel[0]]
      temp[1] := ||(accelerationTable[accel[0]] - slowFullSpeedTimeTotal)
      if temp[1] > temp[0]
        Com.Str(0, string(11, 13, "****** Possible Problem ******"))
        Com.Str(0, string(11, 13, "temp[1] > temp[0]"))
        Com.Str(0, string(11, 13, "temp[0] = "))
        Com.Dec(0, temp[0])
        Com.Str(0, string(11, 13, "temp[1] = "))
        Com.Dec(0, temp[1])
        Com.Str(0, string(11, 13, "next to last accel = "))
        Com.Dec(0, accelerationTable[accel[0] - 1])
        Com.Str(0, string(11, 13, "last accel = "))
        Com.Dec(0, accelerationTable[accel[0]])
        Com.Str(0, string(11, 13, "FullSpeed = "))
        Com.Dec(0, slowFullSpeedTimeTotal)
        Com.Str(0, string(11, 13, "Combine and divide middle three."))
        temp[2] := ((2 * accelerationTable[accel[0]]) + slowFullSpeedTimeTotal)
        lastAccelDelay[0] := temp[2] / 3
        lastAccelDelay[1] := lastAccelDelay[0]
        slowFullSpeedTimeTotal := temp[2] - (2 * lastAccelDelay[0])
        Com.Str(0, string(11, 13, "lastAccelDelay[0 & 1] = "))
        Com.Dec(0, lastAccelDelay[0])
        Com.Str(0, string(11, 13, "slowFullSpeedTimeTotal = "))
        Com.Dec(0, slowFullSpeedTimeTotal)
        Com.Str(0, string(11, 13, "Is this okay?"))
        temp[1] := accelerationTable[accel[0] - 1] - lastAccelDelay[0]
        if ||temp[1] > temp[0]
          Com.Str(0, string(11, 13, "****** Possible Problem Again ******"))
          Com.Str(0, string(11, 13, "||temp[1] > temp[0]"))
          Com.Str(0, string(11, 13, "old lastAccelDelay[0] = "))
          Com.Dec(0, lastAccelDelay[0])  
          if temp[1] < 0 'temp[0]
            lastAccelDelay[0] := accelerationTable[accel[0] - 1] - temp[0]
            slowFullSpeedTimeTotal := lastAccelDelay[0] - temp[0]
          else
            lastAccelDelay[0] := accelerationTable[accel[0] - 1] + temp[0]
            slowFullSpeedTimeTotal := lastAccelDelay[0] + temp[0]
          lastAccelDelay[1] := lastAccelDelay[0]
          Com.Str(0, string(11, 13, "adjusted lastAccelDelay[0] = "))
          Com.Dec(0, lastAccelDelay[0])
          Com.Str(0, string(11, 13, "adjusted slowFullSpeedTimeTotal = "))
          Com.Dec(0, slowFullSpeedTimeTotal)  
      else
        lastAccelDelay[0] := accelerationTable[accel[0]]
        lastAccelDelay[1] := lastAccelDelay[0]
     
      
      {slowFullSpeedTimeTotal += 2 * accelerationTable[accel[0]]
      lastAccelDelay[0] := slowFullSpeedTimeTotal / 2
      lastAccelDelay[1] := slowFullSpeedTimeTotal - lastAccelDelay[0] }
      PressToContinueOrClose("c")
    else  
      Com.Str(0, string(11, 13, "time per step = "))
      slowFullSpeedTime := slowFullSpeedTimeTotal / full[0] 
      Com.Dec(0, slowFullSpeedTime) 
      extraCountsRemaining := slowFullSpeedRemainder := slowFullSpeedTimeTotal // full[0]           
      addExtraCountInterval := full[0] / extraCountsRemaining
      Com.Str(0, string(11, 13, "slowFullSpeedRemainder = "))
      Com.Dec(0, slowFullSpeedRemainder)
      Com.Str(0, string(11, 13, "addExtraCountInterval = "))
      Com.Dec(0, addExtraCountInterval)
    fastestIndex := 0
    headingInterval := accel[0] / 2
    pauseFlag := 1

    repeat accel[0]
      slow := accelerationTable[fastestIndex]
      totalTimeSlow += slow
      Sd[shortAxis].writeLong(slow)
      filePosition[shortAxis] += 4
      if localDebugFlag  
        DisplayLineStats(totalTimeFast, totalTimeSlow, slowIndex, slowIndex{fastIndex}, {
        } delayAtMaxSpeed[Header#MASTER_ACCELERATION], slow, fastestIndex, pauseFlag, headingInterval)
      slowIndex++
      fastestIndex++
    case full[0]
      0, 1:
        slow := lastAccelDelay[0]
        totalTimeSlow += slow
        Sd[shortAxis].writeLong(slow)
        filePosition[shortAxis] += 4
        if localDebugFlag  
          DisplayLineStats(totalTimeFast, totalTimeSlow, slowIndex, slowIndex{fastIndex}, {
          } delayAtMaxSpeed[Header#MASTER_ACCELERATION], slow, fastestIndex, pauseFlag, headingInterval)
        slowIndex++
             
    fastestIndex--

    Com.Str(0, string(11, 13, "fastest slow accelerationTable = "))
    Com.Dec(0, slow)
    Com.Str(0, string(11, 13, "slowFullSpeedTime = "))
    Com.Dec(0, slowFullSpeedTime)
    PressToContinueOrClose("c")
      
    Com.Str(0, string(11, 13, "Between accel and full."))
    if localDebugFlag  
      DisplayLineHeading
    headingInterval := full[0] / 4
    
    if full[0]
      repeat full[0]
        slow := slowFullSpeedTime
        if (slowIndex - accel[0]) // addExtraCountInterval == 0
          if extraCountsRemaining
            extraCountsRemaining--
            slow++
        Sd[shortAxis].writeLong(slow)
        totalTimeSlow += slow ' the value of "fast" stays the same in this section
        filePosition[shortAxis] += 4
    
        if localDebugFlag  
          DisplayLineStats(totalTimeFast, totalTimeSlow, {
          } slowIndex, slowIndex{fastIndex}, fast, slow, fastestIndex, pauseFlag, headingInterval)
        slowIndex++

    Com.Str(0, string(11, 13, "Between full and decel."))
    if localDebugFlag  
      DisplayLineHeading
    if extraCountsRemaining
      Com.Str(0, string(11, 13, "extraCountsRemaining = "))
      Com.Dec(0, extraCountsRemaining)
      PressToContinueOrClose("c")  

    headingInterval := decel[0] / 4

    case full[0]
      0, 1:
        slow := lastAccelDelay[1]
        totalTimeSlow += slow
        Sd[shortAxis].writeLong(slow)
        filePosition[shortAxis] += 4
        if localDebugFlag  
          DisplayLineStats(totalTimeFast, totalTimeSlow, slowIndex, slowIndex{fastIndex}, {
          } delayAtMaxSpeed[Header#MASTER_ACCELERATION], slow, fastestIndex, pauseFlag, headingInterval)
        slowIndex++
            
    repeat decel[0]
      slow := accelerationTable[fastestIndex]
      totalTimeSlow += slow
      Sd[shortAxis].writeLong(slow)
      filePosition[shortAxis] += 4
      if localDebugFlag  
        DisplayLineStats(totalTimeFast, totalTimeSlow, {
        } slowIndex, slowIndex{fastIndex}, fast, slow, fastestIndex, pauseFlag, headingInterval)
      fastestIndex--
      slowIndex++

    if ++fastestIndex
      Com.Str(0, string(11, 13, "fastestIndex is not zero."))
      Com.Str(0, string(11, 13, "fastestIndex = "))
      Com.Dec(0, fastestIndex)      
    PressToContinueOrClose("c")

        
  if slowIndex <> shortDistance or fastIndex <> longDistance
    Com.Str(0, string(11, 13, "Distances don't match."))
    Com.Str(0, string(11, 13, "slowIndex = "))
    Com.Dec(0, slowIndex)
    Com.Str(0, string(11, 13, "shortDistance = "))
    Com.Dec(0, shortDistance)
    Com.Str(0, string(11, 13, "fastIndex = "))
    Com.Dec(0, fastIndex)
    Com.Str(0, string(11, 13, "longDistance = "))
    Com.Dec(0, longDistance)
    PressToContinueOrClose("c")

  result := @totalTimeSlow  
                        }
PRI DisplayLineHeading

  Com.Str(0, string(11, 13, "fastIndex, slowIndex, fast, slow, totalTimeFast, totalTimeSlow, fastestIndex"))
    
PRI DisplayLineStats(localTimeFast, localTimeSlow, slowIndex, fastIndex, fast, slow, {
} fastestIndex, pauseFlag, headingInterval)

  Com.Str(0, string(11, 13))
  Com.Dec(0, fastIndex)
  Com.Str(0, string(", "))
  Com.Dec(0, slowIndex)
  Com.Str(0, string(", "))
  Com.Dec(0, fast)
  Com.Str(0, string(", "))
  Com.Dec(0, slow)
  Com.Str(0, string(", "))
  Com.Dec(0, localTimeFast)
  Com.Str(0, string(", "))
  Com.Dec(0, localTimeSlow)
  Com.Str(0, string(", "))
  Com.Dec(0, fastestIndex)
  if fastIndex // headingInterval == 0
    DisplayLineHeading
    if pauseFlag
      Cnc.PressToContinueOrClose("c")

{PRI GetDec(sdInstance) | inputCharacter, negativeFlag, startOfNumberFlag

  Com.Str(0, string(11, 13, "GetDec"))
  globalMultiplier := 0
  longfill(@negativeFlag, 0, 2)

  repeat
    inputCharacter := Cnc.ReadByte(0)
    'filePosition[sdInstance]++
    Com.Str(0, string(11, 13, "inputCharacter = "))
    Cnc.SafeTx(inputCharacter)
    case inputCharacter
      "0".."9":
        startOfNumberFlag := 1
        result *= 10
        result += inputCharacter - "0"
        globalMultiplier *= 10
      ".":
        globalMultiplier := 1
      "-":
        negativeFlag := 1  
      " ":
        Com.Str(0, string(11, 13, "Ignore space character."))
      delimiter[0], delimiter[1], delimiter[2], delimiter[3], delimiter[4]:
        if startOfNumberFlag
          inputCharacter := delimiter[0]
        else
          inputCharacter := " "
      other:
        Com.Str(0, string(11, 13, "GetDec Error"))
        Com.Str(0, string(11, 13, "So far result = "))
        Com.Dec(0, result)
        Com.Str(0, string(11, 13, "Unexpected byte = $"))
        Pst.Hex(inputCharacter, 2)
        Cnc.PressToContinue
        'waitcnt(clkfreq * 2 + cnt)
    
  until inputCharacter == delimiter[0]

  if negativeFlag
    -result
  ifnot globalMultiplier
    globalMultiplier := 1

  Com.Str(0, string(11, 13, "GetDec result = "))
  Com.Dec(0, result)
    }
PUB ReadM(sdInstance, localValue) : parameterCount | inputCharacter, expectedParameters, {
} delimiterCount

  Com.Str(0, string(11, 13, "ReadM("))
  Com.Str(0, Header.FindString(@axesText, sdInstance))
  Com.Str(0, string(", "))
  Com.Dec(0, localValue)
  Com.Str(0, string(" = "))
  Com.Str(0, Header.FindString(@mCodeText, localValue))
  Com.Tx(0, ")")

  delimiterCount := 1
  
  case localValue
    Header#COMPULSORY_STOP_M, Header#OPTIONAL_STOP_M: ' when would these be used?
      Com.Str(0, string(11, 13, "This M code is not yet supported."))
      expectedParameters := 0
    Header#END_OF_PROGRAM_M: 'M02
      endFlag := 1
      Com.Str(0, string(11, 13, "End of program."))
      expectedParameters := 0
   { SPINDLE_ON_CCW_M:
    SPINDLE_STOP_M:  }
    other:
      Com.Str(0, string(11, 13, "This M code is not yet supported."))
      expectedParameters := 1
  expectedParameters := 0
  
  Com.Str(0, string(11, 13))
  Com.Str(0, Header.FindString(@mCodeText, localValue))
    
  if expectedParameters
    Com.Str(0, string(" = "))
    repeat  
      inputCharacter := Cnc.readByte(0)
      'filePosition[sdInstance]++
      Com.Tx(0, inputCharacter)
      case inputCharacter
        delimiter[0], delimiter[1], delimiter[2], delimiter[3], delimiter[4]:
          ifnot delimiterCount
            parameterCount++
          delimiterCount++              
        other:
          delimiterCount := 0
    until parameterCount == expectedParameters 
  else
    Com.Str(0, string(" has no parameters."))
      
  Com.Str(0, string(11, 13, "End of ReadM method."))  
{
  ' M-Codes
  #0, COMPULSORY_STOP_M, OPTIONAL_STOP_M, END_OF_PROGRAM_M, SPINDLE_ON_CCW_M
  #5, SPINDLE_STOP_M
  }
PUB ReadD(sdInstance, localValue) : parameterCount | inputCharacter, expectedParameters, {
} delimiterCount

  Com.Str(0, string(11, 13, "ReadD("))
  Com.Str(0, Header.FindString(@axesText, sdInstance))
  Com.Str(0, string(", "))
  Com.Dec(0, localValue)
  Com.Str(0, string(" = "))
  Com.Str(0, Header.FindString(@dCodeText, localValue))
  Com.Tx(0, ")")

  delimiterCount := 1
                     
  case localValue
    Header#POINT_D:
      expectedParameters := 2
    Header#EXTERNALLY_CREATED_D, Header#CREATED_USING_PROGRAM_D:
      expectedParameters := 0
    other:
      expectedParameters := 1

  case localValue
    Header#POINT_D, Header#START_D, Header#TOOL_RADIUS_UNITS_D:
      Com.Str(0, string(11, 13, "This D code is not yet supported."))

  {case localValue
    PART_VERSION_D, PART_NAME_D, PARTS_IN_FILE_D, DATE_CREATED_D, DATE_MODIFIED_D, {
      } PROGRAM_NAME_D, EXTERNALLY_CREATED_D, CREATED_USING_PROGRAM_D, AUTHOR_NAME_D, {
      } PROJECT_NAME_D: }
  Com.Str(0, string(11, 13))
  Com.Str(0, Header.FindString(@dCodeText, localValue))
    
  if expectedParameters
    Com.Str(0, string(" = "))
    repeat  
      inputCharacter := Cnc.readByte(0)
      'filePosition[sdInstance]++
      Com.Tx(0, inputCharacter)
      case inputCharacter
        delimiter[0], delimiter[1], delimiter[2], delimiter[3], delimiter[4]:
          ifnot delimiterCount
            parameterCount++
          delimiterCount++              
        other:
          delimiterCount := 0
    until parameterCount == expectedParameters
  else
    Com.Str(0, string(" has no parameters."))  
  Com.Str(0, string(11, 13, "End of ReadD method."))
      
PUB GetName(sdInstance, localPtr, localSize)

  repeat
    result := Cnc.ReadByte(0)
    'filePosition[sdInstance]++
    case result
      delimiter[0], delimiter[1], delimiter[2], delimiter[3], delimiter[4]:
        result := delimiter[0]
      other:  
        byte[localPtr++] := result
  while --localSize and result <> delimiter[0] 

  repeat while result <> delimiter[0] ' find end of program name even if it doesn't fit
    result := Cnc.ReadByte(0)
    'filePosition[sdInstance]++
    case result
      delimiter[0], delimiter[1], delimiter[2], delimiter[3], delimiter[4]:
        result := delimiter[0]
        Com.Str(0, string(11, 13, "Error, the program name was too long."))
        waitcnt(clkfreq * 2 + cnt)

PUB OpenConfig

  Com.Str(0, string(11, 13, "OpenConfig Method"))
  Cnc.PressToContinue
  sdFlag := Cnc.OpenConfig(@programState)
  
  if sdFlag == Header#READ_FILE_SUCCESS
    Cnc.ReadData(0, @programState, Header#CONFIG_SIZE)
    case programState
      {Header#FRESH_PROGRAM:
        Com.Str(0, string(11, 13, 7, "Error! programState = FRESH_PROGRAM"))
        ResetConfig
      Header#ACTIVE_PROGRAM:
        Com.Str(0, string(11, 13, 7, "Error! Previous session was not properly shutdown."))
        ResetConfig           }
      Header#TRANSITIONING_PROGRAM:
        'Com.Str(0, string(11, 13, "Returning from ", QUOTE))
        'Com.Str(0, Header.FindString(@programNames, previousProgram))
        'Com.Tx(0, QUOTE)
        previousProgram := Header#DESIGN_INPUT_MAIN
        programState := Header#ACTIVE_PROGRAM
        Cnc.WriteData(0, @programState, Header#CONFIG_SIZE)
      {Header#SHUTDOWN_PROGRAM:
        Com.Str(0, string(11, 13, "Previous session was successfully shutdown."))
        ResetConfig  }
      other:
        Com.Str(0, string(11, 13, 7, "Error! Configuration File Found But With Wrong programState."))
        Com.Str(0, string(11, 13, 7))
        'Com.Str(0, @endText)
        Com.Str(0, @errorButContinueText)
        oledPtr := 0
        oledPtr[1] := 0
        Cnc.SetOled(Header#AXES_READOUT_OLED, @errorButContinueText, @oledPtr, 2)
        previousProgram := Header#DESIGN_INPUT_MAIN
        programState := Header#ACTIVE_PROGRAM
        Cnc.WriteData(0, @programState, Header#CONFIG_SIZE)
        waitcnt(clkfreq * 2 + cnt)
  else
    Com.Str(0, string(11, 13, 7, "Error! Configuration File Not Found"))
    Com.Str(0, string(11, 13, 7))
    Com.Str(0, @endText)
    oledPtr := 0
    Cnc.SetOled(Header#AXES_READOUT_OLED, @endText, @oledPtr, 1)
    repeat     
  waitcnt(clkfreq * 2 + cnt) ' temp while debugging
        
PRI ResetConfig

  programState := Header#FRESH_PROGRAM
  microsteps := Header#DEFAULT_MICROSTEPS
  machineState := Header#DEFAULT_MACHINE_STATE
  previousProgram := Header#INIT_MAIN
  homedFlag := Header#UNKNOWN_POSITION                      
  positionX := 0 '$80_00_00_00
  positionY := 0 '$80_00_00_00
  positionZ := 0 '$80_00_00_00

PUB L

  Cnc.L

PUB C

  Cnc.C
  
PUB D 'ebugCog
'' display cog ID at the beginning of debug statements

  Cnc.D

PUB DHome

  L
  Com.Tx(0, 11)
  Com.Tx(0, 13)
  Com.Tx(0, 1)
  Com.Dec(0, cogid)
  Com.Tx(0, ":")
  Com.Tx(0, 32)

DAT

pauseInterval           long 40
minDelay                long 100 'US_001 * 1_000
maxDelay                long 10_000 'US_001 * 20_000
'cncName                 byte "CNA_0000.TXT", 0  ' Use all caps in file names or SD driver wont find them.


{programNames            byte "INIT_MAIN", 0
                        byte "DESIGN_INPUT_MAIN", 0
                        byte "DESIGN_REVIEW_MAIN", 0
                        byte "DESIGN_READ_MAIN", 0
                        byte "MANUAL_JOYSTICK_MAIN", 0
                        byte "MANUAL_NUNCHUCK_MAIN", 0
                        byte "MANUAL_POTS_MAIN", 0 } 
                          
DAT

unitsText               byte "steps", 0
                        byte "turns", 0
                        byte "inches", 0
                        byte "millimeters", 0

unitsTxt                byte "steps", 0
                        byte "turns", 0
                        byte "in", 0
                        byte "mm", 0

axesText                byte "X_AXIS", 0
                        byte "Y_AXIS", 0
                        byte "Z_AXIS", 0
                        byte "DESIGN_AXIS", 0

{machineStateTxt         byte "INIT_STATE", 0
                        byte "DESIGN_INPUT_STATE", 0
                        byte "DESIGN_REVIEW_STATE", 0
                        byte "DESIGN_READ_STATE", 0
                        byte "MANUAL_JOYSTICK_STATE", 0
                        byte "MANUAL_NUNCHUCK_STATE", 0
                        byte "MANUAL_POTS_STATE", 0   }


xyzLabels               byte "x = ", 0
yLabel                  byte "y = ", 0
zLabel                  byte "z = ", 0
                        byte "timer = ", 0

adcLabels               byte "ADC X = ", 0
                        byte "ADC Y = ", 0
                        byte "ADC Z = ", 0
                        byte "Timer = ", 0
                        
joystickLabels          byte "Joy X = ", 0
                        byte "Joy Y = ", 0
                        byte "Joy Z = ", 0
                             '012345678
buttonLabel             byte "Button off", 0
                        byte "Pot 1 = ", 0
                        byte "Pot 2 = ", 0
                        byte "Pot 3 = ", 0
                        byte "Timer = ", 0
oledMenuLimit           byte 3
oledMenuHighlightRange  byte 1, 2                             
                         
                             '0123456789012345
oledMenu                byte "Highlight&Select", 0
                        byte " Select Design", 0
                        byte " Return to Top", 0

{oledMenu                byte "Highlight&Select", 0
                        byte "  enter design", 0
                        byte "display design", 0
                        byte "execute design", 0
                        byte "   joystick", 0
                        byte "   nunchuck", 0
                        byte " poteniometers", 0
                        byte " home machine", 0
}                       
                             '0123456789012345
selectFileTxt           byte "  Select File", 0
cncNumber               byte " CNC # ", 0
                        byte " CNC # ", 0
                        byte " CNC # ", 0
                        byte " CNC # ", 0
                        byte " CNC # ", 0
                        byte " CNC # ", 0
                        byte " CNC # ", 0
                        
homedText               byte "Machine Homed", 0
endText                 byte "End of Program", 0
                             '0123456789012345
errorButContinueText    byte "Error Continuing", 0
                        byte "  with Program", 0

expectedCharText        byte "CODE_TYPE_CHAR", 0
                        byte "CODE_VALUE_CHAR", 0
                        byte "PARAMETER_VALUE_CHAR", 0
                        byte "STRING_CHAR", 0
                        byte "COMMENT_CHAR", 0

gCodeText               byte "RAPID_POSITION_G", 0
                        byte "LINEAR_G", 0
                        byte "CIRCULAR_CW_G", 0
                        byte "CIRCULAR_CCW_G", 0
                        byte "DWELL_G", 0
                        byte "5", 0
                        byte "6", 0
                        byte "7", 0
                        byte "8", 0
                        byte "9", 0
                        byte "10", 0
                        byte "#11", 0
                        byte "FULL_CIRCLE_CW_G", 0
                        byte "FULL_CIRCLE_CCW_G", 0
                        byte "14", 0
                        byte "15", 0
                        byte "16", 0
                        byte "17", 0
                        byte "18", 0
                        byte "#19", 0
                        byte "INCHES_G", 0
                        byte "MILLIMETERS_G", 0
                        byte "22", 0
                        byte "23", 0
                        byte "24", 0
                        byte "25", 0
                        byte "26", 0
                        byte "#27", 0
                        byte "HOME_G", 0
                        byte "#29", 0
                        byte "SECONDARY_HOME_G", 0
                        byte "31", 0
                        byte "32", 0
                        byte "33", 0
                        byte "34", 0
                        byte "35", 0
                        byte "36", 0
                        byte "37", 0
                        byte "38", 0
                        byte "#39", 0
                        byte "TOOL_RADIUS_COMP_OFF_G", 0
                        byte "TOOL_RADIUS_COMP_LEFT_G", 0
                        byte "TOOL_RADIUS_COMP_RIGHT_G", 0
                        byte "TOOL_HEIGHT_COMP_NEGATIVE_G", 0
                        byte "TOOL_HEIGHT_COMP_POSITIVE_G", 0
                        byte "TOOL_HEIGHT_COMP_OFF_G", 0
                        byte "46", 0
                        byte "47", 0
                        byte "48", 0
                        byte "49", 0
                        byte "50", 0
                        byte "#51", 0
                        byte "LOCAL_SYSTEM_G", 0
                        byte "MACHINE_SYSTEM_G", 0
                        byte "WORK_SYSTEM_G", 0  

mCodeText               byte "COMPULSORY_STOP_M", 0
                        byte "OPTIONAL_STOP_M", 0
                        byte "END_OF_PROGRAM_M", 0
                        byte "SPINDLE_ON_CCW_M", 0
                        byte "04", 0
                        byte "SPINDLE_STOP_M", 0
  
dCodeText               byte "POINT_D", 0
                        byte "START_D", 0
                        byte "PART_VERSION_D", 0
                        byte "PART_NAME_D", 0
                        byte "PARTS_IN_FILE_D", 0
                        byte "DATE_CREATED_D", 0
                        byte "DATE_MODIFIED_D", 0
                        byte "PROGRAM_NAME_D", 0
                        byte "EXTERNALLY_CREATED_D", 0
                        byte "CREATED_USING_PROGRAM_D", 0
                        byte "AUTHOR_NAME_D", 0
                        byte "PROJECT_NAME_D", 0
                        byte "TOOL_RADIUS_UNITS_D", 0
                        
commentFromFile         byte 0[MAX_COMMENT_CHARACTERS + 1]
                                           
'                        long
{DAT accelerationTable   'long 0[MAX_ACCEL_TABLE]
'slowaccelTable          long 0[MAX_ACCEL_TABLE]

buffer0X                long 0[Header#HUB_BUFFER_SIZE]
buffer1X                long 0[Header#HUB_BUFFER_SIZE]
buffer0Y                long 0[Header#HUB_BUFFER_SIZE]
buffer1Y                long 0[Header#HUB_BUFFER_SIZE]
buffer0Z                long 0[Header#HUB_BUFFER_SIZE]
buffer1Z                long 0[Header#HUB_BUFFER_SIZE]
extra                   long 0[Header#MAX_ACCEL_TABLE - (6 * Header#HUB_BUFFER_SIZE)]
 }
DAT
{propBeanie    byte $04, $0E, $0E, $0E, $0E, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $04, $04, $04, $F4
              byte $F4, $04, $04, $04, $82, $06, $06, $06, $06, $06, $06, $07, $0F, $0E, $0E, $04
              byte $00, $00, $00, $80, $E0, $F0, $F8, $1C, $0E, $02, $01, $00, $00, $F8, $FF, $FF
              byte $FF, $FF, $FC, $00, $00, $01, $03, $06, $1C, $F8, $F0, $E0, $80, $00, $00, $00
              byte $00, $00, $7C, $5F, $9F, $9F, $80, $88, $88, $88, $08, $08, $0E, $0F, $0F, $0F
              byte $0F, $0F, $0F, $0F, $08, $08, $88, $88, $88, $80, $9F, $9F, $5F, $7C, $00, $00
              byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01
              byte $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    }