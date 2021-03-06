DAT objectName          byte "HeaderCnc", 0
CON{
  ****** Private Notes ******
  120922a Start using header file for pin definitions and
  other constants to be used by multiple files.
  Change name from "HeaderCnc150426a" to "HeaderCnc."
  
  The parallel port cable has a 25-pin D-sub connector on one end and a 18-pin
  (2 x 9) female 0.1" connector on the other. The eight ground lines are tied
  together on the 2 x 9 connector. The ground lines all connect to pin 18 of
  2 x 9 connector. I flipped some of the wires prior to soldering so there
  is not a one to one pin numbering on the two connectors.
  #1/25 connects with #6/18
  #2/25 connects with #5/18
  #3/25 connects with #4/18
  #4/25 connects with #3/18
  #5/25 connects with #2/18
  #6/25 connects with #1/18
  #7/25 - #18/25 connects with #7/18 - #18/18
  #19/25 - #25/25 also connect #18/18
  
 The 18-pin female connector's pins are numbered 1 through 9 on one row
 and 10 through 18 on the other. The pin numbers do not alternate between
 rows as many two row connectors do.

 #1/25 = #6/18 = NC : 2nd output control
 #2/25 = #5/18 = STEP_X_PIN = 16 : X step
 #3/25 = #4/18 = DIR_X_PIN = 17 : X direction
 #4/25 = #3/18 = STEP_Y_PIN = 18 : Y step
 #5/25 = #2/18 = DIR_Y_PIN = 19 : Y direction
 #6/25 = #1/18 = STEP_Z_PIN = 20 : Z step
 #7/25 = #7/18 = DIR_Z_PIN = 21 : Z direction
 #8/25 = #8/18 : A step
 #9/25 = #9/18 : A direction
 #10/25 = #10/18 = 10 (47k) : input 1
 #11/25 = #11/18 = 11 (47k) : input 2 
 #12/25 = #12/18 = 22 (47k) : input 3 
 #13/25 = #13/18 = 13 (47k) : input 4 
 #14/25 = #14/18 : NC
 #15/25 = #15/18 = 9 (47k) : input 5
 #16/25 = #16/18 = ENABLE_PIN = 23 : enable
 #17/25 = #17/18 = NC : 1st output control
 #18/25 = #18/18 : Ground
 
 
                ' Must be a contiguous block of 6 pins
  
                
  
  STEP_Z_PIN = 20              
  DIR_Z_PIN = 21
  
}{{
1

    I/O P10 - X-Axis Home / +Overtravel (Normally HIGH, Active LOW with Axis HOME, +Overtravel)
    I/O P11 - X-Axis -Overtravel        (Normally HIGH, Active LOW with            -Overtravel)
    I/O P12 - Y-Axis Home / +Overtravel (Normally HIGH, Active LOW with Axis HOME, +Overtravel)
    I/O P13 - Y-Axis -Overtravel        (Normally HIGH, Active LOW with            -Overtravel)
    I/O P14 - Z-Axis Home / +Overtravel (Normally HIGH, Active LOW with Axis HOME, +Overtravel)
    I/O P15 - Z-Axis -Overtravel        (Normally HIGH, Active LOW with            -Overtravel)

    ' Must be a contiguous block of 6 pins    
    I/O P16 - X-Axis Step Pin   ' Movement happens on the Falling edge of our step pulse which is then    
                                '  inverted through driver transistor = rising edge ( Low for 0.5 uS)
                                '  for Superior SD200 step driver.  
    I/O P17 - X-Axis Direction Pin (Bit set for Negative direction Move, Bit clear for Positive direction move)

    I/O P18 - Y-Axis Step Pin   ' Movement happens on the Falling edge of our step pulse which is then  
                                '  inverted through driver transistor = rising edge ( Low for 0.5 uS)
                                '  for Superior SD200 step driver.    

    I/O P19 - Y-Axis Direction Pin (Bit set for Negative direction Move, Bit clear for Positive direction move)

    I/O P20 - Z-Axis Step Pin   ' Movement happens on the Falling edge of our step pulse which is then 
                                '  inverted through driver transistor = rising edge ( Low for 0.5 uS)
                                '  for Superior SD200 step driver.    

    I/O P21 - Z-Axis Direction Pin (Bit set for Negative direction Move, Bit clear for Positive direction move)

    I/O P22 -

    I/O P23 - Drive Enable (stepper drives enabled when HIGH)

    I/O P24 - SD Card DO Pin   
    I/O P25 - SD Card CLK Pin    
    I/O P26 - SD Card DI Pin   
    I/O P27 - SD Card CS Pin   

    I/O P28 - SCL I2C
    I/O P39 - SDA I2C
    I/O P30 - Serial Communications
    I/O P31 - Serial Communications

}}
CON{ cheap stepper
  'GEAR_RATIO_NUMERATOR = 25_792 '2 * 2 * 2 * 2 * 2 * 2 * 13 * 31 | 32 * 22 * 26 * 31 = 56_7424
  'GEAR_RATIO_DENOMINATOR = 405 '3 * 3 * 3 * 3 * 5 | 9 * 11 * 9 * 10 = 8910
  ' aprox 63.684
  'STEPS_PER_REV_NUMERATOR = 32 * GEAR_RATIO_NUMERATOR
  'STEPS_PER_REV_DENOMINATOR = GEAR_RATIO_DENOMINATOR
}
CON                  
    '_clkmode = xtal1 + pll16x                     
    '_xinfreq = 5_000_000
    '_stack = 150
  CLK_FREQ = 80_000_000
  MS_001 = CLK_FREQ / 1000
  
