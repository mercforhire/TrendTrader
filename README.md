# TrendTrader
Automated trading bot based off AbleTrend signals and operates on NinjaTrader

▪ Desktop Mac OS application written in Swift controlling NinjaTrader platform
▪ Developed a fully automated algorithmic trading system for Futures
▪ Systematic trend-following intraday trading strategy
▪ Delivers market-neutral, crash-resistant returns
▪ Fixed income, no overnight risk, great for hedging against buy-and-hold

Backtest results:
https://docs.google.com/spreadsheets/d/1_O3pII3iIckitnxLBjt5o9wDkxzI6wzOwnnzA6nGnv4/edit?usp=sharing

Backtest results are based on trading 1 NQ Futures contract
Results are generated from historical chart data with indicators. 
All signals generated are final and do not "forward-look" AKA cheat.
Different models have different risk parameter settings as pictured in the screenshot of the Config page.
Real life results will differ from backtest results due to slippage. 
Real time trading decisions have a 4-5 seconds delay from the close of the previous minute tick, which is used as the ideal entry price in backtest. 
All stop-loss exits are assumed to exit precisely on the set price in backtest results. 

3 Models: 
Optimized - Same setting as Balanced except does not trade on Fridays, Friday's performance has been consistently bad since Febuary
Conservative - Optimal settings with highest P/L and sustainable max drawdown, allow small amount of losing trades before halting for the day
Risker - Less restrictive settings, giving it chance for a losing day to bounce back

'Optimized' is the best model so far, this could change with more data. Will adjust to the best model from time to time as time progresses.
