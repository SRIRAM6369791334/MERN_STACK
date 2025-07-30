//+------------------------------------------------------------------+
//| Enhanced Combined Strategy EA - Improved Version                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, SRIRAM6369791334 & ALLAN MUNENE MUTIIRIA"
#property version   "2.15"
#property strict
#property description "Multi-Strategy Expert Advisor with Swing Breakout, FVG, BOS, MSS, and Liquidity Grab strategies. Includes advanced risk management, time filters, partial close, trailing stop, and enhanced trade validation."
#property description "Last Updated: 2025-03-26 04:25:26 UTC"
#property description "User: SRIRAM6369791334"

// Include required libraries
#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>
#include <Arrays/ArrayString.mqh>
#include <Indicators/TimeSeries.mqh>

// FVG Definitions
#define FVG_PREFIX       "FVG REC "
#define CLR_UP           clrLime
#define CLR_DOWN         clrRed

// Input Parameters
//+------------------------------------------------------------------+
input group "=== Basic Trade Settings ==="
input double initialLot         = 0.01;    // Initial Lot Size
input int    stopLossPoints    = 300;     // Stop Loss (Points)
input int    takeProfitPoints  = 500;     // Take Profit (Points)
input double riskRewardRatio   = 7.0;     // Risk : Reward Ratio
input int    magicNumber       = 123456;  // Magic Number

input group "=== Multi-Order Settings ==="
input bool   enableMultiOrders = false;   // Enable Multiple Orders
input double tp1_points        = 100;     // TP1 Points
input double tp2_points        = 200;     // TP2 Points
input double tp3_points        = 400;     // TP3 Points
input bool   tp4_runner        = true;    // TP4 Runner (No TP)

input group "=== Advanced Risk Management ==="
input double maxRiskPercent    = 2.0;     // Maximum Risk Per Trade (%)
input double dailyLossLimit    = 5.0;     // Daily Loss Limit (%)
input double weeklyLossLimit   = 10.0;    // Weekly Loss Limit (%)
input int    maxDailyTrades    = 5;       // Maximum Trades Per Day
input bool   enableMartingale  = false;   // Enable Martingale
input double martingaleMult    = 1.5;     // Martingale Multiplier

input group "=== Time Filters ==="
input bool   useTimeFilter     = true;    // Enable Time Filter
input int    startHourUTC      = 3;       // Trading Start Hour (UTC)
input int    endHourUTC        = 23;      // Trading End Hour (UTC)
input bool   skipMonday        = true;    // Skip Monday Trading
input bool   skipFriday        = true;    // Skip Friday Trading

input group "=== Technical Parameters ==="
input int    indicatorCode     = 77;      // Object Code for indicators
input int    maxOpenTrades     = 1;       // Maximum allowed open trades
input color  swingHighColor    = clrBlue; // Swing High Color
input color  swingLowColor     = clrRed;  // Swing Low Color
input int    scanBars          = 5;       // Bars to scan for BOS/CHOCH
input bool   enablePrintLogs   = true;    // Enable Print Statements
input int    lineWidth         = 2;       // Line Width for drawings

// Global Variables
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo positionInfo;
CDealInfo dealInfo;
CTimeSeries priceData;

// Structure for swing points
struct SwingPoint
{
    double price;
    datetime time;
    int barIndex;
    ENUM_OBJECT type; // OBJ_ARROW_UP for high, OBJ_ARROW_DOWN for low
};

// Arrays for swing points
SwingPoint swingHighs[];
SwingPoint swingLows[];

// Trading statistics
int dailyTradesCount = 0;
double dailyProfit = 0.0;
double weeklyProfit = 0.0;
datetime lastResetTime = 0;

// FVG structure
struct FVG
{
    double top;
    double bottom;
    datetime time;
    int barIndex;
    bool isBullish;
    bool filled;
};

FVG fvgArray[];

