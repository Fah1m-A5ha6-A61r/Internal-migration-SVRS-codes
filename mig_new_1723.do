/* Wealth Index */
*****************************************************
* Standardize the continuous variable
*****************************************************
egen z_exp = std(hh_exp)

*****************************************************
* Run PCA on 5 key variables
*****************************************************
pca z_exp floor_material toilet_facility zap q12_g

*****************************************************
* Predict wealth score using first component
*****************************************************
predict wealth_index_5, score

*****************************************************
* Convert to quintiles
*****************************************************
xtile wealth_quintile_5 = wealth_index_5, n(5)

label define wq 1 "Poorest" 2 "Poorer" 3 "Middle" 4 "Richer" 5 "Richest"
label values wealth_quintile_5 wq





/*----------Open SVRS17 folder, open all 4 stata files simulatanously------------*/


//Merging Popupaltion and Household data


use Taf2p.dta, clear
gen SVRS = 2017
gen caseid_t = string(SVRS) + " " + string(psu_no) + " " + string(hh_no)
save Taf2p.dta, replace

use Taf2h.dta, clear
gen SVRS = 2017
gen caseid_t = string(SVRS) + " " + string(psu_no) + " " + string(hh_no)
duplicates report caseid_t
duplicates drop caseid_t, force


* creating wealth index and quintile
gen build_mat = .
replace build_mat = 6 if (build_mat == . &   q1_1a > 0)
replace build_mat = 5 if (build_mat == . &   q1_2a > 0)
replace build_mat = 4 if (build_mat == . &   q1_3a > 0)
replace build_mat = 3 if (build_mat == . &   q1_4a > 0)
replace build_mat = 2 if (build_mat == . &   q1_5a > 0)
replace build_mat = 1 if (build_mat == . &   q1_6a > 0)
replace build_mat = 1 if build_mat == .

gen water_source = .
replace water_source = 5 if (water_source == . & q2_2 == 1)
replace water_source = 4 if (water_source == . & q2_2 == 2)
replace water_source = 3 if (water_source == . & q2_2 == 4)
replace water_source = 2 if (water_source == . & q2_2 == 5)
replace water_source = 1 if water_source == .

gen electricity = .
replace electricity = 2 if q_4 == 1
replace electricity = 1 if electricity == .

gen water_own = .
replace water_own = 2 if q_3 == 1
replace water_own = 1 if water_own == .

gen sanitary = .
replace sanitary = 4 if q_6 == 1
replace sanitary = 3 if q_6 == 2
replace sanitary = 2 if q_6 == 3
replace sanitary = 1 if sanitary == .

gen money = .
replace money = 4 if q_7 == 4
replace money = 3 if q_7 == 3
replace money = 2 if q_7 == 2
replace money = 1 if money == .

pca money build_mat water_source water_own sanitary electricity

predict wealth_index_5, score

xtile wealth_quintile_5 = wealth_index_5, n(5)

label define wq 1 "Poorest" 2 "Poorer" 3 "Middle" 4 "Richer" 5 "Richest"
label values wealth_quintile_5 wq
save Taf2h.dta, replace

use Taf2p.dta, clear
merge m:1 caseid_t using Taf2h.dta
drop if _merge==1
drop if _merge==2 
rename _merge _merge_hp
keep psu_no zila rmo hh_no q_8 q_10 q_11 q_12 q_13 q_14 q_16 q_22 q_3 q_5 q_6 q_7 _merge_hp SVRS caseid_t wealth_quintile_5
gen caseid = string(SVRS) + " " + string(psu_no) + " " + string(hh_no) + " " + string(q_8)
duplicates report caseid
duplicates drop caseid, force
save Taf2.dta, replace


//---Merging unique cases of Taf7 and Taf8 with Taf2 (Important)---//


use Taf8.dta, clear
gen SVRS = 2017
gen caseid = string(SVRS) + " " + string(psu_no) + " " + string(hh_no) + " " + string(line_no)
duplicates report caseid
duplicates drop caseid, force

replace q_6 = q_6 + 100 if q_5 == 4

rename q_4 H4
rename q_5 H5
rename q_6 H6
rename q_7m H7M
rename q_8 H8
keep H4 H5 H6 H7M H8 caseid
save Taf8.dta, replace

use Taf7.dta, clear
gen SVRS = 2017
gen caseid = string(SVRS) + " " + string(psu_no) + " " + string(hh_no) + " " + string(line_no)
duplicates report caseid
duplicates drop caseid, force

replace q_5 = q_5 + 100 if q_4 == 4

rename q_4 G4
rename q_5 G5
rename q_6 G6
rename q_7m G7M
rename q_8 G8
keep G4 G5 G6 G7M G8 caseid
save Taf7.dta, replace

//Start Merging
//In_Mig (Taf2+Taf8)
use Taf2.dta,clear
merge 1:1 caseid using Taf8.dta
drop if _merge==2
gen tafsil=.
replace tafsil=8 if _merge==3
save In_Mig.dta,replace

//uniuqe Out_Mig (Taf7+Taf8)
use Taf7.dta,clear
merge 1:1 caseid using Taf8.dta
drop if inrange( _merge, 2, 3 )
rename G4 gg4
rename G5 gg5
rename G6 g6
rename G7M g7
rename G8 g8
label variable gg4 "gg4.migrated to which area"
label variable gg5 "gg5.migrated to which district"
keep caseid gg4 gg5 g6 g7 g8
save Out_Mig.dta,replace

//final_merge (In_Mig + Out_Mig)
use In_Mig.dta,replace
rename H4 h4
rename H5 h5
rename H6 h6
rename H7M h7
rename H8 h8
label variable h4 "h4.reason of migration"
label variable h5 "h5.migrated from which area"
label variable h6 "h6.migrated from which district"
label variable h7 "h7.month of migration"
label variable h8 "h8.migration type"
rename _merge _merge_Taf_2_8
merge 1:1 caseid using Out_Mig.dta
replace tafsil=7 if _merge==3
drop if _merge==2
replace h4 = g6 if missing( h4 )
replace h7 = g7 if missing( h7 )
replace h8 = g8 if missing( h8 )
drop g6 g7 g8 caseid_t psu_no hh_no q_8 _merge_hp _merge_Taf_2_8 _merge
tab tafsil
save final_merge17.dta,replace
//renaming+relabelling
rename zila Dist
rename rmo Rmo
rename q_3 q4_water
rename q_5 q6_fuel
rename q_6 q7_toilet
rename q_7 q8_econ
rename q_10 q10_age
rename q_11 q11_sex
rename q_12 q12_religion
rename q_13 q13_relation
rename q_14 q14_marry
rename q_16 q16_class
rename q_22 q22_occupation
rename tafsil schedule

label variable Dist "District/Zila"
label variable Rmo "Type of place"
label variable q4_water "Ownership of water source"
label variable q6_fuel "Fuel source"
label variable q7_toilet "Toilet Facility"
label variable q8_econ "Economic Status"
label variable q10_age "Age"
label variable q11_sex "Sex"
label variable q12_religion "Religion"
label variable q13_relation "Relation to Household Head"
label variable q14_marry "Marital Status"
label variable q16_class "Class Passed Upto what(>4y)?"
label variable q22_occupation "Occupation/What do you do?"
label variable caseid "Unique case indentifier"
label variable SVRS "Study Year" 
label variable schedule "Schedule/Module of Survey"
save final_merge17.dta,replace
save "E:\4th year\Project\SVRS\SVRS_Data_Uncoded\final_merges\final_merge17.dta"


//---close all stata files---//


/*----------Open SVRS18 folder, open all 4 stata files simulatanously------------*/



* creating wealth index and quintile
use Taf2p.dta, clear
gen water_source = .
replace water_source = 5 if (water_source == . & Q2B == 1)
replace water_source = 4 if (water_source == . & Q2B == 2)
replace water_source = 3 if (water_source == . & Q2B == 4)
replace water_source = 2 if (water_source == . & Q2B == 5)
replace water_source = 1 if water_source == .

gen electricity = .
replace electricity = 2 if Q4 == 1
replace electricity = 1 if electricity == .