CON 'DRV7811 Version with QuickStart
{{
  MISO  Shared with SD card and possibly OLED and ADC.
  MOSI
  CLOCK
  CHIP_SELECT x 3
  SLEEP
  RESET
  FAULT
  STALL
  STEP x 3
  DIRECTION x 3

  CSPIN = 27    ' SD Card Chip Select
  I2C_CLOCK
  I2C_DATA

  '595 Channels
  3 * CHIP_SELECT DRV8711
  3 * SLEEP DRV8711
  3 * RESET DRV8711

  '165 channels
  3 * FAULT DRV8711
  3 * STALL DRV8711
  3 * FAULT DRV8711
  6 * Limit Switches
  
  '3208 Channels
  3 * Pot DRV8711
  
  
}}
CON '' QuickStart CNC

  SHIFT_CLOCK = 10'' Used for ClockPin mask
  SHIFT_MOSI = 11
  SHIFT_MISO = 0

  ADC_DATA = 1 '12
  
  LATCH_165_PIN = 13
  LATCH_595_PIN = 14
  
  SPI_CLOCK = 15
  
  STEP_X_PIN = 16              
  DIR_X_PIN = 17
  STEP_Y_PIN = 18              
  DIR_Y_PIN = 19
  STEP_Z_PIN = 20              
  DIR_Z_PIN = 21

  SPI_MOSI = 22
  SPI_MISO = 23
  DOPIN = 24    ' SD Card Data OUT
  ClKPIN = 25    ' SD Card Clock
  DIPIN = 26    ' SD Card Data IN
  CSPIN = 27    ' SD Card Chip Select
  I2CBASE = 28    ' Wii Nunchuck

  DEBUG_TX_PIN = 30
  DEBUG_RX_PIN = 31
  
  '595 Channels
  #0, CS_DRV8711_X_595, RESET_DRV8711_X_595, SLEEP_DRV8711_X_595
      CS_DRV8711_Y_595, RESET_DRV8711_Y_595, SLEEP_DRV8711_Y_595
      CS_DRV8711_Z_595, RESET_DRV8711_Z_595, SLEEP_DRV8711_Z_595
      CS_OLED_595, RESET_OLED_595, DC_OLED_595
      CS_ADC_595, SPINDLE_595
  
  '165 Channels
  #2, OVER_TRAVEL_X_POS_165, OVER_TRAVEL_X_NEG_165
      OVER_TRAVEL_Y_POS_165, OVER_TRAVEL_Y_NEG_165
      OVER_TRAVEL_Z_POS_165, OVER_TRAVEL_Z_NEG_165

  #8, STALL_DRV8711_X_165, FAULT_DRV8711_X_165
      STALL_DRV8711_Y_165, FAULT_DRV8711_Y_165
      STALL_DRV8711_Z_165, FAULT_DRV8711_Z_165
      JOYSTICK_BUTTON_165
      
  'MCP3208 Channels
  #0, POT_X_ADC, POT_Y_ADC, POT_Z_ADC
      JOY_X_ADC, JOY_Y_ADC, JOY_Z_ADC

  BITS_595 = 16
  BITS_165 = 16

  DEFAULT_MAX_DIGITS = 4

  CHANNELS_PER_CS = CS_DRV8711_Y_595 - CS_DRV8711_X_595
  
