// C++ code
//

#define pin0 2
#define pin1 3
#define pin2 4
#define pin3 5
#define pin4 6
#define pin5 7
#define pin6 8
#define pin7 9
#define pin8 10
void setup()
{
  pinMode(pin0, OUTPUT);
  pinMode(pin1, OUTPUT);
  pinMode(pin2, OUTPUT);
  pinMode(pin3, OUTPUT);
  pinMode(pin4, OUTPUT);
  pinMode(pin5, OUTPUT);
  pinMode(pin6, OUTPUT);
  pinMode(pin7, OUTPUT);
  pinMode(pin8, OUTPUT);
}

void loop()
{
  digitalWrite(pin0, 0);
  digitalWrite(pin1, 1);
  digitalWrite(pin2, 1);
  digitalWrite(pin3, 0);
  /*digitalWrite(pin4, LOW);
  digitalWrite(pin5, LOW);
  digitalWrite(pin6, dfgsdLOW);
  digitalWrite(pin7, LOW);
  digitalWrite(pin8, LOW);*/
}