gen water_own = .
replace water_own = 2 if Q3 == 1
replace water_own = 1 if water_own == .

gen sanitary = .
replace sanitary = 4 if Q6 == 1
replace sanitary = 3 if Q6 == 2
replace sanitary = 2 if Q6 == 3
replace sanitary = 1 if sanitary == .

gen money = .
replace money = 4 if Q7 == 4
replace money = 3 if Q7 == 3
replace money = 2 if Q7 == 2
replace money = 1 if money == .

pca money water_source water_own sanitary electricity

predict wealth_index_5, score

xtile wealth_quintile_5 = wealth_index_5, n(5)

label define wq 1 "Poorest" 2 "Poorer" 3 "Middle" 4 "Richer" 5 "Richest"
label values wealth_quintile_5 wq


//Already found merged.
drop Q2A Q2B Q3 Q4 Q5 Q6 Q7
gen SVRS = 2018
gen caseid = string(SVRS) + " " + string(PSU_NO) + " " + string(HH2) + " " + string(Q8) 
duplicates report caseid
duplicates drop caseid, force
save Taf2.dta, replace


//---Merging unique cases of Taf7 and Taf8 with Taf2 (Important)---//


use Taf8.dta, clear
gen SVRS = 2018
gen caseid = string(SVRS) + " " + string(HH1) + " " + string(HH2) + " " + string(LINE)
duplicates report caseid
duplicates drop caseid, force
keep H4 H5 H6 H7M H8 caseid

replace H6 = H6 + 100 if H5 == 4

save Taf8.dta, replace

use Taf7.dta, clear
gen SVRS = 2018
gen caseid = string(SVRS) + " " + string(HH1) + " " + string(HH2) + " " + string(LINE)
duplicates report caseid
duplicates drop caseid, force
keep G4 G5 G6 G7M G8 caseid

replace G5 = G5 + 100 if G4 == 4

save Taf7.dta, replace

//Start Merging
//In_Mig (Taf2+Taf8)
use Taf2.dta,clear
merge 1:1 caseid using Taf8.dta
drop if _merge==2
gen tafsil=.
replace tafsil=8 if _merge==3
save In_Mig.dta,replace

//uniuqe Out_Mig (Taf7+Taf8)
use Taf7.dta,clear
merge 1:1 caseid using Taf8.dta
drop if inrange( _merge, 2, 3 )
rename G4 gg4
rename G5 gg5
rename G6 g6
rename G7M g7
rename G8 g8
label variable gg4 "gg4.migrated to which area"
label variable gg5 "gg5.migrated to which district"
keep caseid gg4 gg5 g6 g7 g8
save Out_Mig.dta,replace

//final_merge (In_Mig + Out_Mig)
use In_Mig.dta,replace
rename H4 h4
rename H5 h5
rename H6 h6
rename H7M h7
rename H8 h8
label variable h4 "h4.reason of migration"
label variable h5 "h5.migrated from which area"
label variable h6 "h6.migrated from which district"
label variable h7 "h7.month of migration"
label variable h8 "h8.migration type"
rename _merge _merge_Taf_2_8
merge 1:1 caseid using Out_Mig.dta
replace tafsil=7 if _merge==3
drop if _merge==2
replace h4 = g6 if missing( h4 )
replace h7 = g7 if missing( h7 )
replace h8 = g8 if missing( h8 )
drop g6 g7 g8 PSU_NO HH2 Q8 _merge_Taf_2_8 _merge
tab tafsil
save final_merge18.dta,replace
//renaming+relabelling
rename ZILA Dist
rename RMO Rmo
rename Q10 q10_age
rename Q11 q11_sex
rename Q12 q12_religion
rename Q13 q13_relation
rename Q14 q14_marry
rename Q16 q16_class
rename Q22 q22_occupation
rename tafsil schedule

label variable Dist "District/Zila"
label variable Rmo "Type of place"
label variable q10_age "Age"
label variable q11_sex "Sex"
label variable q12_religion "Religion"
label variable q13_relation "Relation to Household Head"
label variable q14_marry "Marital Status"
label variable q16_class "Class Passed Upto what(>4y)?"
label variable q22_occupation "Occupation/What do you do?"
label variable caseid "Unique case indentifier"
label variable SVRS "Study Year" 
label variable schedule "Schedule/Module of Survey"
save final_merge18.dta,replace
save "E:\4th year\Project\SVRS\SVRS_Data_Uncoded\final_merges\final_merge18.dta"



//---close all stata files---//


/*----------Open SVRS19 folder, open all 4 stata files simulatanously------------*/


//Merging Popupaltion and Household data


use Taf2p.dta, clear
gen SVRS = 2019
gen caseid_t = string(SVRS) + " " + string(hh1) + " " + string(hh2)
save Taf2p.dta, replace

use Taf2h.dta, clear
gen SVRS = 2019
gen caseid_t = string(SVRS) + " " + string(hh1) + " " + string(hh2)
duplicates report caseid_t
duplicates drop caseid_t, force

* creating wealth index and quintile

gen water_source = .
replace water_source = 5 if (water_source == . & q2b == 1)
replace water_source = 4 if (water_source == . & q2b == 2)
replace water_source = 3 if (water_source == . & q2b == 4)
replace water_source = 2 if (water_source == . & q2b == 5)
replace water_source = 1 if water_source == .

gen electricity = .
replace electricity = 2 if q4 == 1
replace electricity = 1 if electricity == .

gen water_own = .
replace water_own = 2 if q3 == 1
replace water_own = 1 if water_own == .

gen sanitary = .
replace sanitary = 4 if q6a == 1
replace sanitary = 3 if q6a == 2
replace sanitary = 2 if q6a == 3
replace sanitary = 1 if sanitary == .

gen money = .
replace money = 4 if q7 == 4
replace money = 3 if q7 == 3
replace money = 2 if q7 == 2
replace money = 1 if money == .

pca money water_source water_own sanitary electricity

predict wealth_index_5, score

xtile wealth_quintile_5 = wealth_index_5, n(5)

label define wq 1 "Poorest" 2 "Poorer" 3 "Middle" 4 "Richer" 5 "Richest"
label values wealth_quintile_5 wq

save Taf2h.dta, replace

use Taf2p.dta, clear
merge m:1 caseid_t using Taf2h.dta
drop if _merge==1
drop if _merge==2 
rename _merge _merge_hp
keep hh1 zila rmo hh2 q8 q10 q11 q12 q13 q14 q16 q23 q3 q5a q6a q7 _merge_hp SVRS caseid_t wealth_quintile_5
gen caseid = string(SVRS) + " " + string(hh1) + " " + string(hh2) + " " + string(q8)
duplicates report caseid
duplicates drop caseid, force
save Taf2.dta, replace


//---Merging unique cases of Taf7 and Taf8 with Taf2 (Important)---//


use Taf8.dta, clear
gen SVRS = 2019
gen caseid = string(SVRS) + " " + string(HH1) + " " + string(HH2) + " " + string(LINE)
duplicates report caseid
duplicates drop caseid, force
keep H4 H5 H6 H7M H8 caseid

replace H6 = H6 + 100 if H5 == 4

save Taf8.dta, replace

use Taf7.dta, clear
gen SVRS = 2019
gen caseid = string(SVRS) + " " + string(hh1) + " " + string(hh2) + " " + string(line)
duplicates report caseid
duplicates drop caseid, force
rename g4 G4
rename g5 G5
rename g6 G6
rename g7m G7M
rename g8 G8
keep G4 G5 G6 G7M G8 caseid

replace G5 = G5 + 100 if G4 == 4

save Taf7.dta, replace

//Start Merging
//In_Mig (Taf2+Taf8)
use Taf2.dta,clear
merge 1:1 caseid using Taf8.dta
drop if _merge==2
gen tafsil=.
replace tafsil=8 if _merge==3
save In_Mig.dta,replace

