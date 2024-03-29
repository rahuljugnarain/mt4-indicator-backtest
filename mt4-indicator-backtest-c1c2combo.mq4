//+---------------------------------------------------------------------------|
//|                                               mt4-indicator-backtest.mq4  |
//|                 https://github.com/rahuljugnarain/mt4-indicator-backtest  |
//|                                                        February 22, 2021  |
//|                                                                    v1.00  |
//|             Code adapted from Gonçalo Esteves https://github.com/goncaloe |
//+---------------------------------------------------------------------------+
#property strict

#define FLAT 0
#define LONG 1
#define SHORT 2

enum IndicatorTypes {
   ________GENERIC_______ = 0,
   ZeroLine = 1,
   LineCross = 2, // 2LineCross
   MovingAverage = 3,
};

enum OptimizationCalcTypes {
   Winrate = 0,
   Takeprofit = 1,
   Stoploss = 2,
   WinsBeforeTP = 3,
   LossesBeforeSL = 4,
   EstimatedWinrate = 5,
};

sinput int ATRPeriod = 14;
sinput int Slippage = 3;
sinput double RiskPercent = 2;
sinput int TakeProfitPercent = 100;
sinput int StopLossPercent = 150;
sinput bool ReopenOnOppositeSignal = true;
sinput OptimizationCalcTypes OptimizationCalcType = 0;
sinput IndicatorTypes C1IndicatorType = 1;
sinput string C1IndicatorPath = "MyIndicator";
sinput string C1IndicatorParams = "";
sinput int C1IndicatorIndex1 = 0;
sinput int C1IndicatorIndex2 = 1;
sinput IndicatorTypes C2IndicatorType = 1;
sinput string C2IndicatorPath = "MyIndicator";
sinput string C2IndicatorParams = "";
sinput int C2IndicatorIndex1 = 0;
sinput int C2IndicatorIndex2 = 1;
extern double Input1 = 0;
extern double Input2 = 0;
extern double Input3 = 0;
extern double Input4 = 0;
extern double Input5 = 0;
extern double Input6 = 0;
extern double Input7 = 0;
extern double Input8 = 0;


// GLOBAL VARIABLES:
double myATR;
double stopLoss;
double takeProfit;
int myTicket;
int myTrade;
string C1Params[];
string C2Params[];
int countTP = 0;
int countSL = 0;
int countWinsBeforeTP = 0;
int countLossesBeforeSL = 0;
int GlobalCounter = 0;
int globalC1SwitchTracker = 0;

int OnInit(void){
   prepareC1Parameters(C1IndicatorParams, C1Params);
   prepareC2Parameters(C2IndicatorParams, C2Params);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason){  
   updateBacktestResults();
   string text = StringConcatenate("WinsTP: ", countTP, "; LossesSL: ", countSL, "; WinsBeforeTP: ", countWinsBeforeTP, "; LossesBeforeSL: ", countLossesBeforeSL);
   StringAdd(text, StringFormat("; Winrate: %.2f", getNNFXWinrate()));StringAdd(text, StringFormat("; Estimated Winrate: %.2f", getEstimatedWinrate()));
   Print(text);
}

void OnTick(){  
   checkTicket();
   checkForOpen();
}

double OnTester()
{
   updateBacktestResults();
   switch(OptimizationCalcType){
      case 0:
         return getNNFXWinrate();
      case 1:
         return countTP;
      case 2:
         return countSL;
      case 3:
         return countWinsBeforeTP;
      case 4:
         return countLossesBeforeSL;       
      case 5:
         return getEstimatedWinrate(); 
   }

   return 0;
}

//======================================================================
// SIGNAL FUNCTIONS----------------------------------------------------
//======================================================================

/*
return int: the signal of indicator
   FLAT: no signal
   LONG: long signal
   SHORT: short signal
for custom indicator uncomment only the indicator that we are testing     
*/