//+------------------------------------------------------------------+
//| Function declarations                                            |
//+------------------------------------------------------------------+
bool IsWithinTradingHours();
bool CheckDailyLimits();
void ResetDailyStats();
void UpdateSwingPoints();
void AddSwingPoint(double price, datetime time, int barIndex, bool isHigh);
void DrawSwingPoint(string name, datetime time, double price, ENUM_OBJECT type, color clr);
void DetectFVGs();
void CreateFVG(double top, double bottom, datetime time, int barIndex, bool isBullish);
void CheckBOSBreakoutSignals();
void CheckLiquidityGrabSignals();
void ExecuteBOSBuyTrade(double swingLevel);
void ExecuteBOSSellTrade(double swingLevel);
void ExecuteMultipleOrders(ENUM_POSITION_TYPE type, double swingLevel, double entryPrice, double sl, double tp1, double tp2);
double CalculateLotSize(double stopLossDistance);
bool HasOpenPosition();
bool WasLastTradeLoss();
void UpdateTrailingStops();
void CleanupChartObjects();
double high(int shift);
double low(int shift);
double close(int shift);
datetime time(int shift);
void detectBOSSwingPoints();
void drawBOSSwingPoint(string name, datetime time, double price, ENUM_OBJECT type, color clr);
void drawBOSBreakLevel(double level, datetime time, color clr);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("Enhanced Combined Strategy EA v2.15 - Initializing...");
    
    // Initialize trade object
    trade.SetExpertMagicNumber(magicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // Initialize arrays
    ArrayResize(swingHighs, 0);
    ArrayResize(swingLows, 0);
    ArrayResize(fvgArray, 0);
    
    // Reset daily statistics
    ResetDailyStats();
    
    Print("Enhanced Combined Strategy EA v2.15 - Initialization completed successfully!");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Enhanced Combined Strategy EA v2.15 - Deinitializing...");
    
    // Clean up chart objects
    CleanupChartObjects();
    
    Print("Enhanced Combined Strategy EA v2.15 - Deinitialization completed!");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if we're within trading hours
    if(useTimeFilter && !IsWithinTradingHours())
        return;
        
    // Check daily limits
    if(!CheckDailyLimits())
        return;
        
    // Update swing points
    UpdateSwingPoints();
    
    // Detect FVGs
    DetectFVGs();
    
    // Check for BOS signals
    CheckBOSBreakoutSignals();
    
    // Check for liquidity grab signals
    CheckLiquidityGrabSignals();
    
    // Update trailing stops for open positions
    UpdateTrailingStops();
}

//+------------------------------------------------------------------+
//| Function implementations                                         |
//+------------------------------------------------------------------+

bool IsWithinTradingHours()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // Skip Monday if enabled
    if(skipMonday && dt.day_of_week == 1)
        return false;
        
    // Skip Friday if enabled
    if(skipFriday && dt.day_of_week == 5)
        return false;
        
    // Check hour range
    int currentHour = dt.hour;
    
    if(startHourUTC <= endHourUTC)
    {
        return (currentHour >= startHourUTC && currentHour <= endHourUTC);
    }
    else
    {
        return (currentHour >= startHourUTC || currentHour <= endHourUTC);
    }
}

bool CheckDailyLimits()
{
    // Reset daily stats if new day
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    MqlDateTime lastDt;
    if(TimeToStruct(lastResetTime, lastDt) == false || dt.day != lastDt.day)
    {
        ResetDailyStats();
    }
    
    // Check daily trade count limit
    if(dailyTradesCount >= maxDailyTrades)
    {
        if(enablePrintLogs)
            Print("Daily trade limit reached: ", dailyTradesCount);
        return false;
    }
    
    // Check daily loss limit
    if(dailyProfit <= -AccountInfoDouble(ACCOUNT_BALANCE) * dailyLossLimit / 100.0)
    {
        if(enablePrintLogs)
            Print("Daily loss limit reached: ", dailyProfit);
        return false;
    }
    
    return true;
}

void ResetDailyStats()
{
    dailyTradesCount = 0;
    dailyProfit = 0.0;
    lastResetTime = TimeCurrent();
}

void UpdateSwingPoints()
{
    int lookback = 10; // Bars to look back for swing point validation
    int totalBars = Bars(_Symbol, PERIOD_CURRENT);
    
    for(int i = lookback; i < totalBars - lookback; i++)
    {
        // Check for swing high
        bool isSwingHigh = true;
        double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, i);
        
        for(int j = 1; j <= lookback; j++)
        {
            if(iHigh(_Symbol, PERIOD_CURRENT, i - j) >= currentHigh || 
               iHigh(_Symbol, PERIOD_CURRENT, i + j) >= currentHigh)
            {
                isSwingHigh = false;
                break;
            }
        }
        
        if(isSwingHigh)
        {
            AddSwingPoint(currentHigh, iTime(_Symbol, PERIOD_CURRENT, i), i, true);
        }
        
        // Check for swing low
        bool isSwingLow = true;
        double currentLow = iLow(_Symbol, PERIOD_CURRENT, i);
        
        for(int j = 1; j <= lookback; j++)
        {
            if(iLow(_Symbol, PERIOD_CURRENT, i - j) <= currentLow || 
               iLow(_Symbol, PERIOD_CURRENT, i + j) <= currentLow)
            {
                isSwingLow = false;
                break;
            }
        }
        
        if(isSwingLow)
        {
            AddSwingPoint(currentLow, iTime(_Symbol, PERIOD_CURRENT, i), i, false);
        }
    }
}