//uniuqe Out_Mig (Taf7+Taf8)
use Taf7.dta,clear
merge 1:1 caseid using Taf8.dta
drop if inrange( _merge, 2, 3 )
rename G4 gg4
rename G5 gg5
rename G6 g6
rename G7M g7
rename G8 g8
label variable gg4 "gg4.migrated to which area"
label variable gg5 "gg5.migrated to which district"
keep caseid gg4 gg5 g6 g7 g8
save Out_Mig.dta,replace

//final_merge (In_Mig + Out_Mig)
use In_Mig.dta,replace
rename H4 h4
rename H5 h5
rename H6 h6
rename H7M h7
rename H8 h8
label variable h4 "h4.reason of migration"
label variable h5 "h5.migrated from which area"
label variable h6 "h6.migrated from which district"
label variable h7 "h7.month of migration"
label variable h8 "h8.migration type"
rename _merge _merge_Taf_2_8
merge 1:1 caseid using Out_Mig.dta
replace tafsil=7 if _merge==3
drop if _merge==2
replace h4 = g6 if missing( h4 )
replace h7 = g7 if missing( h7 )
replace h8 = g8 if missing( h8 )
drop g6 g7 g8 caseid_t hh1 hh2 q8 _merge_hp _merge_Taf_2_8 _merge
tab tafsil
save final_merge19.dta,replace
//renaming+relabelling
rename zila Dist
rename rmo Rmo
rename q3 q4_water
rename q5a q6_fuel
rename q6a q7_toilet
rename q7 q8_econ
rename q10 q10_age
rename q11 q11_sex
rename q12 q12_religion
rename q13 q13_relation
rename q14 q14_marry
rename q16 q16_class
rename q23 q22_occupation
rename tafsil schedule

label variable Dist "District/Zila"
label variable Rmo "Type of place"
label variable q4_water "Ownership of water source"
label variable q6_fuel "Fuel source"
label variable q7_toilet "Toilet Facility"
label variable q8_econ "Economic Status"
label variable q10_age "Age"
label variable q11_sex "Sex"
label variable q12_religion "Religion"
label variable q13_relation "Relation to Household Head"
label variable q14_marry "Marital Status"
label variable q16_class "Class Passed Upto what(>4y)?"
label variable q22_occupation "Occupation/What do you do?"
label variable caseid "Unique case indentifier"
label variable SVRS "Study Year" 
label variable schedule "Schedule/Module of Survey"
save final_merge19.dta,replace
save "E:\4th year\Project\SVRS\SVRS_Data_Uncoded\final_merges\final_merge19.dta"



//---close all stata files---//


/*----------Open SVRS20 folder, open all 4 stata files simulatanously------------*/


//Merging Popupaltion and Household data


use Taf2p.dta, clear
gen SVRS = 2020
gen caseid_t = string(SVRS) + " " + string(hh1) + " " + string(hh2)
save Taf2p.dta, replace

use Taf2h.dta, clear
gen SVRS = 2020
gen caseid_t = string(SVRS) + " " + string(hh1) + " " + string(hh2)
duplicates report caseid_t
duplicates drop caseid_t, force

gen water_source = .
replace water_source = 5 if (water_source == . & q2b == 1)
replace water_source = 4 if (water_source == . & q2b == 2)
replace water_source = 3 if (water_source == . & q2b == 4)
replace water_source = 2 if (water_source == . & q2b == 5)
replace water_source = 1 if water_source == .

gen electricity = .
replace electricity = 2 if q4 == 1
replace electricity = 1 if electricity == .

gen water_own = .
replace water_own = 2 if q3 == 1
replace water_own = 1 if water_own == .

gen sanitary = .
replace sanitary = 4 if q6a == 1
replace sanitary = 3 if q6a == 2
replace sanitary = 2 if q6a == 3
replace sanitary = 1 if sanitary == .

gen money = .
replace money = 4 if q7 == 4
replace money = 3 if q7 == 3
replace money = 2 if q7 == 2
replace money = 1 if money == .

pca money water_source water_own sanitary electricity

predict wealth_index_5, score

xtile wealth_quintile_5 = wealth_index_5, n(5)

label define wq 1 "Poorest" 2 "Poorer" 3 "Middle" 4 "Richer" 5 "Richest"
label values wealth_quintile_5 wq

save Taf2h.dta, replace

use Taf2p.dta, clear
merge m:1 caseid_t using Taf2h.dta
drop if _merge==1
drop if _merge==2 
rename _merge _merge_hp
keep hh1 zila rmo hh2 q8 q10 q11 q12 q13 q14 q16 q24 q3 q5a q6a q7 _merge_hp SVRS caseid_t wealth_quintile_5
gen caseid = string(SVRS) + " " + string(hh1) + " " + string(hh2) + " " + string(q8)
duplicates report caseid
duplicates drop caseid, force
save Taf2.dta, replace


//---Merging unique cases of Taf7 and Taf8 with Taf2 (Important)---//


use Taf8.dta, clear
gen SVRS = 2020
gen caseid = string(SVRS) + " " + string(hh1) + " " + string(hh2) + " " + string(line)
duplicates report caseid
duplicates drop caseid, force
keep h4 h5 h6 h7m h8 caseid

replace h6 = h6 + 100 if h5 == 4

save Taf8.dta, replace

use Taf7.dta, clear
gen SVRS = 2020
gen caseid = string(SVRS) + " " + string(hh1) + " " + string(hh2) + " " + string(line)
duplicates report caseid
duplicates drop caseid, force
keep g4 g5 g6 g7m g8 caseid

replace g5 = g5 + 100 if g4 == 4

save Taf7.dta, replace

//Start Merging
//In_Mig (Taf2+Taf8)
use Taf2.dta,clear
merge 1:1 caseid using Taf8.dta
drop if _merge==2
gen tafsil=.
replace tafsil=8 if _merge==3
save In_Mig.dta,replace

//uniuqe Out_Mig (Taf7+Taf8)
use Taf7.dta,clear
merge 1:1 caseid using Taf8.dta
drop if inrange( _merge, 2, 3 )
rename g4 gg4
rename g5 gg5
label variable gg4 "gg4.migrated to which area"
label variable gg5 "gg5.migrated to which district"
keep caseid gg4 gg5 g6 g7 g8
save Out_Mig.dta,replace

//final_merge (In_Mig + Out_Mig)
use In_Mig.dta,replace
rename h7m h7
label variable h4 "h4.reason of migration"
label variable h5 "h5.migrated from which area"
label variable h6 "h6.migrated from which district"
label variable h7 "h7.month of migration"
label variable h8 "h8.migration type"
rename _merge _merge_Taf_2_8
merge 1:1 caseid using Out_Mig.dta
replace tafsil=7 if _merge==3
drop if _merge==2
replace h4 = g6 if missing( h4 )
replace h7 = g7 if missing( h7 )
replace h8 = g8 if missing( h8 )
drop g6 g7m g8 caseid_t hh1 hh2 q8 _merge_hp _merge_Taf_2_8 _merge
tab tafsil
save final_merge20.dta,replace
//renaming+relabelling
rename zila Dist
rename rmo Rmo
rename q3 q4_water
rename q5a q6_fuel
rename q6a q7_toilet
rename q7 q8_econ
rename q10 q10_age
rename q11 q11_sex
rename q12 q12_religion
rename q13 q13_relation
rename q14 q14_marry
rename q16 q16_class
rename q24 q22_occupation
rename tafsil schedule

label variable Dist "District/Zila"
label variable Rmo "Type of place"
label variable q4_water "Ownership of water source"
label variable q6_fuel "Fuel source"
label variable q7_toilet "Toilet Facility"
label variable q8_econ "Economic Status"
label variable q10_age "Age"
label variable q11_sex "Sex"
label variable q12_religion "Religion"
label variable q13_relation "Relation to Household Head"
label variable q14_marry "Marital Status"
label variable q16_class "Class Passed Upto what(>4y)?"
label variable q22_occupation "Occupation/What do you do?"
label variable caseid "Unique case indentifier"
label variable SVRS "Study Year" 
label variable schedule "Schedule/Module of Survey"
save final_merge20.dta,replace
save "E:\4th year\Project\SVRS\SVRS_Data_Uncoded\final_merges\final_merge20.dta"