CON ' CNC Pins

  TERMINAL_BAUD = 115_200

  DEBUG_SPI_VARIABLES = 16
  DEBUG_SPI_BYTES = DEBUG_PASM_VARIABLES * 4
  MAX_DEBUG_SPI_INDEX = DEBUG_SPI_VARIABLES - 1
  
  DEBUG_PASM_VARIABLES = 6
  DEBUG_PASM_BYTES = DEBUG_PASM_VARIABLES * 4

  COMMAND_VARIABLES = 3
  COMMAND_BYTES = COMMAND_VARIABLES * 4
  
  #0, IDLE_COMMAND, MOVE_COMMAND, HOLD_POSITION_COMMAND
      SPEED_COMMAND, SET_POSITION_COMMAND
      BRAKE_COMMAND, RELEASE_BRAKE_COMMAND
    
      
  #0, IDLE_SPI, OLED_WRITE_ONE_SPI, OLED_WRITE_BUFFER_SPI
      SPIN_595_SPI, SET_ADC_CHANNELS_SPI, ADC_SPI
      DRV8711_WRITE_SPI, DRV8711_READ_SPI
      
  #0, IDLE_MOTOR, SINGLE_MOTOR, DUAL_MOTOR, TRIPLE_MOTOR, NEW_PARAMETERS_MOTOR
      CIRCLE_MOTOR
      
  DEFAULT_ADC_CHANNELS = 3
  DEFAULT_FIRST_ADC_CHANNEL = 0
  ADC_BASE_REQUEST = %1_1000   
  HUB_BUFFER_SIZE = 100
  'SHIFT_AMOUNT = 4
  'DUAL_COIL_BITS = %1100_0110_0011_1001_1100_0110_0011_1001
  MAX_ACCEL_TABLE = 1250 '1300
  MAX_MAX_ACCEL_INDEX = MAX_ACCEL_TABLE - 1

  NUMBER_OF_BUFFERS = 2
  ACCELERATION = 100
  MAX_SPEED = 500 '1000
  MIN_SPEED = 20
  SPEED_RANGE = MAX_SPEED - MIN_SPEED + 1
  SPEED_RESOLUTION = 100 ' used to create speed to acceleration table
  
' units enumeration
  #0, STEP_UNIT, TURN_UNIT, INCH_UNIT, MILLIMETER_UNIT

  MAX_UNITS_INDEX = MILLIMETER_UNIT
  NUMBER_OF_UNITS = MAX_UNITS_INDEX + 1
  
  ' pattern enumeration
  #0, SINGLE_COIL_PATTERN, DUAL_COIL_PATTERN, HALF_STEP_PATTERN

  MAX_PATTERN_INDEX = HALF_STEP_PATTERN
  NUMBER_OF_PATTERNS = MAX_PATTERN_INDEX + 1

  MAX_SCRAMBLED_PATTERN_INDEX = 5

  #0, X_AXIS, Y_AXIS, Z_AXIS, DESIGN_AXIS

  MAX_AXES_INDEX = Z_AXIS
  NUMBER_OF_AXES = MAX_AXES_INDEX + 1
  NUMBER_OF_SD_INSTANCES = 2 'NUMBER_OF_AXES + 1

  ' SD instances
  #0, CNC_DATA_SD, OLED_DATA_SD

