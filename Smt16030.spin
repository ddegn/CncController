DAT programName         byte "Smt16030", 0
CON
{ 
  This program might show how to use read from a SMT16030 sensor.
  By Duane Degn
  11 May, 2015
  
}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq
  MS_001   = CLK_FREQ / 1_000
  US_001   = CLK_FREQ / 1_000_000

  SCALED_MULTIPLIER = 10_000
  SCALED_DECIMAL_PLACES = 4
  SCALED_CONVERSION_DENOMINATOR = 47  ' = .0047 * 10_000
  SCALED_CONVERSION_SUBTRACTION = 3200  ' = .32 * 10_000
 
  SMT16030_PIN = 16  ' Connect to sensor with at least a 3K ohm resistor. 10K ohm should work fine.
  
VAR

  long scaledTemperature ' make this global so it can be used from other methods
  
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
  Pst.Clear
  
  TestSensor 

PUB TestSensor | startLow, startHigh, endTime, timeHigh, timeTotal, scaledDutyCycle
 
  repeat 
    waitpeq(|< SMT16030_PIN, |< SMT16030_PIN, 0) ' wait for pin to go high
    waitpeq(0, |< SMT16030_PIN, 0) ' wait for pin to go low
    startLow := cnt      ' record start of low time
    waitpeq(|< SMT16030_PIN, |< SMT16030_PIN, 0) ' wait for pin to go high
    startHigh := cnt     ' record start of high time 
    waitpeq(0, |< SMT16030_PIN, 0) ' wait for pin to go low again
    endTime := cnt      ' record start of low time
    timeTotal := endTime - startLow
    timeHigh := endTime - startHigh

    scaledDutyCycle := (timeHigh * SCALED_MULTIPLIER) / timeTotal
    scaledTemperature := ((scaledDutyCycle - SCALED_CONVERSION_SUBTRACTION) * SCALED_MULTIPLIER) / {
    } SCALED_CONVERSION_DENOMINATOR
    
    Pst.Home
    Pst.Str(string("    SMT16030 Temperture Sensor Demo", 11, 13)) 
    Pst.Str(string(11, 13, "timeTotal = ")) ' get the raw values in hex and dec
    ' 11 clears the end of the previous line, 13 moves to a new line
    
    Pst.Dec(timeTotal)
    Pst.Str(string(" clocks or "))  
    Pst.Dec(timeTotal / US_001)
    Pst.Str(string(" us"))  
    Pst.Str(string(11, 13, "timeHigh = ")) 
    Pst.Dec(timeHigh)
    Pst.Str(string(" clocks or "))  
    Pst.Dec(timeHigh / US_001)
    Pst.Str(string(" us"))  
    Pst.Str(string(11, 13, "duty cycle (out of 1.0) = ")) 
    DecPoint(scaledDutyCycle, SCALED_DECIMAL_PLACES)
    Pst.Str(string(11, 13, "temperature = ")) 
    DecPoint(scaledTemperature, SCALED_DECIMAL_PLACES)
    Pst.Str(string(" C"))  
    
PUB DecPoint(value, decimalPlaces) | localBuffer[4]

  result := Format.FDec(@localBuffer, value, decimalPlaces + 3, decimalPlaces)
  byte[result] := 0
  Pst.str(@localBuffer)
  