int getSignal()
{
   int c1 = FLAT;
   double C1indParams[];
   switch(C1IndicatorType){
      case 1:
         parseC1ParametersDouble(C1Params, C1indParams);
         c1 = getZeroLineSignal(C1IndicatorPath, C1indParams, C1IndicatorIndex1);
         break;
      case 2:
         parseC1ParametersDouble(C1Params, C1indParams);
         c1 = get2LineCrossSignal(C1IndicatorPath, C1indParams, C1IndicatorIndex1, C1IndicatorIndex2);
         break;
      case 3:
         parseC1ParametersDouble(C1Params, C1indParams);
         c1 = getMASignal(C1IndicatorPath, C1indParams, C1IndicatorIndex1);
         break;             
        
   }
   int c2 = FLAT;
   double C2indParams[];
   switch(C2IndicatorType){
      case 1:
         parseC2ParametersDouble(C2Params, C2indParams);
         c2 = getZeroLineSignal(C2IndicatorPath, C2indParams, C2IndicatorIndex1);
         break;
      case 2:
         parseC2ParametersDouble(C2Params, C2indParams);
         c2 = get2LineCrossSignal(C2IndicatorPath, C2indParams, C2IndicatorIndex1, C2IndicatorIndex2);
         break;
      case 3:
         parseC2ParametersDouble(C1Params, C2indParams);
         c2 = getMASignal(C2IndicatorPath, C2indParams, C2IndicatorIndex1);
         break;             
        
   }   
   return comboSignal(c1,c2);
}



//Returns new signal only when signal differs from previous one and C2 indicator agrees
int comboSignal(int c1Signal, int c2Signal){
   static int prevSignal = FLAT;
   static int prevC1 = FLAT;
   static int counter = 0;
   
   if(prevC1 == c1Signal){
      return FLAT;
   }
   
   if(prevC1 != c1Signal){
      counter = 0;
      prevC1 = c1Signal;
   }   
   
   if(c1Signal == FLAT){
      return FLAT;
   }
   
   if((prevC1 != c1Signal) && (c2Signal != c1Signal)){
      counter = counter+1;
      Print(counter);
      return FLAT;
   }   
   
   else if((c1Signal == c2Signal) && (counter<2)){
      prevSignal = c1Signal;
      counter = 0;
      return c1Signal;
   }
   
   
   return FLAT;
}



int get2LineCrossSignal(string ind, double &params[], int buff1, int buff2)
{
   double v0Curr = iCustomArray(NULL, 0, ind, params, buff1, 1);
   double v1Curr = iCustomArray(NULL, 0, ind, params, buff2, 1);
   int signal = FLAT;
   if(v0Curr > v1Curr){
      signal = LONG;
   }
   else if(v0Curr < v1Curr){
      signal = SHORT;
   }
   return signal;
}

int getZeroLineSignal(string ind, double &params[], int buff)
{
   double vCurr = iCustomArray(NULL, 0, ind, params, buff, 1);  
   int signal = FLAT;
   if(vCurr >= 0){
      signal = LONG;
   }
   else if(vCurr <= 0){
      signal = SHORT;
   }
   return signal;
}

int getMASignal(string ind, double &params[], int buff)
{
   double vCurr = iCustom(NULL, 0, ind, params[0], buff, 1);
   double vPrev = iCustom(NULL, 0, ind, params[0], buff, 2);
   
   int signal = FLAT;
   if(vCurr > vPrev){
      signal = LONG;
   }
   else if(vCurr < vPrev){
      signal = SHORT;
   }
   return signal;
}

//====================================================================
// TRADE FUNCTIONS----------------------------------------------------
//====================================================================


void checkForOpen(){
   if(!ReopenOnOppositeSignal && myTrade != FLAT){
      return;
   }
   
   int signal = getSignal();
   
   if(signal == FLAT){
      return;
   }
   
   if(ReopenOnOppositeSignal && myTrade != FLAT && myTrade != signal){
      double close = myTrade == LONG ? Bid : Ask;
      
      if(!OrderSelect(0, SELECT_BY_POS, MODE_TRADES)){
         return;   
      }
      
      if(!OrderClose(myTicket, OrderLots(), close, Slippage)){
         return;
      }
      
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit > 0){
         countWinsBeforeTP++;      
      }
      else {
         countLossesBeforeSL++; 
      }
      
      myTicket = -1;
      myTrade = FLAT;
   }
   
   if(myTrade != FLAT){
      return;
   }
   
   // calculate takeProfit and stopLoss
   updateValues();
   double myLots = getLots(stopLoss);
   
   if(signal == LONG){
      openTrade(OP_BUY, "Buy Order", myLots, stopLoss, takeProfit);
   }
   else if(signal == SHORT){
      openTrade(OP_SELL, "Sell Order", myLots, stopLoss, takeProfit);
   }
   
}