CON 'oledFileType enumeration
  #0, NO_ACTIVE_OLED_TYPE, FONT_OLED_TYPE, GRAPHICS_OLED_TYPE

  ' fontFile enumeration
  #0, _5_x_7_FONT, FREE_DESIGN_FONT, SIMPLYTROINICS_FONT

  ' graphicsFile enumeration
  #0, BEANIE_SMALL_GRAPHICS, BEANIE_LARGE_GRAPHICS, ADAFRUIT_SPLASH_GRAPHICS
      LMR_SMALL_GRAPHICS, LMR_LARGE_GRAPHICS
  
  ' machineState enumeration  update "stateToSubIndex" if this list is changed
 { #0, INIT_STATE, HOMED_STATE, ENTER_PROGRAM_STATE, INTERPRETE_PROGRAM_STATE
      DISPLAY_PROGRAM_SINGLE_STATE, DISPLAY_PROGRAM_LINE_STATE, RUN_PROGRAM_STATE
      MANUAL_KEYPAD_STATE, MANUAL_NUNCHUCK_STATE     }

 #0, INIT_STATE, DESIGN_INPUT_STATE, DESIGN_REVIEW_STATE, DESIGN_READ_STATE
     MANUAL_JOYSTICK_STATE, MANUAL_NUNCHUCK_STATE, MANUAL_POTS_STATE
      
  DEFAULT_MACHINE_STATE = INIT_STATE
  
  #0, SLAVE_ACCELERATION, MASTER_ACCELERATION

  MAX_NAME_SIZE = PROGRAM_NAME_LIMIT

  DEFAULT_MICROSTEPS = 16

  SCALED_MULTIPLIER = 1000

  SCALED_ROOT_2 = round(^^2.0 * float(SCALED_MULTIPLIER))
  
  MIN_DELAY = MS_001

  STEPS_PER_REV_NUMERATOR = 200
  STEPS_PER_REV_DENOMINATOR = 1

  BALL_SCREW_UM = 5_000
  BALL_SCREW_CM = 5

  DEFAULT_Z_DISTANCE = 1000

  MENU_DISPLAY_TIME = 10        ' in seconds

  PSEUDO_MULTIPLIER = 1000

  WP_SD_PIN = -1          
  CD_SD_PIN = -1           
  RTC_PIN_1 = -1                 ' Pins that would have been used by real time clock.
  RTC_PIN_2 = -1
  RTC_PIN_3 = -1
  
    ' sdFlag enumeration
  #0, NOT_FOUND_SD, IN_USE_SD, INITIALIZING_SD, NEW_LOG_CREATED_SD, DESIGN_FILE_FOUND_SD, NO_DESIGN_FILE_YET_SD, IN_USE_BY_OTHER_DEVICE_SD
                   
  #0, READ_FILE_SUCCESS, FILE_NOT_FOUND, READ_FILE_ERROR_OTHER
  
  MAX_FILE_NUMBER = 9999
  PROGRAM_VERSION_CHARACTERS = 7
  VERSION_CHARACTER_TO_USE = 3
  VERSION_LOC_IN_LOG_NAME = 1
  NUMBER_LOC_IN_FILE_NAME = 4     

  ' offset from command
  #0, COMMAND_OFFSET, STEPS_OR_SPEED_OFFSET, POSITION_FROM_PASM_OFFSET, POSITION_TO_PASM_OFFSET
      

  MAX_OFFSET_INDEX = POSITION_TO_PASM_OFFSET
  NUMBER_OF_OFFSETS = MAX_OFFSET_INDEX + 1
 
CON ' Shared Constants

  DEBUG_BAUD = 115_200
  PROGRAM_NAME_LIMIT = 16

  ' wait enumeration
  #0, NO_WAIT, YES_WAIT
  