//---close all stata files---//


/*----------Open SVRS21 folder, open all 4 stata files simulatanously------------*/


//Merging Popupaltion and Household data


use Taf2p.dta, clear
gen SVRS = 2021
gen caseid_t = string(SVRS) + " " + string(psu) + " " + string(hh)
save Taf2p.dta, replace

use Taf2h.dta, clear
gen SVRS = 2021
gen caseid_t = string(SVRS) + " " + string(psu) + " " + string(hh)
duplicates report caseid_t
duplicates drop caseid_t, force
save Taf2h.dta, replace

use Taf2p.dta, clear
drop _merge
merge m:1 caseid_t using Taf2h.dta
drop if _merge==1
drop if _merge==2 
gen caseid = string(SVRS) + " " + string(psu) + " " + string(hh) + " " + string(line)
duplicates report caseid
duplicates drop caseid, force
rename _merge _merge_hp
keep psu hh line zl rmo q19 q18b q20 q21a q23 q27_edu q31 wealth_quint _merge_hp SVRS caseid
save Taf2.dta, replace


//---Merging unique cases of Taf7 and Taf8 with Taf2 (Important)---//


use Taf8.dta, clear
gen SVRS = 2021
gen caseid = string(SVRS) + " " + string(psu) + " " + string(hh) + " " + string(line)
duplicates report caseid
duplicates drop caseid, force
keep h4 h5 h6 h7m h8 caseid
replace h6 = h6 + 100 if h5 == 4
save Taf8.dta, replace

use Taf7.dta, clear
gen SVRS = 2021
gen caseid = string(SVRS) + " " + string(psu) + " " + string(hh) + " " + string(line)
duplicates report caseid
duplicates drop caseid, force
keep g4 g5 g6 g7m g8 caseid
replace g5 = g5 + 100 if g4 == 4
save Taf7.dta, replace

//Start Merging
//In_Mig (Taf2+Taf8)
use Taf2.dta,clear
merge 1:1 caseid using Taf8.dta
drop if _merge==2
gen tafsil=.
replace tafsil=8 if _merge==3
save In_Mig.dta,replace

//uniuqe Out_Mig (Taf7+Taf8)
use Taf7.dta,clear
merge 1:1 caseid using Taf8.dta
drop if inrange( _merge, 2, 3 )
rename g4 gg4
rename g5 gg5
label variable gg4 "gg4.migrated to which area"
label variable gg5 "gg5.migrated to which district"
keep caseid gg4 gg5 g6 g7 g8
save Out_Mig.dta,replace

//final_merge (In_Mig + Out_Mig)
use In_Mig.dta,replace
rename h7m h7
label variable h4 "h4.reason of migration"
label variable h5 "h5.migrated from which area"
label variable h6 "h6.migrated from which district"
label variable h7 "h7.month of migration"
label variable h8 "h8.migration type"
rename _merge _merge_Taf_2_8
merge 1:1 caseid using Out_Mig.dta
replace tafsil=7 if _merge==3
drop if _merge==2
replace h4 = g6 if missing( h4 )
replace h7 = g7 if missing( h7 )
replace h8 = g8 if missing( h8 )
drop g6 g7m g8 psu hh line _merge_hp _merge_Taf_2_8 _merge
tab tafsil
save final_merge21.dta,replace
//renaming+relabelling
rename zl Dist
rename rmo Rmo
rename wealth_quint q8_econ
rename q18b q10_age
rename q19 q11_sex
rename q23 q12_religion
rename q20 q13_relation
rename q21a q14_marry
rename q27_edu q16_class
rename q31 q22_occupation
rename tafsil schedule

label variable Dist "District/Zila"
label variable Rmo "Type of place"
label variable q8_econ "Economic Status"
label variable q10_age "Age"
label variable q11_sex "Sex"
label variable q12_religion "Religion"
label variable q13_relation "Relation to Household Head"
label variable q14_marry "Marital Status"
label variable q16_class "Class Passed Upto what(>4y)?"
label variable q22_occupation "Occupation/What do you do?"
label variable caseid "Unique case indentifier"
label variable SVRS "Study Year" 
label variable schedule "Schedule/Module of Survey"
drop if q11_sex == 3
rename q8_econ wealth_quintile_5
save final_merge21.dta,replace
save "E:\4th year\Project\SVRS\SVRS_Data_Uncoded\final_merges\final_merge21.dta"








//---close all stata files---//


/*----------Open SVRS22 folder, open all 4 stata files simulatanously------------*/


//Merging Popupaltion and Household data


use Taf2p.dta, clear
gen SVRS = 2022
gen caseid_t = string(SVRS) + " " + string(psu) + " " + string(hh)
save Taf2p.dta, replace

use Taf2h.dta, clear
gen SVRS = 2022
gen caseid_t = string(SVRS) + " " + string(psu) + " " + string(hh)
duplicates report caseid_t
duplicates drop caseid_t, force
drop rmo
save Taf2h.dta, replace

use Taf2p.dta, clear
merge m:1 caseid_t using Taf2h.dta
drop if _merge==1
drop if _merge==2 
rename _merge _merge_hp
gen caseid = string(SVRS) + " " + string(psu) + " " + string(hh) + " " + string(q16_line)
duplicates report caseid
duplicates drop caseid, force
keep psu hh q16_line zl rmo q18b q19 q20 q21a q23 q27 q31 wealth_quint _merge_hp SVRS caseid
rename wealth_quint wealth_quintile_5
save Taf2.dta, replace


//---Merging unique cases of Taf7 and Taf8 with Taf2 (Important)---//


use Taf8.dta, clear
gen SVRS = 2022
gen caseid = string(SVRS) + " " + string(psu) + " " + string(hhno) + " " + string(line)
duplicates report caseid
duplicates drop caseid, force
rename Q4 h4
rename Q5 h5
rename Q5_new h5n
rename Q6 h6
rename Q7_date h7m
rename Q8 h8  
keep h4 h5 h5n h6 h7m h8 caseid
replace h6 = h5n + 100 if h5 == 4
save Taf8.dta, replace

use Taf7.dta, clear
gen SVRS = 2022
gen caseid = string(SVRS) + " " + string(psu) + " " + string(hhno) + " " + string(line)
duplicates report caseid
duplicates drop caseid, force
rename Q4 g4
rename Q5a g5
rename Q5_country g5n
rename Q6 g6
rename Q7 g7m 
rename OUT_TYPE g8
keep g4 g5 g5n g6 g7m g8 caseid
destring varname, replace
replace g5 = g5n + 100 if g4 == 4
save Taf7.dta, replace

//Start Merging
//In_Mig (Taf2+Taf8)
use Taf2.dta,clear
merge 1:1 caseid using Taf8.dta
drop if _merge==2
gen tafsil=.
replace tafsil=8 if _merge==3
save In_Mig.dta,replace

//uniuqe Out_Mig (Taf7+Taf8)
use Taf7.dta,clear
merge 1:1 caseid using Taf8.dta
drop if inrange( _merge, 2, 3 )
rename g4 gg4
rename g5 gg5
label variable gg4 "gg4.migrated to which area"
label variable gg5 "gg5.migrated to which district"
keep caseid gg4 gg5 g6 g7 g8
save Out_Mig.dta,replace

//final_merge (In_Mig + Out_Mig)
use In_Mig.dta,replace
rename h7m h7
label variable h4 "h4.reason of migration"
label variable h5 "h5.migrated from which area"
label variable h6 "h6.migrated from which district"
label variable h7 "h7.month of migration"
label variable h8 "h8.migration type"
rename _merge _merge_Taf_2_8
merge 1:1 caseid using Out_Mig.dta
replace tafsil=7 if _merge==3
drop if _merge==2
replace h4 = g6 if missing( h4 )
replace h7 = g7 if missing( h7 )
replace h8 = g8 if missing( h8 )
drop g6 g7m g8 psu hh q16_line _merge_hp _merge_Taf_2_8 _merge
tab tafsil
save final_merge22.dta,replace
//renaming+relabelling
rename zl Dist
rename rmo Rmo
rename wealth_quint wealth_quintile_5
rename q18b q10_age
rename q19 q11_sex
rename q23 q12_religion
rename q20 q13_relation
rename q21a q14_marry
rename q27 q16_class
rename q31 q22_occupation
rename tafsil schedule

