DAT programName         byte "MathTestSine", 0
CON
{ 
  This program shows how to use the sine table.
}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

  SCALED_MULTIPLIER = 10_000
  SCALED_DECIMAL_PLACES = 4
  SCALED_NINETY_DEGREES = 90 * SCALED_MULTIPLIER
  TWELVE_BITS = 1 << 12
  TWELVE_BITS_MINUS_ONE = TWELVE_BITS - 1
  SIZE_OF_SINE_TABLE = 2_049 ' From Propeller Manual
  MAX_TABLE_INDEX = SIZE_OF_SINE_TABLE - 1
  ONE_AS_16_BITS = $FFFF ' sin(90) = $FFFF or 1
  SINE_TABLE_LOCATION = $E000
  
OBJ

  Pst : "Parallax Serial Terminal"
  Format : "StrFmt"
   
PUB Setup

  Pst.Start(115_200)
 
  repeat
    result := Pst.RxCount
    Pst.Str(string(11, 13, "Press any key to start program."))
    waitcnt(clkfreq / 2 + cnt)
  until result
  
  Pst.RxFlush

  TestMath 

PUB TestMath | sineIndex
 
  repeat sineIndex from 0 to MAX_TABLE_INDEX step $10
    Pst.Str(string(11, 13, "word[$E000][$")) ' get the raw values in hex and dec
    Pst.Hex(sineIndex, 3)
    Pst.Str(string("] = $"))
    Pst.Hex(word[SINE_TABLE_LOCATION][sineIndex], 3)
    Pst.Str(string(" or word[57_344]["))
    Pst.Dec(sineIndex)
    Pst.Str(string("] = "))
    Pst.Dec(word[SINE_TABLE_LOCATION][sineIndex])

    '' convert raw values to properly scaled values
    Pst.Str(string(" | sin("))      
    DecPoint(sineIndex * SCALED_NINETY_DEGREES / MAX_TABLE_INDEX, SCALED_DECIMAL_PLACES)
    Pst.Str(string(") = "))
    DecPoint(word[SINE_TABLE_LOCATION][sineIndex] * SCALED_MULTIPLIER / ONE_AS_16_BITS, {
    } SCALED_DECIMAL_PLACES)
    
    ifnot sineIndex // $200 
      PressToContinue
  
  repeat ' Keep cog alive

PUB PressToContinue
  
  Pst.Str(string(11, 13, "Press to continue."))
  repeat
    result := Pst.RxCount
  until result
  
  Pst.RxFlush

PUB DecPoint(value, decimalPlaces) | localBuffer[4]

  result := Format.FDec(@localBuffer, value, decimalPlaces + 3, decimalPlaces)
  byte[result] := 0
  Pst.str(@localBuffer)
  
