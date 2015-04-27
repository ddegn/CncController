DAT programName         byte "DESIGNIN", 0
CON
{  Design Input

  ******* Private Notes *******
 
  Change name from "StepperControl150426b" to "DI50426A."
  Change name from "DI50427A" to "DESIGNIN."
  
}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq
  MS_001   = CLK_FREQ / 1_000
  US_001   = CLK_FREQ / 1_000_000

  SCALED_MULTIPLIER = 1000

  QUOTE = 34

  'designState enumeration
  #0, INIT_DESIGN, NEW_DESIGN, PREVIOUS_DESIGN, RETURN_FROM_DESIGN
            
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
  long timer
  long topX, topY, topZ
  long oledPtr[Header#MAX_OLED_DATA_LINES]
  long adcPtr, buttonMask
  long configPtr
  
  byte debugLock, spiLock
  'byte tstr[32]

  'byte sdMountFlag[Header#NUMBER_OF_SD_INSTANCES]
  'byte endFlag
  'byte configData[Header#CONFIG_SIZE]
  byte sdFlag, highlightedLine

DAT

designFileIndex         long -1
lowerZAmount            long Header#DEFAULT_Z_DISTANCE

'microStepMultiplier     long 1
'machineState            byte Header#INIT_STATE
stepPin                 byte Header#STEP_X_PIN, Header#STEP_Y_PIN, Header#STEP_Z_PIN
directionPin            byte Header#DIR_X_PIN, Header#DIR_Y_PIN, Header#DIR_Z_PIN
designState             byte INIT_DESIGN

programState            byte Header#FRESH_PROGRAM
microsteps              byte Header#DEFAULT_MICROSTEPS
machineState            byte Header#DEFAULT_MACHINE_STATE
previousProgram         byte Header#INIT_MAIN
homedFlag               byte Header#UNKNOWN_POSITION, 0[3]                          
positionX               long 0 '$80_00_00_00
positionY               long 0 '$80_00_00_00
positionZ               long 0 '$80_00_00_00
 
OBJ

  Header : "HeaderCnc"
  Pst : "Parallax Serial TerminalDat"
  Format : "StrFmt"
  'Sd[1]: "SdSmall" 
  Cnc : "CncCommonMethods"
   
PUB Setup(parameter0, parameter1) | cncCog

  configPtr := Header.GetConfigName

  Pst.Start(115_200)
 
  'cognew(OledDemo, @stack)
  debugLock := locknew
  spiLock := locknew
  Cnc.SetDebugLock(debugLock)
 
  repeat
    result := Pst.RxCount
    Pst.str(string(11, 13, "Press any key to continue starting program."))
    waitcnt(clkfreq / 2 + cnt)
  until result
  Pst.RxFlush

  cncCog := Cnc.Start(spiLock)

  adcPtr := Cnc.GetAdcPtr
  buttonMask := 1 << Header#JOYSTICK_BUTTON_165
  
  Pst.str(string(11, 13, "Helper object started on cog #"))
  Pst.Dec(cncCog)   
  Pst.Char(".")   

  waitcnt(clkfreq * 2 + cnt)

  Cnc.PressToContinue
  
  'AdcJoystickLoop


  'repeat
  
  'TempLoop

  'repeat
  
  OpenConfig
  'repeat
  result := 0
 { repeat result from 0 to 2
    Cnc.ResetDrv8711(result)
    Pst.str(string(11, 13, "Reset axis #"))
    Pst.Dec(result)   
    Pst.Char(".")

    Pst.str(string(11, 13, "Reading registers prior to setup."))
    Cnc.ShowRegisters(result)
    
    Cnc.SetupDvr8711(result, Header#DEFAULT_DRIVE_DRV8711, Header#DEFAULT_MICROSTEP_CODE_DRV8711, {
    } Header#DEFAULT_DECAY_MODE_DRV8711, Header#DEFAULT_GATE_SPEED_DRV8711, {
    } Header#DEFAULT_GATE_DRIVE_DRV8711, Header#DEFAULT_DEADTIME_DRV8711)
    Pst.str(string(11, 13, "Setup finished axis #"))
    Pst.Dec(result)   
    Pst.Char(".")
    Cnc.PressToContinue
    Pst.str(string(11, 13, "Reading registers."))
    Cnc.ShowRegisters(result)
    Cnc.PressToContinue    }

  'repeat  
  MainLoop

