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

// Global Variables and Objects
CTrade trade;
int magicNumber = 12345;  // Magic number for trade identification
int    minFVGPoints     = 100;  // Minimum points for FVG detection
int    FVG_ExtensionBars = 30;