label variable Dist "District/Zila"
label variable Rmo "Type of place"
label variable wealth_quintile_5 "Economic Status"
label variable q10_age "Age"
label variable q11_sex "Sex"
label variable q12_religion "Religion"
label variable q13_relation "Relation to Household Head"
label variable q14_marry "Marital Status"
label variable q16_class "Class Passed Upto what(>4y)?"
label variable q22_occupation "Occupation/What do you do?"
label variable caseid "Unique case indentifier"
label variable SVRS "Study Year" 
label variable schedule "Schedule/Module of Survey"
drop if q11_sex == 3
destring gg5, replace force
gen mon = month(h7)
drop h7
rename mon h7
label variable h7 "h7.month of migration"
save final_merge22.dta,replace
save "E:\4th year\Project\SVRS\SVRS_Data_Uncoded\final_merges\final_merge22.dta"








//---close all stata files---//


/*----------Open SVRS23 folder, open all 4 stata files simulatanously------------*/


//Merging Popupaltion and Household data


use Taf2p.dta, clear
gen SVRS = 2023
gen caseid_t = string(SVRS) + " " + string(psu) + " " + string(hh)
save Taf2p.dta, replace

use Taf2h.dta, clear
gen SVRS = 2023
gen caseid_t = string(SVRS) + " " + string(psu) + " " + string(hh)
duplicates report caseid_t
duplicates drop caseid_t, force 
save Taf2h.dta, replace

use Taf2p.dta, clear
merge m:1 caseid_t using Taf2h.dta
drop if _merge==1
drop if _merge==2 
rename _merge _merge_hp
gen caseid = string(SVRS) + " " + string(psu) + " " + string(hh) + " " + string(line)
duplicates report caseid
duplicates drop caseid, force
keep psu hh line zl rmo q18b q19 q20 q21a q23 q27 q31 wealth_quint _merge_hp SVRS caseid
save Taf2.dta, replace


//---Merging unique cases of Taf7 and Taf8 with Taf2 (Important)---//


use Taf8.dta, clear
gen SVRS = 2023
gen caseid = string(SVRS) + " " + string(psu) + " " + string(hhno) + " " + string(ln_act)
duplicates report caseid
duplicates drop caseid, force
rename Q4 h4
rename Q5 h5
rename Q5_dist h6
rename Q5_country h6n
rename month h7m
rename Q8 h8  
keep h4 h5 h6 h6n h7m h8 caseid
replace h6 = h6n + 100 if h5 == 4
save Taf8.dta, replace

use Taf7.dta, clear
gen SVRS = 2023
gen caseid = string(SVRS) + " " + string(psu) + " " + string(hhno) + " " + string(line_no)
duplicates report caseid
duplicates drop caseid, force
rename q4 g4
rename q5_dist g5
rename q5_country g5n
rename q6 g6
rename q7_date g7m 
rename q8 g8
keep g4 g5 g5n g6 g7m g8 caseid
replace g5 = g5n + 100 if g4 == 4
save Taf7.dta, replace

//Start Merging
//In_Mig (Taf2+Taf8)
use Taf2.dta,clear
merge 1:1 caseid using Taf8.dta
drop if _merge==2
gen tafsil=.
replace tafsil=8 if _merge==3
save In_Mig.dta,replace

//uniuqe Out_Mig (Taf7+Taf8)
use Taf7.dta,clear
merge 1:1 caseid using Taf8.dta
drop if inrange( _merge, 2, 3 )
rename g4 gg4
rename g5 gg5
label variable gg4 "gg4.migrated to which area"
label variable gg5 "gg5.migrated to which district"
keep caseid gg4 gg5 g6 g7 g8
save Out_Mig.dta,replace

//final_merge (In_Mig + Out_Mig)
use In_Mig.dta,replace
rename h7m h7
label variable h4 "h4.reason of migration"
label variable h5 "h5.migrated from which area"
label variable h6 "h6.migrated from which district"
label variable h7 "h7.month of migration"
label variable h8 "h8.migration type"
rename _merge _merge_Taf_2_8
merge 1:1 caseid using Out_Mig.dta
replace tafsil=7 if _merge==3
drop if _merge==2
replace h4 = g6 if missing( h4 )
replace h7 = g7 if missing( h7 )
replace h8 = g8 if missing( h8 )
drop g6 g7m g8 psu hh line _merge_hp _merge_Taf_2_8 _merge
tab tafsil
save final_merge23.dta,replace
//renaming+relabelling
rename zl Dist
rename rmo Rmo
rename wealth_quint wealth_quintile_5
rename q18b q10_age
rename q19 q11_sex
rename q23 q12_religion
rename q20 q13_relation
rename q21a q14_marry
rename q27 q16_class
rename q31 q22_occupation
rename tafsil schedule

label variable Dist "District/Zila"
label variable Rmo "Type of place"
label variable wealth_quintile_5 "Economic Status"
label variable q10_age "Age"
label variable q11_sex "Sex"
label variable q12_religion "Religion"
label variable q13_relation "Relation to Household Head"
label variable q14_marry "Marital Status"
label variable q16_class "Class Passed Upto what(>4y)?"
label variable q22_occupation "Occupation/What do you do?"
label variable caseid "Unique case indentifier"
label variable SVRS "Study Year" 
label variable schedule "Schedule/Module of Survey"
drop if q11_sex == 3
save final_merge23.dta,replace
save "E:\4th year\Project\SVRS\SVRS_Data_Uncoded\final_merges\final_merge23.dta"








//----------------------------------------------------------------------------------------------------------------------------------------------------------//


// before merging some cleaning to make all years have same codings.

//open final_merge17
drop q4_water q6_fuel q7_toilet q8_econ

//open final_merge18
drop Q15 Q17 Q18 Q19 Q20 Q21 UPZ UNION MAUZA CW_ratio HH_size dep_ratio water_source electricity water_own sanitary money wealth_index_5

//open final_merge19
drop q4_water q6_fuel q7_toilet q8_econ

//open final_merge20
drop q4_water q6_fuel q7_toilet q8_econ

//open final_merge22
drop h5n

//open final_merge23
drop h6n



// do this for final_merge 21,22,23 only.
gen h6_n = .
replace h6_n = 1 if h6 == 77
replace h6_n = 2 if h6 == 94
replace h6_n = 3 if h6 == 27
replace h6_n = 4 if h6 == 73
replace h6_n = 5 if h6 == 52
replace h6_n = 6 if h6 == 85
replace h6_n = 7 if h6 == 49
replace h6_n = 8 if h6 == 32

replace h6_n = 9 if h6 == 10
replace h6_n = 10 if h6 == 38
replace h6_n = 11 if h6 == 64
replace h6_n = 12 if h6 == 70
replace h6_n = 13 if h6 == 81
replace h6_n = 14 if h6 == 69
replace h6_n = 15 if h6 == 88
replace h6_n = 16 if h6 == 76

replace h6_n = 17 if h6 == 50
replace h6_n = 18 if h6 == 18
replace h6_n = 19 if h6 == 57
replace h6_n = 20 if h6 == 44
replace h6_n = 21 if h6 == 55
replace h6_n = 22 if h6 == 65
replace h6_n = 23 if h6 == 41
replace h6_n = 24 if h6 == 87
replace h6_n = 25 if h6 == 47
replace h6_n = 26 if h6 == 1

replace h6_n = 27 if h6 == 4
replace h6_n = 28 if h6 == 78
replace h6_n = 29 if h6 == 9
replace h6_n = 30 if h6 == 6
replace h6_n = 31 if h6 == 42
replace h6_n = 32 if h6 == 79

