/*******************************************************************************
								XXX TASK
		
		- Author:  Gabriella Wong
		- Last update: Jul 07
		- Windows version
		- Worked on Stata 18
*******************************************************************************/

*******************Prepping Stata
clear all 
set more off

global root "C:\Users\lenovo\Desktop\CAH Task"
global raw "$root\0_raw"
global dta "$root\1_dta"
global temp "$root\1_dta\temp"
global docs "$root\3_output"


local c_date=c(current_date)
local date=subinstr("`c_date'","","",.)


/*******************************************************************************
									IMPORT
*******************************************************************************/

* Import 

	import delimited "$raw\Data set B.csv", varnames(1) clear
		save "$dta/raw_data_b.dta", replace
			global bb "$dta/raw_data_b.dta"


	import delimited "$raw\Data set A.csv", varnames(1) clear
		save "$dta/raw_data_a.dta", replace
			global aa "$dta/raw_data_a.dta"
			
/*******************************************************************************
									CLEAN & MERGE
*******************************************************************************/

*** DATASET A ***
*****************
* Browse 

	des 

	tab condition
	tab income_level
	
* Trim unwanted spaces

	drop if identifier==.

* Doublecheck for duplicates 

	duplicates report identifier

	duplicates tag identifier, gen(dup_id)
	list if dup_id==1
	bysort identifier: gen n=_n
	drop if dup_id==1 & n==2
	drop n dup_id
	
* Encode both condition and income level
	
		tab condition
		drop if condition=="NA" // not part of randomization
	
		la def trr 1 "Recommendation" 0 "Control" , modify
		encode condition, gen(treat) label(trr)
		
		la def inc 1 "LMI" 0 "non-LMI", modify
		encode income_level, gen(inc) label(inc)
	
	
		save	"$dta/clean_data_a.dta", replace
	

*** DATASET B**	
*****************
	
	u "$bb" , clear	
		
* Browse 
	br
	des
	tab increased_contribution

* Trim unwanted spaces

	drop if identifier==.	

* Review contribution

	list if increased_contribution=="closed" 
	// I am asuming that closed mean they didn't contribute, thus it should be valued as zero later on 
	
	drop if increased_contribution=="closed" 
	
* Change str to int for inc_cont
	destring increased_contribution, replace

	
		save	"$dta/clean_data_b.dta", replace
	
	
*** MERGING DATASETS **	
*********************** 

	u "$dta/clean_data_a.dta" , clear
	merge 1:1 identifier using "$dta/clean_data_b.dta"
	drop if _merge==2 // we have to drop users that don't belong to randomization 
	drop _merge
	
* Input zero value to all users that didn't contribute 
	replace increased_contribution=0 if increased_contribution==.
	
	
	save "$dta/master_dataset.dta", replace
	
	
/*******************************************************************************
									STATS & GRAPHS
*******************************************************************************/

* Descriptive analysis 

	summ treat inc increased_contribution

	bysort treat: summ inc increased_contribution


* Option1. Bar chart 
graph bar (mean) increased_contribution, ///
    over(treat) ///
    ytitle("Proportion Contributing") ///
    title("Users Contributing by Treatment Group") ///
    blabel(bar, format(%4.2f) position(top)) ///
    legend(off)
	

* Option 2. Better bar chart
	cibar increased_contribution, over(treat) ///
	graphopts ( /// start of graphopts option
	 title("Users Contributing by Treatment Group") ///
	 ytitle(Avg. Users Increasing Contribution, col(gs8)) /// titles y-axis
	 xtitle(Treatment group, col(gs8))  /// titles x-axis
	)
	
	
	graph save "Graph" "$docs\Graph.gph", replace

/*******************************************************************************
									ANALYSIS
*******************************************************************************/

* Model 1 OLS
	reg increased_contribution treat, vce(robust)
	reg increased_contribution treat inc , vce(robust)

* Model 2 Logit // since outcome var is dichotomic
	
	logit increased_contribution treat inc, vce(robust)
	margins, dydx(*)  // to get marginal effects
	
	
	