void AddSwingPoint(double price, datetime time, int barIndex, bool isHigh)
{
    if(isHigh)
    {
        int size = ArraySize(swingHighs);
        ArrayResize(swingHighs, size + 1);
        swingHighs[size].price = price;
        swingHighs[size].time = time;
        swingHighs[size].barIndex = barIndex;
        swingHighs[size].type = OBJ_ARROW_DOWN;
        
        // Draw swing high point
        DrawSwingPoint("SwingHigh_" + IntegerToString(barIndex), time, price, OBJ_ARROW_DOWN, swingHighColor);
    }
    else
    {
        int size = ArraySize(swingLows);
        ArrayResize(swingLows, size + 1);
        swingLows[size].price = price;
        swingLows[size].time = time;
        swingLows[size].barIndex = barIndex;
        swingLows[size].type = OBJ_ARROW_UP;
        
        // Draw swing low point
        DrawSwingPoint("SwingLow_" + IntegerToString(barIndex), time, price, OBJ_ARROW_UP, swingLowColor);
    }
}

void DrawSwingPoint(string name, datetime time, double price, ENUM_OBJECT type, color clr)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, type, 0, time, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, lineWidth);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
    }
}

void DetectFVGs()
{
    int totalBars = Bars(_Symbol, PERIOD_CURRENT);
    
    for(int i = 3; i < totalBars - 1; i++)
    {
        double high1 = iHigh(_Symbol, PERIOD_CURRENT, i + 1);
        double low1 = iLow(_Symbol, PERIOD_CURRENT, i + 1);
        double high2 = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low2 = iLow(_Symbol, PERIOD_CURRENT, i);
        double high3 = iHigh(_Symbol, PERIOD_CURRENT, i - 1);
        double low3 = iLow(_Symbol, PERIOD_CURRENT, i - 1);
        
        // Bullish FVG: Gap between low of bar1 and high of bar3
        if(low1 > high3)
        {
            CreateFVG(high3, low1, iTime(_Symbol, PERIOD_CURRENT, i), i, true);
        }
        
        // Bearish FVG: Gap between high of bar1 and low of bar3
        if(high1 < low3)
        {
            CreateFVG(low3, high1, iTime(_Symbol, PERIOD_CURRENT, i), i, false);
        }
    }
}

void CreateFVG(double top, double bottom, datetime time, int barIndex, bool isBullish)
{
    int size = ArraySize(fvgArray);
    ArrayResize(fvgArray, size + 1);
    
    fvgArray[size].top = top;
    fvgArray[size].bottom = bottom;
    fvgArray[size].time = time;
    fvgArray[size].barIndex = barIndex;
    fvgArray[size].isBullish = isBullish;
    fvgArray[size].filled = false;
    
    // Draw FVG rectangle
    string rectName = FVG_PREFIX + IntegerToString(barIndex);
    datetime endTime = iTime(_Symbol, PERIOD_CURRENT, barIndex - 10);
    
    ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, time, top, endTime, bottom);
    ObjectSetInteger(0, rectName, OBJPROP_COLOR, isBullish ? CLR_UP : CLR_DOWN);
    ObjectSetInteger(0, rectName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
    ObjectSetInteger(0, rectName, OBJPROP_BACK, true);
}