replace h6_n = 33 if h6 == 86
replace h6_n = 34 if h6 == 54
replace h6_n = 35 if h6 == 35
replace h6_n = 36 if h6 == 29
replace h6_n = 37 if h6 == 82
replace h6_n = 38 if h6 == 56
replace h6_n = 39 if h6 == 26
replace h6_n = 40 if h6 == 33
replace h6_n = 41 if h6 == 67
replace h6_n = 42 if h6 == 59
replace h6_n = 43 if h6 == 68
replace h6_n = 44 if h6 == 93
replace h6_n = 48 if h6 == 48

replace h6_n = 45 if h6 == 39
replace h6_n = 47 if h6 == 61
replace h6_n = 49 if h6 == 72
replace h6_n = 46 if h6 == 89

replace h6_n = 50 if h6 == 90
replace h6_n = 51 if h6 == 91
replace h6_n = 52 if h6 == 58
replace h6_n = 53 if h6 == 36

replace h6_n = 54 if h6 == 12
replace h6_n = 55 if h6 == 19
replace h6_n = 56 if h6 == 13
replace h6_n = 57 if h6 == 51
replace h6_n = 58 if h6 == 75
replace h6_n = 59 if h6 == 30
replace h6_n = 60 if h6 == 15
replace h6_n = 61 if h6 == 22
replace h6_n = 62 if h6 == 3
replace h6_n = 63 if h6 == 84
replace h6_n = 64 if h6 == 46
replace h6_n = 99 if h6 == 99
replace h6_n = h6 if h6_n == . & h5 == 4
drop h6 
rename h6_n h6


gen gg5_n = .
replace gg5_n = 1 if gg5 == 77
replace gg5_n = 2 if gg5 == 94
replace gg5_n = 3 if gg5 == 27
replace gg5_n = 4 if gg5 == 73
replace gg5_n = 5 if gg5 == 52
replace gg5_n = 6 if gg5 == 85
replace gg5_n = 7 if gg5 == 49
replace gg5_n = 8 if gg5 == 32

replace gg5_n = 9 if gg5 == 10
replace gg5_n = 10 if gg5 == 38
replace gg5_n = 11 if gg5 == 64
replace gg5_n = 12 if gg5 == 70
replace gg5_n = 13 if gg5 == 81
replace gg5_n = 14 if gg5 == 69
replace gg5_n = 15 if gg5 == 88
replace gg5_n = 16 if gg5 == 76

replace gg5_n = 17 if gg5 == 50
replace gg5_n = 18 if gg5 == 18
replace gg5_n = 19 if gg5 == 57
replace gg5_n = 20 if gg5 == 44
replace gg5_n = 21 if gg5 == 55
replace gg5_n = 22 if gg5 == 65
replace gg5_n = 23 if gg5 == 41
replace gg5_n = 24 if gg5 == 87
replace gg5_n = 25 if gg5 == 47
replace gg5_n = 26 if gg5 == 1

replace gg5_n = 27 if gg5 == 4
replace gg5_n = 28 if gg5 == 78
replace gg5_n = 29 if gg5 == 9
replace gg5_n = 30 if gg5 == 6
replace gg5_n = 31 if gg5 == 42
replace gg5_n = 32 if gg5 == 79

replace gg5_n = 33 if gg5 == 86
replace gg5_n = 34 if gg5 == 54
replace gg5_n = 35 if gg5 == 35
replace gg5_n = 36 if gg5 == 29
replace gg5_n = 37 if gg5 == 82
replace gg5_n = 38 if gg5 == 56
replace gg5_n = 39 if gg5 == 26
replace gg5_n = 40 if gg5 == 33
replace gg5_n = 41 if gg5 == 67
replace gg5_n = 42 if gg5 == 59
replace gg5_n = 43 if gg5 == 68
replace gg5_n = 44 if gg5 == 93
replace gg5_n = 48 if gg5 == 48

replace gg5_n = 45 if gg5 == 39
replace gg5_n = 47 if gg5 == 61
replace gg5_n = 49 if gg5 == 72
replace gg5_n = 46 if gg5 == 89

replace gg5_n = 50 if gg5 == 90
replace gg5_n = 51 if gg5 == 91
replace gg5_n = 52 if gg5 == 58
replace gg5_n = 53 if gg5 == 36

replace gg5_n = 54 if gg5 == 12
replace gg5_n = 55 if gg5 == 19
replace gg5_n = 56 if gg5 == 13
replace gg5_n = 57 if gg5 == 51
replace gg5_n = 58 if gg5 == 75
replace gg5_n = 59 if gg5 == 30
replace gg5_n = 60 if gg5 == 15
replace gg5_n = 61 if gg5 == 22
replace gg5_n = 62 if gg5 == 3
replace gg5_n = 63 if gg5 == 84
replace gg5_n = 64 if gg5 == 46
replace gg5_n = 99 if gg5 == 99
replace gg5_n = gg5 if gg5_n == . & gg4 == 4
drop gg5 
rename gg5_n gg5












//Merging all year. Open final_merges folder. open all stata file simulatanously. Go to final_merge17.dta 

// remove all value labels from a dataset//////
use final_merge17.dta, clear
foreach var of varlist _all {
    label values `var'   
}

use final_merge17, clear
foreach year in 18 19 20 21 22 23{
    append using final_merge`year'
}
save grand_merge_1723, replace


/// More Cleaning in grand_merge files

use grand_merge_1723.dta, replace


//dist and Division
gen zila = .
replace zila = 1 if Dist == 77
replace zila = 2 if Dist == 94
replace zila = 3 if Dist == 27
replace zila = 4 if Dist == 73
replace zila = 5 if Dist == 52
replace zila = 6 if Dist == 85
replace zila = 7 if Dist == 49
replace zila = 8 if Dist == 32

replace zila = 9 if Dist == 10
replace zila = 10 if Dist == 38
replace zila = 11 if Dist == 64
replace zila = 12 if Dist == 70
replace zila = 13 if Dist == 81
replace zila = 14 if Dist == 69
replace zila = 15 if Dist == 88
replace zila = 16 if Dist == 76

replace zila = 17 if Dist == 50
replace zila = 18 if Dist == 18
replace zila = 19 if Dist == 57
replace zila = 20 if Dist == 44
replace zila = 21 if Dist == 55
replace zila = 22 if Dist == 65
replace zila = 23 if Dist == 41
replace zila = 24 if Dist == 87
replace zila = 25 if Dist == 47
replace zila = 26 if Dist == 1

replace zila = 27 if Dist == 4
replace zila = 28 if Dist == 78
replace zila = 29 if Dist == 9
replace zila = 30 if Dist == 6
replace zila = 31 if Dist == 42
replace zila = 32 if Dist == 79

replace zila = 33 if Dist == 86
replace zila = 34 if Dist == 54
replace zila = 35 if Dist == 35
replace zila = 36 if Dist == 29
replace zila = 37 if Dist == 82
replace zila = 38 if Dist == 56
replace zila = 39 if Dist == 26
replace zila = 40 if Dist == 33
replace zila = 41 if Dist == 67
replace zila = 42 if Dist == 59
replace zila = 43 if Dist == 68
replace zila = 44 if Dist == 93
replace zila = 48 if Dist == 48

replace zila = 45 if Dist == 39
replace zila = 47 if Dist == 61
replace zila = 49 if Dist == 72
replace zila = 46 if Dist == 89

replace zila = 50 if Dist == 90
replace zila = 51 if Dist == 91
replace zila = 52 if Dist == 58
replace zila = 53 if Dist == 36

replace zila = 54 if Dist == 12
replace zila = 55 if Dist == 19
replace zila = 56 if Dist == 13
replace zila = 57 if Dist == 51
replace zila = 58 if Dist == 75
replace zila = 59 if Dist == 30
replace zila = 60 if Dist == 15
replace zila = 61 if Dist == 22
replace zila = 62 if Dist == 3
replace zila = 63 if Dist == 84
replace zila = 64 if Dist == 46

recode zila (1/8 = 55 "Rangpur") (9/16 = 50 "Rajshahi") (17/26 = 40 "Khulna") (27/32 = 10 "Barisal") (33/44 48 = 30 "Dhaka") (45 46 47 49 = 45 "Mymensingh") (50/53 = 60 "Sylhet") (54/64 = 20 "Chittagong"), gen(Division)

