//+------------------------------------------------------------------+
//| Enhanced Combined Strategy EA - Fixed Version                      |
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
input int    lineWidth         = 2;       // Object drawing width
input int    textFontSize      = 10;      // Font Size for text objects

input group "=== BOS Strategy Settings ==="
input bool   enableBOSStrategy = true;    // Enable BOS Breakout Strategy
input int    bosSwingLength    = 20;      // BOS Swing Detection Length
input int    bosLimit          = 20;      // BOS Analysis Limit
input bool   enableBOSVisuals  = true;    // Enable BOS Visual Indicators
input color  bosBreakColor     = clrYellow; // BOS Break Level Color

input group "=== Enhanced Validation Settings ==="
input bool   enableEnhancedValidation = true; // Enable Enhanced Trade Validation
input bool   enableAutoRectification = true;  // Enable Automatic Price Rectification

input group "=== Partial Close Settings ==="
input bool   enablePartialClose = true;    // Enable Partial Close
input int    partialClosePoints = 100;     // Partial Close Points
input double partialCloseAmount = 0.03;    // Partial Close Lot Reduction

input group "=== Trailing Stop Settings ==="
input bool   enableTrailingStop = true;    // Enable Trailing Stop
input double initialTrailingPoints = 300;  // Initial Trailing Stop Points
input double trailingStepBuy = 4.0;       // Trailing Step for Buy Orders (points)
input double trailingStepSell = 4.0;      // Trailing Step for Sell Orders (points)
input double slShiftAfterPartial = 0.1;   // SL Shift After Partial Close (points)

input group "=== Signal Threshold Settings ==="
input int    conditionsToTrade = 3;       // Minimum conditions to trigger trade
input double BreakEven_After_Pts = 150; // Points after which to set break-even
input double BreakEven_At_Pts = 50;     // Points to set the break-even stop loss

input group "=== FVG Strategy Settings ==="
input bool   enableFVGStrategy = true;    // Enable FVG Strategy
input int    fvgMinPoints     = 100;      // Minimum FVG Points
input int    fvgExtensionBars = 30;       // FVG Extension Bars
input bool   enableFVGVisuals = true;     // Enable FVG Visual Indicators
input bool   enableFVGUpdates = true;     // Enable Dynamic FVG Updates
input bool   enableFVGTrading = true;     // Enable FVG Trading Signals
input color  fvgUpColor       = clrLime;  // FVG Up Color
input color  fvgDownColor     = clrRed;   // FVG Down Color

input group "=== MSS (Market Structure Shift) Settings ==="
input bool   enableMSS = true;           // Enable MSS Detection
input int    mssSwingLength = 10;        // MSS Swing Detection Length
input color  mssUpColor = clrDarkGreen;  // MSS Uptrend Color
input color  mssDownColor = clrBlack;    // MSS Downtrend Color
input int    mssLineWidth = 4;           // MSS Line Width
input int    mssFontSize = 13;           // MSS Font Size

input group "=== Liquidity Grab Strategy Settings ==="
input bool   enableLiquidityGrab = true;    // Enable Liquidity Grab Strategy
input double wickToBodyRatio = 4.0;         // Wick to Body Ratio for Rejection
input int    candlesBeforeBreakout = 20;    // Candles Before Breakout Check
input int    maPeriods = 200;               // MA Periods for Filter
input int    distanceRange = 100;           // Distance Range for Key Levels
input int    barsN = 3;                     // Bars N for Key Level Detection
input int    startHour1 = 13;               // First Trading Session Start Hour
input int    endHour1 = 14;                 // First Trading Session End Hour
input int    startHour2 = 17;               // Second Trading Session Start Hour
input int    endHour2 = 19;                 // Second Trading Session End Hour

// Global Variables and Objects
CTrade trade;
int    minFVGPoints     = 100;  // Minimum points for FVG detection
int    FVG_ExtensionBars = 30;
string fvgNames[];
datetime fvgBarTimes[];
bool   fvgSignals[];

// Enhanced FVG Variables
string totalFVGs[];
int barINDICES[];
datetime barTIMES[];
bool signalFVGs[];
bool fvgInitialized = false;

// MSS Arrays
static double swingHighs_Array[2];
static double swingLows_Array[2];
static int swingHighs_Size = 0;
static int swingLows_Size = 0;

// Global Variables for Swing Points and Structure
static double swingHigh = -1.0;
static double swingLow  = -1.0;

// BOS Strategy Variables
static double bosSwingHigh = -1.0;
static double bosSwingLow = -1.0;
static bool bosBreakoutActive = false;

// Global Risk Management Variables
datetime lastTradeTime = 0;
int      dailyTradeCount = 0;
double   dailyProfitLoss = 0.0;
double   weeklyProfitLoss= 0.0;
datetime lastDailyReset = 0;
datetime lastWeeklyReset= 0;

// Liquidity Grab Variables
static int handleMa = INVALID_HANDLE;
static ulong buypos = 0, sellpos = 0;
static int barsTotal = 0;

//+------------------------------------------------------------------+
//| Helper Functions                                                  |
//+------------------------------------------------------------------+
double high(int index) { return (iHigh(_Symbol, PERIOD_CURRENT, index)); }
double low(int index) { return (iLow(_Symbol, PERIOD_CURRENT, index)); }
double close(int index) { return (iClose(_Symbol, PERIOD_CURRENT, index)); }
datetime time(int index) { return (iTime(_Symbol, PERIOD_CURRENT, index)); }