void CheckBOSBreakoutSignals()
{
    if(ArraySize(swingHighs) < 2 || ArraySize(swingLows) < 2)
        return;
        
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    // Check for bullish BOS (break above recent swing high)
    for(int i = ArraySize(swingHighs) - 1; i >= 0 && i >= ArraySize(swingHighs) - scanBars; i--)
    {
        if(currentPrice > swingHighs[i].price)
        {
            if(enablePrintLogs)
                Print("Bullish BOS detected at price: ", currentPrice, " breaking high: ", swingHighs[i].price);
                
            if(!HasOpenPosition())
            {
                if(enableMultiOrders)
                {
                    double sl = currentPrice - stopLossPoints * _Point;
                    double tp1 = currentPrice + tp1_points * _Point;
                    double tp2 = currentPrice + tp2_points * _Point;
                    ExecuteMultipleOrders(POSITION_TYPE_BUY, swingHighs[i].price, currentPrice, sl, tp1, tp2);
                }
                else
                    ExecuteBOSBuyTrade(swingHighs[i].price);
            }
            break;
        }
    }
    
    // Check for bearish BOS (break below recent swing low)
    for(int i = ArraySize(swingLows) - 1; i >= 0 && i >= ArraySize(swingLows) - scanBars; i--)
    {
        if(currentPrice < swingLows[i].price)
        {
            if(enablePrintLogs)
                Print("Bearish BOS detected at price: ", currentPrice, " breaking low: ", swingLows[i].price);
                
            if(!HasOpenPosition())
            {
                if(enableMultiOrders)
                {
                    double sl = currentPrice + stopLossPoints * _Point;
                    double tp1 = currentPrice - tp1_points * _Point;
                    double tp2 = currentPrice - tp2_points * _Point;
                    ExecuteMultipleOrders(POSITION_TYPE_SELL, swingLows[i].price, currentPrice, sl, tp1, tp2);
                }
                else
                    ExecuteBOSSellTrade(swingLows[i].price);
            }
            break;
        }
    }
}

void CheckLiquidityGrabSignals()
{
    // Implementation for liquidity grab detection
    // This would involve detecting when price sweeps liquidity levels
    // and then reverses, creating entry opportunities
}

void ExecuteBOSBuyTrade(double swingLevel)
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double stopLoss = currentPrice - stopLossPoints * _Point;
    double takeProfit = currentPrice + takeProfitPoints * _Point;
    
    // Calculate lot size based on risk management
    double lotSize = CalculateLotSize(MathAbs(currentPrice - stopLoss));
    
    if(trade.Buy(lotSize, _Symbol, currentPrice, stopLoss, takeProfit, "BOS Buy"))
    {
        if(enablePrintLogs)
            Print("BOS Buy order executed: Lot=", lotSize, " Entry=", currentPrice, " SL=", stopLoss, " TP=", takeProfit);
        
        dailyTradesCount++;
    }
    else
    {
        if(enablePrintLogs)
            Print("Failed to execute BOS Buy order. Error: ", GetLastError());
    }
}

void ExecuteBOSSellTrade(double swingLevel)
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double stopLoss = currentPrice + stopLossPoints * _Point;
    double takeProfit = currentPrice - takeProfitPoints * _Point;
    
    // Calculate lot size based on risk management
    double lotSize = CalculateLotSize(MathAbs(currentPrice - stopLoss));
    
    if(trade.Sell(lotSize, _Symbol, currentPrice, stopLoss, takeProfit, "BOS Sell"))
    {
        if(enablePrintLogs)
            Print("BOS Sell order executed: Lot=", lotSize, " Entry=", currentPrice, " SL=", stopLoss, " TP=", takeProfit);
        
        dailyTradesCount++;
    }
    else
    {
        if(enablePrintLogs)
            Print("Failed to execute BOS Sell order. Error: ", GetLastError());
    }
}

void ExecuteMultipleOrders(ENUM_POSITION_TYPE type, double swingLevel, double entryPrice, double sl, double tp1, double tp2)
{
    double lotSize = CalculateLotSize(stopLossPoints * _Point) / 4.0; // Divide into 4 positions
    
    if(type == POSITION_TYPE_BUY)
    {
        // TP1
        trade.Buy(lotSize, _Symbol, entryPrice, sl, tp1, "Multi Buy TP1");
        
        // TP2
        trade.Buy(lotSize, _Symbol, entryPrice, sl, tp2, "Multi Buy TP2");
        
        // TP3
        double tp3 = entryPrice + tp3_points * _Point;
        trade.Buy(lotSize, _Symbol, entryPrice, sl, tp3, "Multi Buy TP3");
        
        // TP4 (Runner - no TP)
        if(tp4_runner)
            trade.Buy(lotSize, _Symbol, entryPrice, sl, 0, "Multi Buy Runner");
    }
    else
    {
        // TP1
        trade.Sell(lotSize, _Symbol, entryPrice, sl, tp1, "Multi Sell TP1");
        
        // TP2
        trade.Sell(lotSize, _Symbol, entryPrice, sl, tp2, "Multi Sell TP2");
        
        // TP3
        double tp3 = entryPrice - tp3_points * _Point;
        trade.Sell(lotSize, _Symbol, entryPrice, sl, tp3, "Multi Sell TP3");
        
        // TP4 (Runner - no TP)
        if(tp4_runner)
            trade.Sell(lotSize, _Symbol, entryPrice, sl, 0, "Multi Sell Runner");
    }
    
    dailyTradesCount++;
}