label define ZILLA 1 "Panchagarh" 2 "Thakurgaon" 3 "Dinajpur" 4 "Nilphamari" 5 "Lalmonirhat" 6 "Rangpur" 7 "Kurigram" 8 "Gaibandha" 9 "Bogra" 10 "Joypurhat" 11 "Naogaon" 12 "Nawabganj" 13 "Rajshahi" 14 "Natore" 15 "Sirajganj" 16 "Pabna" 17 "Kushtia" 18 "Chuadanga" 19 "Meherpur" 20 "Jhenaidah" 21 "Magura" 22 "Narail" 23 "Jessore" 24 "Satkhira" 25 "Khulna" 26 "Bagerhat" 27 "Barguna" 28 "Patuakhali" 29 "Bhola" 30 "Barisal" 31 "Jhalokati" 32 "Pirojpur" 33 "Shariatpur" 34 "Madaripur" 35 "Gopalganj" 36 "Faridpur" 37 "Rajbari" 38 "Manikganj" 39 "Dhaka" 40 "Gazipur" 41 "Narayanganj" 42 "Munshiganj" 43 "Narsingdi" 44 "Tangail" 45 "Jamalpur" 46 "Sherpur" 47 "Mymensingh" 48 "Kishoreganj" 49 "Netrakona" 50 "Sunamganj" 51 "Sylhet" 52 "Maulvibazar" 53 "Habiganj" 54 "Brahamanbaria" 55 "Comilla" 56 "Chandpur" 57 "Lakshmipur" 58 "Noakhali" 59 "Feni" 60 "Chittagong" 61 "Cox's Bazar" 62 "Bandarban" 63 "Rangamati" 64 "Khagrachhari"
label values zila ZILLA

drop Dist


// Continue cleaning
replace h6 = . if !(inrange(h6, 1, 64) | h6 == 99 | inrange(h6, 101, 199))
replace gg5 = . if !(inrange(gg5, 1, 64) | gg5 == 99 | inrange(gg5, 101, 199))


// Migrated or not
gen migrated = .
replace migrated = 1 if schedule != .
replace migrated = 0 if schedule == .
label define BINARY 1 "Yes" 0 "No"
label values migrated BINARY

//droping cases with missing values
codebook q11_sex q12_religion q13_relation q14_marry
drop if q10_age == .
drop if q13_relation == .
drop if q14_marry == .
drop if q14_marry == 0

replace Rmo = 3 if Rmo == 4
replace Rmo = 3 if Rmo == 9
replace q13_relation = . if q13_relation==0
replace q13_relation = 9 if q13_relation == 8
replace q16_class = 0 if q16_class==4.05
replace q16_class = 0 if q16_class == 77
replace q16_class = 1 if q16_class == 88
replace q22_occupation = 0 if q22_occupation == -9
replace q22_occupation = 0 if inrange(q22_occupation,36,98)
replace h4 = . if h4 == 0
replace h4 = . if h4 == 50
replace h4 = 12 if h4 == 99
replace h7 = . if h7 == 0
replace h8 = . if !(inrange(h8,1,2))














// NEW: External migrants
gen external = .
replace external = 1 if ((h5 == 4) | (gg4 == 4))
replace external = 0 if (external == . & migrated == 1)
label values external BINARY


// NEW: External-outmigrants and in-migrants
gen ext_migrant = .
replace ext_migrant = 1 if gg4 == 4
replace ext_migrant = 0 if h5 == 4
label define EXT_MIG 1 "Out-migrant" 0 "In-migrant"
label values ext_migrant EXT_MIG

// NEW: Countries recoded as global regions
gen global_region = .
replace global_region = 1 if (inrange(h6, 101, 105) | inrange(gg5, 101, 105))
replace global_region = 2 if (inrange(h6, 106, 110) | inrange(gg5, 106, 110))
replace global_region = 3 if (inrange(h6, 111, 115) | inrange(gg5, 111, 115))
replace global_region = 4 if (inrange(h6, 116, 119) | inrange(gg5, 116, 119))
replace global_region = 5 if (inrange(h6, 120, 122) | inrange(gg5, 120, 122))
replace global_region = 6 if (inrange(h6, 124, 126) | inrange(gg5, 124, 126))
replace global_region = 7 if (h6 == 123 | h6 == 199 | gg5 == 123 | gg5 == 199)
label define GLO_REG 1 "South-east asian countries" 2 "Gulf countries" 3 "East asian countries" 4 "Europian countries" 5 "Western countries" 6 "African countries" 7 "Australia and Others"
label values global_region GLO_REG 


//Creation of before and after regions
gen bmdis = .
replace bmdis = zila if (schedule == 7 & external == 0)
replace bmdis = zila if (schedule == 8 & h6 == 99 & external == 0)
replace bmdis = h6 if (schedule == 8 & h6 != 99 & external == 0)
replace bmdis = zila if (migrated == 0)
label variable bmdis "Before Migration District"

gen amdis = .
replace amdis = zila if (schedule == 8 & external == 0)
replace amdis = zila if (schedule == 7 & gg5 == 99 & external == 0)
replace amdis = gg5 if (schedule == 7 & gg5 != 99 & external == 0)
label variable amdis "After Migration District"

recode bmdis (1/8 = 55 "Rangpur") (9/16 = 50 "Rajshahi") (17/26 = 40 "Khulna") (27/32 = 10 "Barisal") (33/44 48 = 30 "Dhaka") (45 46 47 49 = 45 "Mymensingh") (50/53 = 60 "Sylhet") (54/64 = 20 "Chittagong"), gen(bmdiv)
label variable bmdiv "Before Migration Division"

recode amdis (1/8 = 55 "Rangpur") (9/16 = 50 "Rajshahi") (17/26 = 40 "Khulna") (27/32 = 10 "Barisal") (33/44 48 = 30 "Dhaka") (45 46 47 49 = 45 "Mymensingh") (50/53 = 60 "Sylhet") (54/64 = 20 "Chittagong"), gen(amdiv)
label variable amdiv "After Migration Division"

recode h5 (1 = 0 "Rural") (2 3 = 1 "Urban") (4 = .), gen(h5UR)
recode gg4 (1 = 0 "Rural") (2 3 = 1 "Urban") (4 = .), gen(gg4UR)
recode Rmo (1 = 0 "Rural") (2 3 = 1 "Urban"), gen(RmoUR)

gen bmarea = .
replace bmarea = RmoUR if (schedule == 7)
replace bmarea = h5UR if (schedule == 8 & h5 != 4)
label variable bmarea "Before Migration Area"

gen amarea = .
replace amarea = RmoUR if (schedule == 8)
replace amarea = gg4UR if (schedule == 7 & gg4 != 4)
label variable amarea "After Migration Area"


//Shift variable 

cap egen shift = group(bmarea amarea) 
cap label define T 1 "Rural to rural" 2 "Rural to urban" 3 "Urban to rural" 4 "Urban to urban"
cap label values shift T
cap label var shift "Type of Urban-Rural transition"

//Those who did not migrated remianed in their place; necessary to code this for modelling migrated or not. 
replace bmarea = RmoUR if (migrated == 0)



 


//Some labelling of values

label define RMOn 1 "Rural" 2 "Municipality" 3 "Upazila HQ" 9 "City Corporation"
label values Rmo RMOn

label define SEX 1 "Male" 2 "Female" 
label values q11_sex SEX

label define RELIGION 1 "Islam" 2 "Hinduism" 3 "Buddhism" 4 "Christianity" 9 "Others"
label values q12_religion RELIGION

label define RELATION 1 "Own self" 2 "Spouse" 3 "Child" 4 "Parents/Parent-in-laws" 9 "Others"
label values q13_relation RELATION

label define MARRY 1 "Unmarried" 2 "Married" 3 "Widowed/Widower" 4 "Divorced" 5 "Separately Living"
label values q14_marry MARRY