CON ' text locations

  MASTER_NEW_TV_X = 0
  MASTER_NEW_TV_Y = 0
  MASTER_NEW_VGA_X = 0
  MASTER_NEW_VGA_Y = 0

CON 'G-Code Constants

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

  ' M-Codes
  #0, COMPULSORY_STOP_M, OPTIONAL_STOP_M, END_OF_PROGRAM_M, SPINDLE_ON_CCW_M
  #5, SPINDLE_STOP_M

  ' D-Code
  #0, POINT_D, START_D, PART_VERSION_D, PART_NAME_D, PARTS_IN_FILE_D {0 - 4}
      DATE_CREATED_D, DATE_MODIFIED_D                                {5 - 6}
      PROGRAM_NAME_D, EXTERNALLY_CREATED_D, CREATED_USING_PROGRAM_D  {7 - 9}
      AUTHOR_NAME_D, PROJECT_NAME_D                                  {10 - 11}
      TOOL_RADIUS_UNITS_D                                            {12 - }

  PROGRAM_NAME_CHAR = "O"
  COMMENT_START_CHAR = "{"
  COMMENT_END_CHAR = "}"

CON ' Configuration Constants

  ' Main Program Settings
  #0, INIT_MAIN, DESIGN_INPUT_MAIN, DESIGN_REVIEW_MAIN, DESIGN_READ_MAIN
      MANUAL_JOYSTICK_MAIN, MANUAL_NUNCHUCK_MAIN, MANUAL_POTS_MAIN  

  ' Homed State
  #0, UNKNOWN_POSITION, HOMED_POSITION, SET_HOME_POSITION

  ' programState
  #0, FRESH_PROGRAM, ACTIVE_PROGRAM, TRANSITIONING_PROGRAM, SHUTDOWN_PROGRAM

  ' Config File Offsets
  #0, PROGRAM_STATE_OFFSET, MICROSTEPS_OFFSET, MACHINE_STATE_OFFSET, PREVIOUS_PROGRAM_OFFSET
      HOMED_FLAG_OFFSET, RESERVED_2_OFFSET, RESERVED_1_OFFSET, RESERVED_0_OFFSET
      POSITION_X_OFFSET_0, POSITION_X_OFFSET_1, POSITION_X_OFFSET_2, POSITION_X_OFFSET_3
      POSITION_Y_OFFSET_0, POSITION_Y_OFFSET_1, POSITION_Y_OFFSET_2, POSITION_Y_OFFSET_3
      POSITION_Z_OFFSET_0, POSITION_Z_OFFSET_1, POSITION_Z_OFFSET_2, POSITION_Z_OFFSET_3 

  MAX_CONFIG_OFFSET = POSITION_Z_OFFSET_3 
  CONFIG_SIZE = MAX_CONFIG_OFFSET + 1

  {' Config File Offsets
  #0, MACHINE_STATE_OFFSET, HOMED_OFFSET, NUNCHUCK_MODE_OFFSET
  VERSION_OFFSET_0, VERSION_OFFSET_1, VERSION_OFFSET_2, VERSION_OFFSET_3
  VERSION_OFFSET_4, VERSION_OFFSET_5, VERSION_OFFSET_6
  POSITION_X_OFFSET_0, POSITION_X_OFFSET_1, POSITION_X_OFFSET_2, POSITION_X_OFFSET_3
  POSITION_X_OFFSET_4, POSITION_X_OFFSET_5, POSITION_X_OFFSET_6, POSITION_X_OFFSET_7
  POSITION_Y_OFFSET_0, POSITION_Y_OFFSET_1, POSITION_Y_OFFSET_2, POSITION_Y_OFFSET_3
  POSITION_Y_OFFSET_4, POSITION_Y_OFFSET_5, POSITION_Y_OFFSET_6, POSITION_Y_OFFSET_7
  POSITION_Z_OFFSET_0, POSITION_Z_OFFSET_1, POSITION_Z_OFFSET_2, POSITION_Z_OFFSET_3
  POSITION_Z_OFFSET_4, POSITION_Z_OFFSET_5, POSITION_Z_OFFSET_6, POSITION_Z_OFFSET_7
  LIMIT_Z_OFFSET_0, LIMIT_Z_OFFSET_1, LIMIT_Z_OFFSET_2, LIMIT_Z_OFFSET_3
  LIMIT_Z_OFFSET_4, LIMIT_Z_OFFSET_5, LIMIT_Z_OFFSET_6, LIMIT_Z_OFFSET_7
  DRIVE_DRV8711_0, DRIVE_DRV8711_1, MICROSTEP_CODE_DRV8711
  DECAY_MODE_DRV8711_0, DECAY_MODE_DRV8711_1, DECAY_MODE_DRV8711_2
  GATE_SPEED_DRV8711_0, GATE_SPEED_DRV8711_1
  GATE_DRIVE_DRV8711_0, GATE_DRIVE_DRV8711_1
  DEADTIME_DRV8711_0, DEADTIME_DRV8711_1

  MAX_CONFIG_OFFSET = DEADTIME_DRV8711_1 
  CONFIG_SIZE = MAX_CONFIG_OFFSET + 1 }

  DEFAULT_DRIVE_DRV8711 = 60
  DEFAULT_MICROSTEP_CODE_DRV8711 = 4
  DEFAULT_DECAY_MODE_DRV8711 = 2
  DEFAULT_GATE_SPEED_DRV8711 = 0
  DEFAULT_GATE_DRIVE_DRV8711 = 1
  DEFAULT_DEADTIME_DRV8711 = 0

  ' fileIndex enumeration
  #0, CNC_DATA_FILE, CONFIG_FILE, SERIAL_FILE, MOTOR_FILE
  
  ' bitmap enumeration
  #0, BEANIE_SMALL_BITMAP, BEANIE_LARGE_BITMAP, ADAFRUIT_BITMAP
      LMR_SMALL_BITMAP, LMR_LARGE_BITMAP

  MAX_BITMAP_INDEX = LMR_LARGE_BITMAP
  NUMBER_OF_BITMAPS = MAX_BITMAP_INDEX + 1

  ' sub program enumeration  update "stateToSubIndex" if this list is changed
  #0, DESIGN_ENTRY_SUB, INSPECT_DESIGN_SUB, MANUAL_CONTROL_SUB
      NUNCHUCK_CONTROL_SUB, TEST_LINE_SUB

  MAX_SUB_PROGRAM_INDEX = TEST_LINE_SUB
  NUMBER_OF_SUB_PROGRAMS = MAX_SUB_PROGRAM_INDEX + 1

  NO_SUB_PROGRAM = 255

  OLED_BUFFER_SIZE = 1024

  OLED_WIDTH = 128
  OLED_HEIGHT = 64
  OLED_LINES = 8
  
  ' oledState enumeration
  #0, DEMO_OLED, MAIN_LOGO_OLED, AXES_READOUT_OLED, BITMAP_OLED, GRAPH_OLED
      PAUSE_MONITOR_OLED, CLEAR_OLED

  MIN_OLED_X = 0
  MAX_OLED_X = OLED_WIDTH - 1
  MIN_OLED_Y = 0
  MAX_OLED_Y = OLED_HEIGHT - 1
  MIN_OLED_INVERTED_SIZE_X = 2
  MIN_OLED_INVERTED_SIZE_Y = 8

  MAX_OLED_DATA_LINES = OLED_LINES
  MAX_OLED_LINE_INDEX = MAX_OLED_DATA_LINES - 1
  MAX_OLED_CHAR_COL = OLED_WIDTH / 8
  MAX_OLED_CHAR_COL_INDEX = MAX_OLED_CHAR_COL
  
  MAX_DATA_FILES = 40
  PRE_ID_CHARACTERS = 4
  ID_CHARACTERS = 4
  POST_ID_CHARACTERS = 4
  
  DEFAULT_DEADBAND = 4095 / 20
  DEFAULT_CENTER = 4095 / 2

  STACK_CHECK_LONG = $55_AA_A5_5A
  MONITOR_OLED_STACK_SIZE = 140 ' really 126 '175

  SERIAL_PASM_IMAGE = 452
  MOTOR_PASM_IMAGE = 414   
  MAX_PASM_IMAGE = SERIAL_PASM_IMAGE 

  RX_BUFFER = 16
  TX_BUFFER = 64

  TOTAL_SERIAL_BUFFERS = RX_BUFFER + TX_BUFFER
  