PUB AdcJoystickLoop | localIndex, buttonValue, previousButton, {
} invertPos[2], invertSize, center[3], deadBand, posSlope[2], sizeSlope, previousJoy[3], {
} temp, maxPos[2]
  L
  Pst.Str(string(11, 13, "AdcJoystickLoop Method"))
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
    Pst.Char(11)
    Pst.Char(13)
    Pst.PositionY(0)
    Pst.Dec(cogid)
    Pst.Char(":")
    Pst.Char(32)
    temp := long[oledPtr[2]] - center[2]
    if temp < -deadBand
      temp += deadBand
      temp -= sizeSlope - 1
    elseif temp > deadBand
      temp -= deadBand
      temp += sizeSlope - 1
    else
      temp := 0
    Pst.Str(string("temp was = "))
    Pst.Dec(temp)
    Pst.Str(string(", sloped temp ="))
   
    temp /= sizeSlope
    
    Pst.Dec(temp)
    Pst.Str(string(", invertSize was ="))
    Pst.Dec(invertSize)  
    invertSize := Header#MIN_OLED_INVERTED_SIZE_Y #> invertSize + temp <# 96
    Pst.Str(string(", invertSize is ="))
    Pst.Dec(invertSize)
    
    repeat localIndex from 0 to 1 
      temp := long[oledPtr[localIndex]] - center[localIndex]
      Pst.Str(string(11, 13, "temp["))
      Pst.Dec(localIndex)
      Pst.Str(string("] was = "))
      Pst.Dec(temp)
      Pst.Str(string(", adjusted for deadband = "))
      if temp < -deadBand
        temp += deadBand
        temp -= posSlope - 1
      elseif temp > deadBand
        temp -= deadBand
        temp += posSlope - 1
      else
        temp := 0
      Pst.Dec(temp)    
      temp /= posSlope[localIndex]
      Pst.Str(string(", sloped temp ="))
      Pst.Dec(temp)    
      Pst.Str(string(11, 13, "invertPos["))
      Pst.Dec(localIndex)
      Pst.Str(string("] was = "))
      Pst.Dec(invertPos[localIndex])
      Pst.Str(string(", is = "))
      invertPos[localIndex] := 0 #> invertPos[localIndex] + temp <# {
      } (maxPos[localIndex] - (invertSize / 2))
      Pst.Dec(invertPos[localIndex])
      
      
    temp := Cnc.SetInvert(invertPos[0], invertPos[1], invertPos[0] + invertSize, invertPos[1] + invertSize)
    
    Pst.Str(string(11, 13, "SetInvert("))
    Pst.Dec(invertPos[0])
    Pst.Str(string(", "))
    Pst.Dec(invertPos[1])
    Pst.Str(string(", "))
    Pst.Dec(invertPos[0] + invertSize)
    Pst.Str(string(", "))
    Pst.Dec(invertPos[1] + invertSize)
    Pst.Char(")")
    buttonValue := Cnc.Get165Value & buttonMask 
    Pst.Char(11)
    Pst.Char(13)
    Cnc.ReadableBin(buttonValue, 32)
    if buttonValue <> previousButton
      previousButton := buttonValue
      if buttonValue
        buttonLabel[8] := "f"
        buttonLabel[9] := "f"
      else
        buttonLabel[8] := "n"
        buttonLabel[9] := " "
    Pst.Char(11)
    Pst.Char(13)
    'C
    timer--
    'DHome
    'Pst.Home
    repeat localIndex from 0 to 7
      Pst.Str(Header.FindString(@adcLabels, localIndex))
      if oledPtr[localIndex] '<> $80_00_00_00
        Pst.Dec(long[oledPtr[localIndex]])
      {Pst.Char(",")
      Pst.Char(" ")
      Pst.Dec(long[oledPtr[localIndex] + 32])  }
      Pst.Char(11)
      Pst.Char(13)  
    C
    waitcnt(clkfreq / 10 + cnt)
    'result := Pst.RxCount
    
  'until result
    result := Cnc.Get165Value & buttonMask    
    
  while result

  L
  Pst.Str(string(11, 13, "End of AdcJoystickLoop Method"))
  C
  
  Cnc.InvertOff
  waitcnt(clkfreq / 10 + cnt)
  
  Cnc.SetOled(Header#DEMO_OLED, @xyzLabels, @oledPtr, 4) 
  waitcnt(clkfreq * 2 + cnt)
  
PUB MainLoop

  repeat
    if homedFlag == Header#SET_HOME_POSITION
      HomeMachine
    case designState
      INIT_DESIGN:
        \MainMenu
      NEW_DESIGN:
      PREVIOUS_DESIGN:
      RETURN_FROM_DESIGN:
      Header#DESIGN_INPUT_MAIN:
        ReturnToTop
  
      other:
        Pst.str(string(11, 13, "Unexpected designState ="))               
        Pst.Dec(designState)
        Cnc.PressToContinueOrClose(-1)
        Pst.str(string(11, 13, "End of program."))               
        repeat
        
{PUB SwitchToSubProgram(programIndex) | fileName, subProgramName
'' This method is mainly a debugging aid. Most of this
'' can be removed in the future.

  fileName := Cnc.FindString(@cncName, programIndex)
  subProgramName := Cnc.FindString(@programNames, programIndex)
  Pst.str(string(11, 13, "Switching to ", QUOTE))
  Pst.str(subProgramName)
  Pst.str(string(QUOTE, ", calling Sd.bootPartition("))
  Pst.str(fileName)
  Pst.Char(")")
  waitcnt(clkfreq * 2 + cnt)
  MenuSelection(fileName)
   }     
PUB ReturnToTop

  programState := Header#TRANSITIONING_PROGRAM
  previousProgram := Header#DESIGN_INPUT_MAIN
  Cnc.OpenOutputFileW(0, configPtr, -1)
  Cnc.WriteData(0, @programState, Header#CONFIG_SIZE)
  'MountSd(0)
  {Cnc.BootPartition(0, fileNamePtr)

  Cnc.PressToContinueOrClose(-1)
  Pst.str(string(11, 13, 7, "Something is wrong.")) }              
  Pst.str(string(11, 13, 7, "Preparing to reboot."))               
  waitcnt(clkfreq * 3 + cnt)
  reboot
  
{PUB InitState

  repeat
    Pst.Home
    Pst.str(string(11, 13, "Machine needs to be homed."))
    Pst.str(string(11, 13, "Do homing stuff here."))
    Pst.str(string(11, 13, "Wait until limit switches are installed."))
    Pst.str(string(11, 13, "Changing to ", QUOTE, "HOMED_STATE", QUOTE, "."))
    Pst.ClearEnd
    Pst.Newline
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
  
  repeat
    Pst.Home

    Pst.str(string(11, 13, "Machine waiting for input."))
    Pst.str(string(11, 13, "Press ", QUOTE, "n", QUOTE, " to start New design file."))
    Pst.str(string(11, 13, "Press ", QUOTE, "e", QUOTE, " to Edit previous design."))
    Pst.str(string(11, 13, "Press ", QUOTE, "r", QUOTE, " to Return to top menu.")) 
    Pst.ClearEnd
    Pst.Newline
    Pst.ClearBelow
    result := Pst.RxCount
    {if result
      machineState := MenuInput
      Pst.str(string(11, 13, "Changing to ", QUOTE))
      Pst.str(Cnc.FindString(@machineStateTxt, machineState))
      Pst.str(string(QUOTE, "."))
      waitcnt(clkfreq * 2 + cnt)  }
    CheckMenu(result)  
  while machineState == Header#INIT_STATE

PUB CheckMenu(tempValue) 

  result := 1
  
  if tempValue
    tempValue := Pst.CharIn
    result := 0
  else
    tempValue := highlightedLine
    result := Cnc.Get165Value & buttonMask

  ifnot result
    case tempValue
      1, "n", "N": 
        designState := NEW_DESIGN
      2, "o", "O":
        designState := PREVIOUS_DESIGN
      3, "r", "R":
        designState := RETURN_FROM_DESIGN
      other:
        designState := INIT_DESIGN
    Cnc.InvertOff
    abort
{  oledMenu                byte "Highlight&Select", 0
                        byte "   Start New", 0
                        byte " Open Previous", 0
                        byte " Return to Top", 0  }
  Cnc.ReadAdc
  result := GetJoystick(Header#JOY_Y_ADC, -Header#DEFAULT_DEADBAND)
  Pst.str(string(11, 13, "result Y ="))               
  Pst.Dec(result)
  result += GetJoystick(Header#JOY_Z_ADC, Header#DEFAULT_DEADBAND)
  Pst.str(string(11, 13, "result Y + Z ="))               
  Pst.Dec(result)
  if result > 0 and highlightedLine < oledMenuHighlightRange[1]
    highlightedLine++
  elseif result < 0 and highlightedLine > oledMenuHighlightRange[0]
    highlightedLine--
  Pst.str(string(11, 13, "highlightedLine ="))               
  Pst.Dec(highlightedLine)
  Cnc.SetInvert(0, highlightedLine * 8, Header#MAX_OLED_X, (highlightedLine * 8) + 7)

PUB GetJoystick(localAxis, scaler)

  result := long[adcPtr][localAxis] - Header#DEFAULT_CENTER
  {Pst.Str(string(11, 13, "temp["))
  Pst.Dec(localIndex)
  Pst.Str(string("] was = "))
  Pst.Dec(temp)
  Pst.Str(string(", adjusted for deadband = "))  }

  Pst.Str(string(11, 13, "GJ("))
  Pst.Dec(localAxis)
  Pst.Str(string(", "))
  Pst.Dec(scaler)
  Pst.Str(string(") "))  
  if result < -Header#DEFAULT_DEADBAND
    Pst.Str(string("negative joystick = "))
    result += Header#DEFAULT_DEADBAND
    Pst.Dec(result)
    'temp -= posSlope - 1
  elseif result > Header#DEFAULT_DEADBAND
    Pst.Str(string("positive joystick = "))
    result -= Header#DEFAULT_DEADBAND
    Pst.Dec(result)
    'temp += posSlope - 1
  else
    result := 0
  'Pst.Dec(temp)    
  result /= scaler
  {Pst.Str(string(", sloped temp ="))
  Pst.Dec(temp)    
  Pst.Str(string(11, 13, "invertPos["))
  Pst.Dec(localIndex)
  Pst.Str(string("] was = "))
  Pst.Dec(invertPos[localIndex])
  Pst.Str(string(", is = "))  
  invertPos[localIndex] := 0 #> invertPos[localIndex] + temp <# {
  } (maxPos[localIndex] - (invertSize / 2))
  Pst.Dec(invertPos[localIndex])}
      
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
PUB HomeMachine

  Pst.ClearEnd
  Pst.Newline
  Pst.Str(@homedText)
  oledPtr := 0
  Cnc.SetOled(Header#AXES_READOUT_OLED, @homedText, @oledPtr, 1)
  homedFlag := Header#HOMED_POSITION
  longfill(@positionX, 0, 3)
  waitcnt(clkfreq * 2 + cnt)
  
PUB OpenConfig

  Pst.Str(string(11, 13, "OpenConfig Method"))
  Cnc.PressToContinue
  sdFlag := Cnc.OpenConfig(@programState)
  
  if sdFlag == Header#READ_FILE_SUCCESS
    Cnc.ReadData(0, @programState, Header#CONFIG_SIZE)
    case programState
      {Header#FRESH_PROGRAM:
        Pst.Str(string(11, 13, 7, "Error! programState = FRESH_PROGRAM"))
        ResetConfig
      Header#ACTIVE_PROGRAM:
        Pst.Str(string(11, 13, 7, "Error! Previous session was not properly shutdown."))
        ResetConfig           }
      Header#TRANSITIONING_PROGRAM:
        Pst.Str(string(11, 13, "Returning from ", QUOTE))
        Pst.Str(Cnc.FindString(@programNames, previousProgram))
        Pst.Char(QUOTE)
        previousProgram := Header#DESIGN_INPUT_MAIN
        programState := Header#ACTIVE_PROGRAM
        Cnc.WriteData(0, @programState, Header#CONFIG_SIZE)
      {Header#SHUTDOWN_PROGRAM:
        Pst.Str(string(11, 13, "Previous session was successfully shutdown."))
        ResetConfig  }
      other:
        Pst.Str(string(11, 13, 7, "Error! Configuration File Found But With Wrong programState."))
        Pst.Str(string(11, 13, 7))
        Pst.Str(@endText)
        oledPtr := 0
        Cnc.SetOled(Header#AXES_READOUT_OLED, @endText, @oledPtr, 1)
        repeat 
  else
    Pst.Str(string(11, 13, 7, "Error! Configuration File Not Found"))
    Pst.Str(string(11, 13, 7))
    Pst.Str(@endText)
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
  Pst.Char(11)
  Pst.Char(13)
  Pst.Home
  Pst.Dec(cogid)
  Pst.Char(":")
  Pst.Char(32)

DAT

cncName                 byte "CNA_0000.TXT", 0  ' Use all caps in file names or SD driver wont find them.

designInput             byte "DI50328A.BIN", 0  
designReview            byte "DR50407B.BIN", 0
designExecute           byte "ED50407A.BIN", 0
manualJoystick          byte "MJ50406E.BIN", 0
manualNunchuck          byte "MN50407A.BIN", 0
manualPots              byte "MP50407A.BIN", 0

programNames            byte "INIT_MAIN", 0
                        byte "DESIGN_INPUT_MAIN", 0
                        byte "DESIGN_REVIEW_MAIN", 0
                        byte "DESIGN_READ_MAIN", 0
                        byte "MANUAL_JOYSTICK_MAIN", 0
                        byte "MANUAL_NUNCHUCK_MAIN", 0
                        byte "MANUAL_POTS_MAIN", 0  
                          
DAT

unitsText               byte "steps", 0
                        byte "turns", 0
                        byte "inches", 0
                        byte "millimeters", 0

axesText                byte "X_AXIS", 0
                        byte "Y_AXIS", 0
                        byte "Z_AXIS", 0
                        byte "DESIGN_AXIS", 0

machineStateTxt         byte "INIT_STATE", 0
                        byte "DESIGN_INPUT_STATE", 0
                        byte "DESIGN_REVIEW_STATE", 0
                        byte "DESIGN_READ_STATE", 0
                        byte "MANUAL_JOYSTICK_STATE", 0
                        byte "MANUAL_NUNCHUCK_STATE", 0
                        byte "MANUAL_POTS_STATE", 0


xyzLabels               byte "x = ", 0
                        byte "y = ", 0
                        byte "z = ", 0
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
oledMenuLimit           byte 4
oledMenuHighlightRange  byte 1, 3                             
                         
                             '0123456789012345
oledMenu                byte "Highlight&Select", 0
                        byte "   Start New", 0
                        byte " Open Previous", 0
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


homedText               byte "Machine Homed", 0
endText                 byte "End of Program", 0                     
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
propBeanie    byte $04, $0E, $0E, $0E, $0E, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $04, $04, $04, $F4
              byte $F4, $04, $04, $04, $82, $06, $06, $06, $06, $06, $06, $07, $0F, $0E, $0E, $04
              byte $00, $00, $00, $80, $E0, $F0, $F8, $1C, $0E, $02, $01, $00, $00, $F8, $FF, $FF
              byte $FF, $FF, $FC, $00, $00, $01, $03, $06, $1C, $F8, $F0, $E0, $80, $00, $00, $00
              byte $00, $00, $7C, $5F, $9F, $9F, $80, $88, $88, $88, $08, $08, $0E, $0F, $0F, $0F
              byte $0F, $0F, $0F, $0F, $08, $08, $88, $88, $88, $80, $9F, $9F, $5F, $7C, $00, $00
              byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01
              byte $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  