label define CLASS 0 "Did not pass class 1" 1 "class 1" 2 "class 2" 3 "class 3" 4 "class 4" 5 "class 5" 6 "class 6" 7 "class 7" 8 "class 8" 9 "class 9" 10 "SSC or equivalent" 11 "HSC or equivalent" 12 "Honors or equivalent" 13 "Masters/PhD or equivalent" 14 "Doctor/Engineer/Agri-specialist" 15 "Diploma" 16 "Vocational" 99 "Others"
label values q16_class CLASS



label define OCCUPATION 0 "Do not work" 1 "Landlord" 2 "Farmer with own land" 3 "Family member farmer" 4 "Contractual farmer" 5 "'Borga' farmer with own land" 6 "Landless farmer labor" 7 "Other farmer labor" 8 "Other Non-farmer labor" 9 "Fish farmer" 10 "Fisherman" 11 "Professional officer" 12 "Executive officer" 13 "Professional staff" 14 "Other office staff" 15 "Mil/Factory worker" 16 "Teacher" 17 "Businessman" 18 "Transport labor" 19 "Tailor" 20 "Blacksmith" 21 "Clay modeller" 22 "Goldsmith" 23 "Social service" 24 "Student" 25 "Housekeeping/Wifery" 26 "Servent/Maid" 27 "Household assistant" 28 "Looking for job" 29 "Unable to work" 30 "Beggar" 99 "Others"
label values q22_occupation OCCUPATION 

label define REASON 1 "Marriage" 2 "Education" 3 "Looking for job" 4 "Got a job" 5 "Transfer" 6 "Floating/river erosion" 7 "Earning" 8 "Famliy reunification" 9 "Business" 10 "Retirement" 11 "Abroad" 12 "Others" 
label values h4 REASON 

label define MONTH 1 "Jan" 2 "Feb" 3 "Mar" 4 "Apr" 5 "May" 6 "Jun" 7 "Jul" 8 "Aug" 9 "Sep" 10 "Oct" 11 "Nov" 12 "Dec" 
label values h7 MONTH

label define SCH 7 "Out-migration_Tafsil-7" 8 "In-migration_Tafsil-8"
label values schedule SCH

label define CAT 1 "Household" 2 "Individual"
label values h8 CAT

label define RU 0 "Rural" 1 "Urban"
label values bmarea amarea RU


// NEW: adjusting for different codings of occupation for SVRS 21,22,23
replace q22_occupation = 7 if ( inlist(q22_occupation, 1, 2, 27, 28, 29, 32, 33, 34) & inlist(SVRS, 2021, 2022, 2023) )
replace q22_occupation = 18 if ( inlist(q22_occupation, 3, 4, 5, 6, 7, 8) & inlist(SVRS, 2021, 2022, 2023) )
replace q22_occupation = 17 if ( inlist(q22_occupation, 30) & inlist(SVRS, 2021, 2022, 2023) )
replace q22_occupation = 12 if ( inlist(q22_occupation, 9, 10, 11, 12, 13, 15, 21) & inlist(SVRS, 2021, 2022, 2023) )
replace q22_occupation = 16 if ( inlist(q22_occupation, 16, 17, 18, 19, 20, 22, 24, 25, 26, 31) & inlist(SVRS, 2021, 2022, 2023) )
replace q22_occupation = 99 if ( inlist(q22_occupation, 14, 23, 35) & inlist(SVRS, 2021, 2022, 2023) )
replace q22_occupation = . if ( inlist(q22_occupation, 31, 32, 33, 34, 35) )

replace h4 = 3 if ( inlist(h4, 2) & inlist(SVRS, 2017, 2018, 2019, 2020) )
replace h4 = 4 if ( inlist(h4, 3) & inlist(SVRS, 2017, 2018, 2019, 2020) )
replace h4 = 7 if ( inlist(h4, 6) & inlist(SVRS, 2017, 2018, 2019, 2020) )
replace h4 = 10 if ( inlist(h4, 7, 9) & inlist(SVRS, 2017, 2018, 2019, 2020) )
replace h4 = 12 if ( inlist(h4, 10, 11) & inlist(SVRS, 2017, 2018, 2019, 2020) )
replace h4 = 13 if ( inlist(h4, 8) & inlist(SVRS, 2017, 2018, 2019, 2020) )



// Reocdes for modeling


recode wealth_quintile_5 (1 2 = 1 "Poor") (3 = 2 "Medium") (4 5 = 3 "Rich"), gen (economic)


recode q10_age (0/4 = 1 "<5") (5/14 = 2 "5-14") (15/24 = 3 "15-24") (25/34 = 4 "25-34") (35/44 = 5 "35-44") (45/54 = 6 "45-54") (55/64 = 7 "55-64") (65/199 = 8 ">65"), gen(age)

recode q12_religion (1 = 1 "Islam") (2 = 2 "Hinduism") (3 4 9 = 3 "Others"), gen (religion)

recode q13_relation (1 = 1 "Ownself") (2 = 2 "Spouse") (3 = 3 "Children") (4 10 = 4 "Parents/GrandParents") (5 6 = 5 "Sibling/in-laws") (7 9 = 6 "Others"), gen(relation)


recode q16_class (0 = 0 "No education") (1/5 = 1 "Primary") (6/10 = 2 "Secondary") (11 12 13 17 18 19 21 = 3 "Higher") (14 15 16 20 22 24 99 = 4 "Vocational and Others"), gen(Educational_Level)  



recode q22_occupation (0 28 29 30 = 0 "Unemployed/Unable") (1/10 = 1 "Agricultural & Farming") (15 18 = 2 "Day Laborers") (17 = 3 "Business") (11 12 13 14 = 4 "Professional/Admin") (16 19 20 21 22 23 = 5 "Social Services/Artisans & Teachers") (24 = 6 "Student") (25 = 7 "Housewife") (26 27 99 = 8 "Servant/Maid & Others"), gen(Occupation)

recode Occupation (0 6 7 = 0 "Unemployed/Unable") (1 = 1 "Agriculture/Farming") (2 8 = 3 "Low skill Labor") (4 5 = 4 "Specialized Skill labor") (3 = 5 "Business"), gen(occupation)


recode h4 (1 9 13 = 1 "Marriage/Family") (3 = 2 "Education") (4 5 6 8 10 11 = 3 "Employment/Business") (7 = 4 "Environmental") (2 12 14 15 = 5 "Others"), gen(reason)

replace reason = . if reason == 0
replace reason = . if reason == 16
replace reason = . if reason == 17
replace reason = . if reason == 99


recode q14_marry (1 = 1 "Unmarried") (2 = 2 "Married") (3 4 5 = 3 "Widowed/Divorced/Separately Living"), gen(marry)

//Only keeping (15-64) working age group
drop if age == 1
drop if age == 2
drop if age == 8



//Bivariate (big-mig-nomig-all)
tab bmarea migrated, row 
tab bmdiv migrated, row 
tab SVRS migrated, row 
tab age migrated, row 
tab q11_sex migrated, row 
tab marry migrated, row 
tab religion migrated, row 
tab relation migrated, row 
tab Educational_Level migrated, row 
tab occupation migrated, row 
tab economic migrated, row 

////Univariate (Only those who migrated)
tab bmarea if migrated == 1
tab amarea if migrated == 1
tab shift if migrated == 1
tab bmdiv if migrated == 1
tab amdiv if migrated == 1
tab SVRS if migrated == 1
tab age if migrated == 1
tab q11_sex if migrated == 1
tab marry if migrated == 1
tab religion if migrated == 1
tab relation if migrated == 1
tab Educational_Level if migrated == 1
tab occupation if migrated == 1
tab economic if migrated == 1
tab reason if migrated == 1
tab h8 if migrated == 1

//Bivariate (Shift)
tab bmdiv shift, row chi
tab amdiv shift, row chi
tab SVRS shift, row chi
tab age shift, row chi
tab q11_sex shift, row chi
tab marry shift, row chi
tab religion shift, row chi
tab relation shift, row chi
tab Educational_Level shift, row chi
tab occupation shift, row chi
tab economic shift, row chi
tab reason shift, row chi
tab h8 shift, row chi

save grand_merge_1723.dta, replace