void openTrade(int signal, string msg, double mLots, double mStopLoss, double mTakeProfit)
{  
   double TPprice, STprice;
   
   if (signal==OP_BUY) 
   {
      myTicket = OrderSend(_Symbol,OP_BUY,mLots,Ask,Slippage,0,0,msg,0,0,Green);
      if (myTicket > 0)
      {
         myTrade = LONG;
         if (OrderSelect(myTicket, SELECT_BY_TICKET, MODE_TRADES) ) 
         {
            TPprice = Ask + mTakeProfit*Point;
            STprice = Ask - mStopLoss*Point;
            // Normalize stoploss / takeprofit to the proper # of digits.
            if (Digits > 0)
            {
              STprice = NormalizeDouble( STprice, Digits);
              TPprice = NormalizeDouble( TPprice, Digits); 
            }
		      if(!OrderModify(myTicket, OrderOpenPrice(), STprice, TPprice,0, LightGreen)){
               Print("OrderModify error ",GetLastError());
               return;
		      }
		   }
         
      }
   }
   else if (signal == OP_SELL) 
   {
      myTicket = OrderSend(_Symbol,OP_SELL,mLots,Bid,Slippage,0,0,msg,0,0,Red);
      if (myTicket > 0)
      {
         myTrade = SHORT;
         if (OrderSelect(myTicket,SELECT_BY_TICKET, MODE_TRADES) ) 
         {
            TPprice=Bid - mTakeProfit*Point;
            STprice = Bid + mStopLoss*Point;
            // Normalize stoploss / takeprofit to the proper # of digits.
            if (Digits > 0) 
            {
              STprice = NormalizeDouble( STprice, Digits);
              TPprice = NormalizeDouble( TPprice, Digits); 
            }
		      
		      if(!OrderModify(myTicket, OrderOpenPrice(), STprice, TPprice,0, LightGreen)){
               Print("OrderModify error ",GetLastError());
               return;
		      }
         }
       }
   }
}


// update myTicket and myTrade
void checkTicket(){
   myTicket = -1;
   myTrade = FLAT;
   if(OrdersTotal() >= 1){
      if(!OrderSelect(0, SELECT_BY_POS, MODE_TRADES)){
         return;   
      }
      int oType = OrderType();
      if(oType == OP_BUY){
         myTicket = OrderTicket();
         myTrade = LONG;   
      }
      else if(oType == OP_SELL){
         myTicket = OrderTicket();
         myTrade = SHORT;
      }
   }
}


//====================================================================
// AUXILIAR FUNCTIONS-------------------------------------------------
//====================================================================

void updateValues(){
   HideTestIndicators(true);
   myATR = iATR(NULL, 0, ATRPeriod, 1)/Point;
   HideTestIndicators(false);
   takeProfit = myATR * TakeProfitPercent/100.0;
   stopLoss = myATR * StopLossPercent/100.0;    
}

void updateBacktestResults()
{
   countTP = 0;
   countSL = 0;
   int total = OrdersHistoryTotal();
   for(int i = 0; i < total; i++){
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) == false){
         Print("Access to history failed with error (",GetLastError(),")");
         break;
      }
      
      if(OrderType() == OP_BUY || OrderType() == OP_SELL){
         if((OrderProfit()+OrderSwap()+OrderCommission()) > 0){
            countTP++;
         }
         else {
            countSL++;
         }
      }
   }
   
   countTP = countTP - countWinsBeforeTP;
   countSL = countSL - countLossesBeforeSL;
}

double getNNFXWinrate(){
   double divisor = (countTP + countSL);
   return divisor == 0 ? 0 : ((countTP)*100)/ divisor;
}

double getEstimatedWinrate(){
   double divisor = countTP + countSL + (countWinsBeforeTP + countLossesBeforeSL) / 2;
   return divisor == 0 ? 0 : (countTP + (countWinsBeforeTP / 2)) * 100 / divisor;
}