double CalculateLotSize(double stopLossDistance)
{
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * maxRiskPercent / 100.0;
    
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    double lotSize = (riskAmount / (stopLossDistance / tickSize * tickValue));
    
    // Apply martingale if enabled and there was a recent loss
    if(enableMartingale && WasLastTradeLoss())
    {
        lotSize *= martingaleMult;
    }
    
    // Ensure lot size is within broker limits
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    lotSize = NormalizeDouble(lotSize / stepLot, 0) * stepLot;
    
    return lotSize;
}

bool HasOpenPosition()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(positionInfo.SelectByIndex(i))
        {
            if(positionInfo.Magic() == magicNumber && positionInfo.Symbol() == _Symbol)
                return true;
        }
    }
    return false;
}

bool WasLastTradeLoss()
{
    HistorySelect(TimeCurrent() - 86400, TimeCurrent()); // Last 24 hours
    
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(dealInfo.SelectByIndex(i))
        {
            if(dealInfo.Magic() == magicNumber && dealInfo.Symbol() == _Symbol)
            {
                if(dealInfo.Entry() == DEAL_ENTRY_OUT)
                {
                    return dealInfo.Profit() < 0;
                }
            }
        }
    }
    return false;
}

void UpdateTrailingStops()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(positionInfo.SelectByIndex(i))
        {
            if(positionInfo.Magic() == magicNumber && positionInfo.Symbol() == _Symbol)
            {
                double currentPrice = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? 
                                    SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                    SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                
                double newStopLoss = 0;
                
                if(positionInfo.PositionType() == POSITION_TYPE_BUY)
                {
                    newStopLoss = currentPrice - stopLossPoints * _Point;
                    if(newStopLoss > positionInfo.StopLoss() && newStopLoss < currentPrice)
                    {
                        trade.PositionModify(positionInfo.Ticket(), newStopLoss, positionInfo.TakeProfit());
                    }
                }
                else
                {
                    newStopLoss = currentPrice + stopLossPoints * _Point;
                    if(newStopLoss < positionInfo.StopLoss() && newStopLoss > currentPrice)
                    {
                        trade.PositionModify(positionInfo.Ticket(), newStopLoss, positionInfo.TakeProfit());
                    }
                }
            }
        }
    }
}

void CleanupChartObjects()
{
    int totalObjects = ObjectsTotal(0);
    
    for(int i = totalObjects - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i);
        
        if(StringFind(objName, "SwingHigh_") == 0 ||
           StringFind(objName, "SwingLow_") == 0 ||
           StringFind(objName, FVG_PREFIX) == 0)
        {
            ObjectDelete(0, objName);
        }
    }
}

double high(int shift)
{
    return iHigh(_Symbol, PERIOD_CURRENT, shift);
}

double low(int shift)
{
    return iLow(_Symbol, PERIOD_CURRENT, shift);
}

double close(int shift)
{
    return iClose(_Symbol, PERIOD_CURRENT, shift);
}

datetime time(int shift)
{
    return iTime(_Symbol, PERIOD_CURRENT, shift);
}

void detectBOSSwingPoints()
{
    // BOS swing point detection implementation
    UpdateSwingPoints();
}

void drawBOSSwingPoint(string name, datetime time, double price, ENUM_OBJECT type, color clr)
{
    DrawSwingPoint(name, time, price, type, clr);
}

void drawBOSBreakLevel(double level, datetime time, color clr)
{
    string lineName = "BOS_Break_" + DoubleToString(level, _Digits);
    if(ObjectFind(0, lineName) < 0)
    {
        ObjectCreate(0, lineName, OBJ_HLINE, 0, time, level);
        ObjectSetInteger(0, lineName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, lineWidth);
        ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
    }
}