CON 'DRV8711 Constants

  CTRL_REG   = 0

  {DRV8711CTL_DEADTIME_400ns = $000
  DRV8711CTL_DEADTIME_450ns = $400
  DRV8711CTL_DEADTIME_650ns = $800
  DRV8711CTL_DEADTIME_850ns = $C00

  DRV8711CTL_IGAIN_5        = $000 }
  DRV8711CTL_IGAIN_10       = $100
 { DRV8711CTL_IGAIN_20       = $200
  DRV8711CTL_IGAIN_40       = $300}

  DRV8711CTL_STALL_INTERNAL = $000
 { DRV8711CTL_STALL_EXTERNAL = $080

  DRV8711CTL_STEPMODE_MASK  = $078

  DRV8711CTL_FORCESTEP      = $004
  DRV8711CTL_REV_DIRECTION  = $002}
  DRV8711CTL_ENABLE         = $001
  
  TORQUE_REG = 1
  
  DRV8711TRQ_BEMF_50us      = $000
  {DRV8711TRQ_BEMF_100us     = $100
  DRV8711TRQ_BEMF_200us     = $200
  DRV8711TRQ_BEMF_300us     = $300
  DRV8711TRQ_BEMF_400us     = $400
  DRV8711TRQ_BEMF_600us     = $500
  DRV8711TRQ_BEMF_800us     = $600
  DRV8711TRQ_BEMF_1ms       = $700
  }
  DRV8711TRQ_TORQUE_MASK    = $0FF

  OFF_REG    = 2
  
  DRV8711OFF_STEPMOTOR      = $000
  {DRV8711OFF_DUALMOTORS     = $100
  }
  DRV8711OFF_OFFTIME_MASK   = $0FF
  
  BLANK_REG  = 3
  
  DRV8711BLNK_ADAPTIVE_BLANK = $100
  DRV8711BLNK_BLANKTIME_MASK = $0FF
 
  DECAY_REG  = 4
  {
  DRV8711DEC_SLOW_DECAY     = $000
  DRV8711DEC_SLOW_MIXED     = $100
  DRV8711DEC_FAST_DECAY     = $200
  DRV8711DEC_MIXED_DECAY    = $300
  DRV8711DEC_SLOW_AUTOMIX   = $400
  DRV8711DEC_AUTOMIX        = $500 }
  DRV8711DEC_DECAYTIME_MASK = $0FF
  
  STALL_REG  = 5
  {
  DRV8711STL_DIVIDE_32      = $000
  DRV8711STL_DIVIDE_16      = $400 }
  DRV8711STL_DIVIDE_8       = $800
 { DRV8711STL_DIVIDE_4       = $C00 }
  DRV8711STL_STEPS_1        = $000
 { DRV8711STL_STEPS_2        = $100
  DRV8711STL_STEPS_4        = $200
  DRV8711STL_STEPS_8        = $300 }
  DRV8711STL_THRES_MASK     = $0FF
  
  DRIVE_REG  = 6
  {
  DRV8711DRV_HIGH_50mA      = $000
  DRV8711DRV_HIGH_100mA     = $400
  DRV8711DRV_HIGH_150mA     = $800
  DRV8711DRV_HIGH_200mA     = $C00

  DRV8711DRV_LOW_100mA      = $000
  DRV8711DRV_LOW_200mA      = $100
  DRV8711DRV_LOW_300mA      = $200
  DRV8711DRV_LOW_400mA      = $300

  DRV8711DRV_HIGH_250ns     = $000
  DRV8711DRV_HIGH_500ns     = $040
  DRV8711DRV_HIGH_1us       = $080
  DRV8711DRV_HIGH_2us       = $0C0

  DRV8711DRV_LOW_250ns      = $000
  DRV8711DRV_LOW_500ns      = $010
  DRV8711DRV_LOW_1us        = $020
  DRV8711DRV_LOW_2us        = $030}

  DRV8711DRV_OCP_1us        = $000
  {DRV8711DRV_OCP_2us        = $004
  DRV8711DRV_OCP_4us        = $008
  DRV8711DRV_OCP_8us        = $00C}

  DRV8711DRV_OCP_250mV      = $000
  {DRV8711DRV_OCP_500mV      = $001
  DRV8711DRV_OCP_750mV      = $002
  DRV8711DRV_OCP_1000mV     = $003
  }
  STATUS_REG = 7
  {
  DRV8711STS_LATCHED_STALL  = $080
  DRV8711STS_STALL          = $040
  DRV8711STS_PREDRIVE_B     = $020
  DRV8711STS_PREDRIVE_A     = $010
  DRV8711STS_UNDERVOLT      = $008
  DRV8711STS_OVERCUR_B      = $004
  DRV8711STS_OVERCUR_A      = $002
  DRV8711STS_OVERTEMP       = $001 }