double getLots(double StopInPips){   
   double minLot = MarketInfo(_Symbol, MODE_MINLOT);
   double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
 
   double divisor = (tickValue * StopInPips);
   if(divisor == 0.0){
      return minLot;   
   }

   double maxLot = MarketInfo(_Symbol, MODE_MAXLOT);
   double lotStep = MarketInfo(_Symbol, MODE_LOTSTEP);
   int decimals = 0;
   if(lotStep == 0.1){
      decimals = 1;
   }
   else if(lotStep == 0.01){
      decimals = 2;
   }

   if(Point == 0.001 || Point == 0.00001){ 
      divisor *= 10;
   }

   double lot = (AccountBalance() * (RiskPercent/100)) / divisor;
   lot = StrToDouble(DoubleToStr(lot, decimals));
   
   if (lot < minLot){ 
      lot = minLot;
   }
   if (lot > maxLot){ 
      lot = maxLot;
   }

   return lot;
}

double iCustomArray(string symbol, int timeframe, string indicator, double &params[], int mode, int shift){
   int len = ArraySize(params);
   if(len == 0){
      return iCustom(symbol, timeframe, indicator, mode, shift);   
   }
   else if(len == 1){
      return iCustom(symbol, timeframe, indicator, params[0], mode, shift);   
   }
   else if(len == 2){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], mode, shift);   
   }
   else if(len == 3){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], mode, shift);   
   }
   else if(len == 4){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], mode, shift);   
   }
   else if(len == 5){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], mode, shift);   
   }
   else if(len == 6){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], mode, shift);   
   }
   else if(len == 7){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], params[6], mode, shift);   
   }
   else if(len == 8){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], mode, shift);   
   }
   else if(len == 9){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], mode, shift);   
   }
   else if(len == 10){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], params[9], mode, shift);   
   }
   else if(len == 11){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], params[9], params[10], mode, shift);   
   }
   else if(len >= 12){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], params[9], params[10], params[11], mode, shift);   
   }
   return 0;
}


//BREAK PARAMETER STRING INTO ARRAY

void prepareC1Parameters(const string params, string &parts[]){
   ushort u_sep = StringGetCharacter(",", 0);
   StringSplit(C1IndicatorParams, u_sep, parts);
   int k = ArraySize(parts);
   int i = 0;
   while(i < k){
      parts[i] = StringTrimLeft(StringTrimRight(parts[i]));
      i++;  
   }
}

void prepareC2Parameters(const string params, string &parts[]){
   ushort u_sep = StringGetCharacter(",", 0);
   StringSplit(C2IndicatorParams, u_sep, parts);
   int k = ArraySize(parts);
   int i = 0;
   while(i < k){
      parts[i] = StringTrimLeft(StringTrimRight(parts[i]));
      i++;  
   }
}
//BREAK PARAMETER STRING INTO ARRAY

void parseC1ParametersDouble(string &params[], double &C1indParams[], int maxsize = NULL){
   int k = ArraySize(C1Params);
   if(maxsize != NULL && maxsize < k){
      k = maxsize;
   }
   ArrayResize(C1indParams, k);
   for(int i = 0; i < k; i++){
      parseDouble(C1Params[i], C1indParams[i]);   
   }
}


void parseC2ParametersDouble(string &params[], double &C2indParams[], int maxsize = NULL){
   int k = ArraySize(C2Params);
   if(maxsize != NULL && maxsize < k){
      k = maxsize;
   }
   ArrayResize(C2indParams, k);
   for(int i = 0; i < k; i++){
      parseDouble(C2Params[i], C2indParams[i]);   
   }
}


//NO EDIT REQUIRED

void parseDouble(string val, double &var, double def = 0){
   if(StringGetChar(val, 0) == '#' && StringGetChar(val, 1) >= '1' && StringGetChar(val, 1) <= '8'){
      parseInput(val, var);
      return;
   }
   var = StrToDouble(val);
}

void parseColor(string val, color &var, color def = 0){
   var = StringToColor(val);
}

void parseBool(string val, bool &var, bool def = false){
   if(val == "1" || val == "true"){
      var = true;   
   }
   else if(val == "0" || val == "false"){
      var = false;
   }
   else {
      var = def;
   }
}

void parseInput(string val, double &var){
   int idx = StrToInteger(StringSubstr(val, 1, 1));
   switch(idx){
      case 1:
         var = Input1;
         break;
      case 2:
         var = Input2;
         break;
      case 3:
         var = Input3;
         break;
      case 4:
         var = Input4;
         break;
      case 5:
         var = Input5;
         break;
      case 6:
         var = Input6;
         break;
      case 7:
         var = Input7;
         break;
      case 8:
         var = Input8;
         break;                                     
   }
}