PUB GetObjectName

  result := @objectName

'PUB GetConfigName

  'result := @configFile   
  
PUB GetFileName(fileIndex)

  'result := @dataFile
  result := FindString(@dataFile, fileIndex)
  
PUB GetBitmapWidth(bitmapIndex)

  result := bitmapWidth[bitmapIndex]
  
PUB GetBitmapHeight(bitmapIndex)

  result := bitmapHeight[bitmapIndex]
  
PUB GetBitmapName(bitmapIndex)

  result := FindString(@beanieSmallFile, bitmapIndex)

PUB GetFontWidth(fontIndex)

  result := fontWidth[fontIndex]
  
PUB GetFontHeight(fontIndex)

  result := fontHeight[fontIndex]
  
PUB GetFontFirst(fontIndex)

  result := fontFirstChar[fontIndex]
  
PUB GetFontLast(fontIndex)

  result := fontLastChar[fontIndex]
  
PUB GetFontName(fontIndex)

  result := FindString(@font5x7File, fontIndex)

PUB FindString(firstStr, stringIndex)      
'' Finds start address of one string in a list
'' of string. "firstStr" is the address of 
'' string #0 in the list. "stringIndex"
'' indicates which of the strings in the list
'' the method is to find.

  result := firstStr 
  repeat while stringIndex    
    repeat while byte[result++]  
    stringIndex--
    
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

DAT

dataFile                byte "CNC_0000.TXT", 0
configFile              byte "CONFIG_0.DAT", 0
serialFile              byte "SERIAL_4.DAT", 0
motorFile               byte "MOTORCNC.DAT", 0

beanieSmallFile         byte "BEANIE_0.DAT", 0 
beanieLargeFile         byte "BEANIE_1.DAT", 0
adafruitSplashFile      byte "ADAFRUIT.DAT", 0
lmrSmallFile            byte "LMRSMALL.DAT", 0
lmrLargeFile            byte "LMR_BIG0.DAT", 0

bitmapWidth             byte 32, 64, 128, 32, 64
bitmapHeight            byte 32, 64, 64, 32, 64

font5x7File             byte "FONT_5X7.DAT", 0
freeDesignFile          byte "FREEDESI.DAT", 0
simplyTronicsFile       byte "SIMPLYTR.DAT", 0

fontWidth               byte 8, 8, 8
fontHeight              byte 8, 8, 8
fontFirstChar           byte 0, 32, 32
fontLastChar            byte 126, 126, 126